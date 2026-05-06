#!/usr/bin/env python3
"""
Mobuntu Devkit — auto-runner.

Detects which Mobuntu variant lives in the current directory tree (or repo
root, walking up) and dispatches to its build pipeline. Provides a curses
TUI with a regedit-style split-pane layout: variant tree on the left,
status / log / actions on the right.

Variants are auto-detected by looking for a ``build.sh`` (and optionally
``build.env``) inside known folder names:

    Mobuntu/         — SDM845 main branch
    Mobuntu-PDK/     — Ubuntu PDK adaptation
    Mobuntu-L4T/     — Switchroot L4T target
    Mobuntu-PS4/     — PS4 target

Run from the repo root (or any ancestor):

    python3 devkit.py

ASCII-only — no emoji.
"""
from __future__ import annotations

import curses
import os
import subprocess
import sys
import threading
import time
from collections import deque
from dataclasses import dataclass, field
from pathlib import Path
from typing import Deque, List, Optional

# -----------------------------------------------------------------------------
# Variant discovery
# -----------------------------------------------------------------------------

KNOWN_VARIANTS = ("Mobuntu", "Mobuntu-PDK", "Mobuntu-L4T", "Mobuntu-PS4")


@dataclass
class Device:
    codename: str
    brand: str
    model: str
    path: Path
    config: dict = field(default_factory=dict)


@dataclass
class Variant:
    name: str
    path: Path
    build_sh: Path
    build_env: Optional[Path] = None
    has_devkit_meta: bool = False
    config: dict = field(default_factory=dict)
    devices: List[Device] = field(default_factory=list)

    @property
    def label(self) -> str:
        suite   = self.config.get("UBUNTU_SUITE", "?")
        release = self.config.get("RELEASE_TAG",  "?")
        n       = len(self.devices)
        devstr  = f"  [{n} device{'s' if n != 1 else ''}]" if n else ""
        return f"{self.name:<14}  suite={suite:<8}  release={release}{devstr}"


def find_repo_root(start: Path) -> Path:
    """Walk up looking for a .git or any KNOWN_VARIANTS sibling."""
    cur = start.resolve()
    for parent in [cur] + list(cur.parents):
        if (parent / ".git").exists():
            return parent
        for v in KNOWN_VARIANTS:
            if (parent / v).is_dir():
                return parent
    return cur


_VAR_DEFAULT_RE = __import__("re").compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*):-([^}]*)\}")


def parse_build_env(path: Path) -> dict:
    """Best-effort parse of shell var assignments (build.env, device.conf, etc.).

    Handles patterns like:
        FOO="bar"
        FOO="${FOO:-bar}"        # inline comment
        export FOO=bar
    """
    out: dict = {}
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return out
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        if line.startswith("export "):
            line = line[len("export "):]
        key, _, val = line.partition("=")
        key = key.strip()
        if not key.isidentifier():
            continue

        val = val.lstrip()
        if val.startswith('"') or val.startswith("'"):
            quote = val[0]
            end   = val.find(quote, 1)
            val   = val[1:end] if end != -1 else val[1:]
        else:
            for sep in ("  #", "\t#", " #"):
                idx = val.find(sep)
                if idx != -1:
                    val = val[:idx]
                    break
            val = val.rstrip()

        match = _VAR_DEFAULT_RE.fullmatch(val)
        if match is not None:
            val = match.group(2)

        out[key] = val
    return out


def discover_devices(vpath: Path) -> List[Device]:
    """Scan <variant>/devices/*/device.conf and return Device objects."""
    devices_dir = vpath / "devices"
    if not devices_dir.is_dir():
        return []
    found: List[Device] = []
    for dpath in sorted(devices_dir.iterdir()):
        conf = dpath / "device.conf"
        if not (dpath.is_dir() and conf.is_file()):
            continue
        cfg = parse_build_env(conf)
        found.append(Device(
            codename=cfg.get("DEVICE_CODENAME", dpath.name),
            brand=cfg.get("DEVICE_BRAND", "unknown"),
            model=cfg.get("DEVICE_MODEL", dpath.name),
            path=dpath,
            config=cfg,
        ))
    return found


def discover_variants(root: Path) -> List[Variant]:
    found: List[Variant] = []
    for name in KNOWN_VARIANTS:
        vpath = root / name
        sh    = vpath / "build.sh"
        if not (vpath.is_dir() and sh.is_file()):
            continue
        env = vpath / "build.env"
        cfg = parse_build_env(env) if env.is_file() else {}
        found.append(Variant(
            name=name,
            path=vpath,
            build_sh=sh,
            build_env=env if env.is_file() else None,
            has_devkit_meta=(vpath / ".devkit").exists(),
            config=cfg,
            devices=discover_devices(vpath),
        ))
    return found


# -----------------------------------------------------------------------------
# Build runner — captures live output for the right pane.
# -----------------------------------------------------------------------------

class BuildRunner:
    def __init__(self, max_lines: int = 5000) -> None:
        self.lines: Deque[str] = deque(maxlen=max_lines)
        self.proc: Optional[subprocess.Popen] = None
        self.thread: Optional[threading.Thread] = None
        self.lock = threading.Lock()
        self.exit_code: Optional[int] = None
        self.running = False

    def is_running(self) -> bool:
        return self.running

    def append(self, line: str) -> None:
        with self.lock:
            self.lines.append(line)

    def snapshot(self) -> List[str]:
        with self.lock:
            return list(self.lines)

    def clear(self) -> None:
        with self.lock:
            self.lines.clear()
            self.exit_code = None

    def start(self, cwd: Path, cmd: List[str], env_extra: Optional[dict] = None) -> None:
        if self.running:
            self.append("[devkit] A build is already running. Cancel it first.")
            return
        self.clear()
        self.append(f"[devkit] cd {cwd}")
        self.append(f"[devkit] exec: {' '.join(cmd)}")
        env = os.environ.copy()
        if env_extra:
            env.update(env_extra)
        try:
            self.proc = subprocess.Popen(
                cmd,
                cwd=str(cwd),
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                bufsize=1,
                universal_newlines=True,
                env=env,
            )
        except OSError as exc:
            self.append(f"[devkit ERROR] {exc}")
            self.running = False
            self.exit_code = 127
            return
        self.running = True
        self.thread = threading.Thread(target=self._reader, daemon=True)
        self.thread.start()

    def _reader(self) -> None:
        assert self.proc is not None and self.proc.stdout is not None
        for line in self.proc.stdout:
            self.append(line.rstrip("\n"))
        self.proc.wait()
        self.exit_code = self.proc.returncode
        self.append(f"[devkit] process exited with code {self.exit_code}")
        self.running = False

    def cancel(self) -> None:
        if self.running and self.proc is not None:
            self.append("[devkit] sending SIGTERM")
            try:
                self.proc.terminate()
            except OSError:
                pass


# -----------------------------------------------------------------------------
# TUI
# -----------------------------------------------------------------------------

ACTIONS = [
    ("b", "Build (full pipeline)",         "build_full"),
    ("s", "Build single stage...",         "build_stage"),
    ("c", "Clean build/ directory",        "clean"),
    ("e", "Edit device.conf (in $EDITOR)", "edit_env"),
    ("v", "View device.conf",              "view_env"),
    ("k", "Cancel running build",          "cancel"),
    ("r", "Refresh devices",               "refresh"),
    ("w", "Switch branch",                 "switch_branch"),
    ("q", "Quit",                          "quit"),
]


def safe_addstr(win, y: int, x: int, text: str, attr: int = 0) -> None:
    """addstr that won't blow up on edge writes or non-ascii."""
    try:
        max_y, max_x = win.getmaxyx()
        if y >= max_y or x >= max_x:
            return
        text = text.encode("ascii", "replace").decode("ascii")
        win.addnstr(y, x, text, max_x - x - 1, attr)
    except curses.error:
        pass


# -----------------------------------------------------------------------------
# Branch picker — startup screen and branch-switch overlay
# -----------------------------------------------------------------------------

class BranchPicker:
    """Full-screen branch selection. Returns chosen Variant or None to quit."""

    def __init__(self, stdscr, variants: List[Variant]) -> None:
        self.stdscr   = stdscr
        self.variants = variants
        self.cursor   = 0

    def draw(self) -> None:
        self.stdscr.erase()
        max_y, max_x = self.stdscr.getmaxyx()

        title = " Mobuntu Devkit  --  select a branch "
        safe_addstr(self.stdscr, 0, 0, " " * (max_x - 1), curses.A_REVERSE)
        safe_addstr(self.stdscr, 0, 2, title, curses.A_REVERSE | curses.A_BOLD)

        if not self.variants:
            safe_addstr(self.stdscr, 4, 4,
                        "No branches found. Expected: Mobuntu/  Mobuntu-L4T/  Mobuntu-PS4/")
            safe_addstr(self.stdscr, max_y - 1, 2, " q: quit ", curses.A_REVERSE)
            self.stdscr.refresh()
            return

        safe_addstr(self.stdscr, 2, 4, "Select a branch:", curses.A_BOLD)

        for i, v in enumerate(self.variants):
            is_sel = (i == self.cursor)
            attr   = curses.A_REVERSE | curses.A_BOLD if is_sel else 0
            if v.devices:
                names  = ", ".join(d.codename for d in v.devices)
                detail = f"[{len(v.devices)} device{'s' if len(v.devices) != 1 else ''}]  {names}"
            else:
                suite  = v.config.get("UBUNTU_SUITE", "?")
                detail = f"suite={suite}"
            line = f"  [{i + 1}]  {v.name:<16}  {detail}"
            safe_addstr(self.stdscr, 4 + i * 2, 4, line.ljust(max_x - 8), attr)

        hint = " UP/DOWN: move   Enter: open   1-9: quick pick   q: quit "
        safe_addstr(self.stdscr, max_y - 1, 0, " " * (max_x - 1), curses.A_REVERSE)
        safe_addstr(self.stdscr, max_y - 1, 2, hint, curses.A_REVERSE)
        self.stdscr.refresh()

    def run(self) -> Optional[Variant]:
        curses.curs_set(0)
        self.stdscr.nodelay(True)
        self.stdscr.timeout(150)

        while True:
            self.draw()
            try:
                ch = self.stdscr.getch()
            except KeyboardInterrupt:
                return None
            if ch == -1:
                continue
            if ch == curses.KEY_UP and self.variants:
                self.cursor = (self.cursor - 1) % len(self.variants)
            elif ch == curses.KEY_DOWN and self.variants:
                self.cursor = (self.cursor + 1) % len(self.variants)
            elif ch in (ord("\n"), ord("\r"), curses.KEY_ENTER):
                if self.variants:
                    return self.variants[self.cursor]
            elif ch in (ord("q"), ord("Q")):
                return None
            elif ord("1") <= ch <= ord("9"):
                idx = ch - ord("1")
                if idx < len(self.variants):
                    return self.variants[idx]


# -----------------------------------------------------------------------------
# Main TUI — focused on a single branch
# -----------------------------------------------------------------------------

class DevkitTUI:
    """Split-pane TUI operating on one branch (Variant). Left pane: devices +
    actions. Right pane: live build output. Press w to go back to branch picker."""

    def __init__(self, stdscr, variant: Variant) -> None:
        self.stdscr          = stdscr
        self.variant         = variant
        # device list cursor / active selection
        self.dev_cursor      = 0
        self.dev_active      = 0
        self.runner          = BuildRunner()
        self.last_action_msg = ""
        self.switch_requested = False  # set True when user wants branch picker

    # -- helpers --------------------------------------------------------------

    def _devices(self) -> List[Device]:
        return self.variant.devices

    def current_device(self) -> Optional[Device]:
        devs = self._devices()
        if not devs:
            return None
        return devs[min(self.dev_active, len(devs) - 1)]

    def _device_label(self, d: Optional[Device]) -> str:
        if d is None:
            return self.variant.name
        return f"{self.variant.name}/{d.codename}"

    # -- input ----------------------------------------------------------------

    def prompt_input(self, prompt: str) -> str:
        max_y, max_x = self.stdscr.getmaxyx()
        win = curses.newwin(3, max_x - 4, max_y // 2 - 1, 2)
        win.box()
        safe_addstr(win, 0, 2, f" {prompt} ", curses.A_REVERSE)
        win.refresh()
        curses.echo()
        curses.curs_set(1)
        try:
            raw = win.getstr(1, 2, max_x - 8)
        except curses.error:
            raw = b""
        curses.noecho()
        curses.curs_set(0)
        return raw.decode("utf-8", "replace").strip()

    # -- actions --------------------------------------------------------------

    def action_switch_device(self) -> None:
        """Make the cursor device the active one."""
        devs = self._devices()
        if not devs:
            return
        if self.dev_cursor == self.dev_active:
            d = self.current_device()
            self.last_action_msg = f"Already on {d.codename if d else '?'}"
            return
        d = devs[self.dev_cursor]
        if self.runner.is_running():
            confirm = self.prompt_input(f"Build running. Switch to {d.codename}? (y/N)")
            if confirm.lower() != "y":
                self.last_action_msg = "Switch cancelled"
                return
        self.dev_active = self.dev_cursor
        self.last_action_msg = f"Device: {d.codename}"

    def action_switch_branch(self) -> None:
        """Signal the main loop to return to the branch picker."""
        if self.runner.is_running():
            confirm = self.prompt_input("Build running. Switch branch anyway? (y/N)")
            if confirm.lower() != "y":
                self.last_action_msg = "Cancelled"
                return
        self.switch_requested = True

    def _env_extra(self) -> dict:
        d = self.current_device()
        return {"DEVICE": d.codename} if d is not None else {}

    def _build_cmd(self, extra_args: list = None) -> list:
        """Build the sudo bash ./build.sh command with -d <codename> injected."""
        d = self.current_device()
        cmd = ["sudo", "-E", "bash", "./build.sh"]
        if d is not None:
            cmd += ["-d", d.codename]
        if extra_args:
            cmd += extra_args
        return cmd

    def action_build_full(self) -> None:
        d = self.current_device()
        if self.variant is None:
            self.last_action_msg = "No branch loaded"
            return
        self.runner.start(
            cwd=self.variant.path,
            cmd=self._build_cmd(),
            env_extra=self._env_extra(),
        )
        self.last_action_msg = f"Build started: {self._device_label(d)}"

    def action_build_stage(self) -> None:
        stages = self.prompt_input("Stages (e.g. '01 02' or '04 05')")
        if not stages:
            self.last_action_msg = "Cancelled"
            return
        env = self._env_extra()
        env["STAGES"] = stages
        d = self.current_device()
        self.runner.start(
            cwd=self.variant.path,
            cmd=self._build_cmd(),
            env_extra=env,
        )
        self.last_action_msg = f"Build started ({self._device_label(d)}, stages={stages})"

    def action_clean(self) -> None:
        confirm = self.prompt_input(f"Type DELETE to wipe {self.variant.path}/build/")
        if confirm != "DELETE":
            self.last_action_msg = "Clean cancelled"
            return
        self.runner.start(cwd=self.variant.path, cmd=["sudo", "rm", "-rf", "build"])
        self.last_action_msg = f"Cleaning {self.variant.name}/build/"

    def _active_conf_path(self) -> Optional[Path]:
        d = self.current_device()
        if d is not None:
            return d.path / "device.conf"
        if self.variant.build_env is not None:
            return self.variant.build_env
        return None

    def action_view_env(self) -> None:
        path = self._active_conf_path()
        if path is None:
            self.last_action_msg = "No config file found"
            return
        try:
            text = path.read_text()
        except OSError as exc:
            self.last_action_msg = f"Cannot read: {exc}"
            return
        self.runner.clear()
        self.runner.append(f"[devkit] view {path}")
        for line in text.splitlines():
            self.runner.append(line)
        self.last_action_msg = f"Loaded {path.name}"

    def action_edit_env(self) -> None:
        path = self._active_conf_path()
        if path is None:
            self.last_action_msg = "No config file found"
            return
        editor = os.environ.get("EDITOR", "nano")
        curses.endwin()
        try:
            subprocess.call([editor, str(path)])
        finally:
            self.stdscr.refresh()
            curses.curs_set(0)
        d = self.current_device()
        if d is not None:
            d.config = parse_build_env(path)
        elif self.variant.build_env is not None:
            self.variant.config = parse_build_env(path)
        self.last_action_msg = f"Edited {path.name} (reloaded)"

    def action_cancel(self) -> None:
        if not self.runner.is_running():
            self.last_action_msg = "No build running"
            return
        self.runner.cancel()
        self.last_action_msg = "Cancel signal sent"

    def action_refresh(self) -> None:
        self.variant.devices = discover_devices(self.variant.path)
        n = len(self.variant.devices)
        self.dev_cursor = min(self.dev_cursor, max(0, n - 1))
        self.dev_active = min(self.dev_active, max(0, n - 1))
        self.last_action_msg = f"Refreshed ({n} devices)"

    # -- drawing --------------------------------------------------------------

    def draw_header(self) -> None:
        max_y, max_x = self.stdscr.getmaxyx()
        title  = f" Mobuntu Devkit  --  {self.variant.name} "
        status = f"w: switch branch "
        safe_addstr(self.stdscr, 0, 0, " " * (max_x - 1), curses.A_REVERSE)
        safe_addstr(self.stdscr, 0, 2, title,  curses.A_REVERSE | curses.A_BOLD)
        safe_addstr(self.stdscr, 0, max_x - len(status) - 2, status, curses.A_REVERSE)

    def draw_left(self, y0: int, h: int, w: int) -> None:
        devs = self._devices()
        row  = 0

        # -- Device list --
        if devs:
            safe_addstr(self.stdscr, y0 + row, 1, "[ Devices ]", curses.A_BOLD)
            row += 2
            for i, d in enumerate(devs):
                if row >= h - 4:
                    break
                is_cursor = (i == self.dev_cursor)
                is_active = (i == self.dev_active)
                marker = "*" if is_active else " "
                prefix = ">" if is_cursor else " "
                suite  = d.config.get("DEVICE_SUITE", "?")
                line   = f" {prefix} {marker} {d.codename:<12} {d.brand}/{d.model}"
                attr   = curses.A_REVERSE if is_cursor else (curses.A_BOLD if is_active else 0)
                safe_addstr(self.stdscr, y0 + row, 2, line.ljust(w - 4), attr)
                row += 1
                if is_cursor:
                    kernel = d.config.get("KERNEL_VERSION", "?")
                    detail = f"     suite={suite}  kernel={kernel}"
                    safe_addstr(self.stdscr, y0 + row, 2, detail, curses.A_DIM)
                    row += 1
            row += 1
        else:
            # No devices — show variant-level config
            safe_addstr(self.stdscr, y0 + row, 1, f"[ {self.variant.name} ]", curses.A_BOLD)
            row += 2
            suite = self.variant.config.get("UBUNTU_SUITE", "?")
            safe_addstr(self.stdscr, y0 + row, 2, f"suite={suite}", curses.A_DIM)
            row += 2

        # -- Actions --
        if row < h - len(ACTIONS) - 3:
            safe_addstr(self.stdscr, y0 + row, 1, "[ Actions ]", curses.A_BOLD)
            row += 2
            for key, label, _ in ACTIONS:
                if row >= h:
                    break
                safe_addstr(self.stdscr, y0 + row, 2, f" {key}  {label}")
                row += 1

    def draw_right(self, y0: int, x0: int, h: int, w: int) -> None:
        d     = self.current_device()
        title = f"[ {self._device_label(d)}  --  build output ]"
        safe_addstr(self.stdscr, y0, x0 + 1, title, curses.A_BOLD)

        if self.runner.is_running():
            ind = "  [ RUNNING ]"
            safe_addstr(self.stdscr, y0, x0 + w - len(ind) - 2, ind,
                        curses.A_BOLD | curses.A_BLINK)
        elif self.runner.exit_code is not None:
            tag = "[ OK ]" if self.runner.exit_code == 0 else f"[ FAIL {self.runner.exit_code} ]"
            safe_addstr(self.stdscr, y0, x0 + w - len(tag) - 2, tag, curses.A_BOLD)

        lines = self.runner.snapshot()
        max_visible = h - 4
        if len(lines) > max_visible:
            lines = lines[-max_visible:]
        for i, line in enumerate(lines):
            safe_addstr(self.stdscr, y0 + 2 + i, x0 + 2, line)

    def draw_footer(self) -> None:
        max_y, max_x = self.stdscr.getmaxyx()
        hint = "UP/DOWN: select device  Enter: activate  letter keys: action  w: branch  q: quit"
        msg  = self.last_action_msg or hint
        safe_addstr(self.stdscr, max_y - 1, 0, " " * (max_x - 1), curses.A_REVERSE)
        safe_addstr(self.stdscr, max_y - 1, 2, msg, curses.A_REVERSE)

    def draw(self) -> None:
        self.stdscr.erase()
        max_y, max_x = self.stdscr.getmaxyx()
        if max_y < 12 or max_x < 70:
            safe_addstr(self.stdscr, 0, 0,
                        "Terminal too small (need >= 70x12). Resize and press any key.")
            self.stdscr.refresh()
            return

        self.draw_header()

        left_w  = max(28, int(max_x * 0.38))
        right_x = left_w + 1
        right_w = max_x - right_x
        body_y  = 2
        body_h  = max_y - body_y - 1

        for y in range(body_y, body_y + body_h):
            safe_addstr(self.stdscr, y, left_w, "|", curses.A_DIM)

        self.draw_left(body_y, body_h, left_w)
        self.draw_right(body_y, right_x, body_h, right_w)
        self.draw_footer()
        self.stdscr.refresh()

    # -- main loop ------------------------------------------------------------

    def loop(self) -> None:
        curses.curs_set(0)
        self.stdscr.nodelay(True)
        self.stdscr.timeout(150)

        action_map = {key: name for key, _, name in ACTIONS}

        while True:
            if self.switch_requested:
                break

            self.draw()
            try:
                ch = self.stdscr.getch()
            except KeyboardInterrupt:
                break
            if ch == -1:
                continue

            devs = self._devices()

            if ch == curses.KEY_UP and devs:
                self.dev_cursor = (self.dev_cursor - 1) % len(devs)
                self.last_action_msg = ""

            elif ch == curses.KEY_DOWN and devs:
                self.dev_cursor = (self.dev_cursor + 1) % len(devs)
                self.last_action_msg = ""

            elif ch in (ord("\n"), ord("\r"), curses.KEY_ENTER):
                self.action_switch_device()

            elif ch in (ord("q"), ord("Q")):
                if self.runner.is_running():
                    confirm = self.prompt_input("Build running. Cancel and quit? (y/N)")
                    if confirm.lower() != "y":
                        continue
                    self.runner.cancel()
                break

            elif 0 < ch < 256:
                key = chr(ch).lower()
                act = action_map.get(key)
                if act is None:
                    continue
                handler = getattr(self, f"action_{act}", None)
                if handler is not None:
                    handler()
                time.sleep(0.05)


# -----------------------------------------------------------------------------
# Entrypoint
# -----------------------------------------------------------------------------

def _tui_main(stdscr, root: Path, variants: List[Variant]) -> int:
    picker_cursor = 0
    while True:
        picker = BranchPicker(stdscr, variants)
        picker.cursor = picker_cursor
        chosen = picker.run()
        if chosen is None:
            return 0
        # Remember which branch was last picked for next time
        try:
            picker_cursor = variants.index(chosen)
        except ValueError:
            picker_cursor = 0

        tui = DevkitTUI(stdscr, chosen)
        tui.loop()

        if not tui.switch_requested:
            return 0
        # Re-discover in case something changed while we were in the TUI
        variants = discover_variants(root)


def main() -> int:
    here = Path(os.getcwd())
    root = find_repo_root(here)
    variants = discover_variants(root)

    if "--list" in sys.argv:
        print(f"Repo root: {root}")
        if not variants:
            print("No variants found.")
            return 1
        for v in variants:
            print(f"  {v.name:<14}  {v.path}")
            for k in ("UBUNTU_SUITE", "FLAVOR", "L4T_RELEASE", "RELEASE_TAG"):
                if k in v.config:
                    print(f"    {k}={v.config[k]}")
            for d in v.devices:
                suite  = d.config.get("DEVICE_SUITE",  "?")
                kernel = d.config.get("KERNEL_VERSION", "?")
                print(f"    device  {d.codename:<14} {d.brand}/{d.model}"
                      f"  suite={suite}  kernel={kernel}")
        return 0

    if "--build" in sys.argv:
        idx = sys.argv.index("--build")
        try:
            target = sys.argv[idx + 1]
        except IndexError:
            print("Usage: devkit.py --build <variant>[/device]")
            return 2
        variant_name, _, device_name = target.partition("/")
        match = next((v for v in variants if v.name == variant_name), None)
        if match is None:
            print(f"No variant named {variant_name}. "
                  f"Available: {[v.name for v in variants]}")
            return 2
        env = os.environ.copy()
        if device_name:
            dev = next((d for d in match.devices if d.codename == device_name), None)
            if dev is None:
                print(f"No device {device_name} in {variant_name}. "
                      f"Available: {[d.codename for d in match.devices]}")
                return 2
            env["DEVICE"] = dev.codename
        build_cmd = ["sudo", "-E", "bash", "./build.sh"]
        if device_name:
            build_cmd += ["-d", dev.codename]
        rc = subprocess.call(build_cmd, cwd=str(match.path), env=env)
        return rc

    try:
        return curses.wrapper(_tui_main, root, variants) or 0
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    sys.exit(main())
