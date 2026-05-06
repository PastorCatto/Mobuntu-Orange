# Mobuntu — Changelog

---

## May 6, 2026 — Spider-Man Scaffold + L4T Architecture Pivot + devkit Fix

### devkit.py — Build Argument Fix
build.sh uses `getopts -d <codename>` but devkit was passing DEVICE only as
an env var. Fixed via new `_build_cmd()` helper that injects `-d <codename>`
as a CLI arg. Both TUI and CLI `--build` paths updated.

### Mobuntu-PS4 (Spider-Man) — Initial Scaffold [0.1.0]
Full scaffold delivered. Key decisions:

| Decision | Choice | Reason |
|----------|--------|--------|
| Base distro | Debian Bookworm/Trixie | Mesa 25 available; no Ubuntu overhead |
| Kernel | strawberry 6.18.21 (upstream ref) | Stable; 7.0 has boot issues |
| initramfs | Bundled 3 variants | Original source dead; preserved with attribution |
| Mesa | Docker build (FalsePhilosopher) | Reproducible PS4-patched build |
| Boot flag | `-p external|aeolia|belize` | Single flag drives initramfs + boot file placement |
| UIs | GNUstep (primary), LXDE, LXQT | Sub-600MB idle; X11 + Steam capable |

**Platform variants (-p flag):**
- `external` — USB/FAT32 boot, any board, initramfs/external/
- `aeolia` — internal HDD, fat PS4, initramfs/internal-aeolia/
- `belize` — internal HDD, PS4 Slim/newer, initramfs/internal-belize/

**Files added:** build.sh, devices/ps4/device.conf, scripts/build-mesa.sh,
scripts/customize-rootfs.sh, scripts/stage-boot.sh, 3x initramfs variants,
upstream/UPSTREAM_SOURCES.md, docs/INSTALL.md, audit/CHANGELOG.md

**Upstream references:**
- Kernel: https://github.com/rmuxnet/ps4-linux-12xx (6.18.21 = strawberry)
- Mesa: https://github.com/FalsePhilosopher/mesa-docker-ps4
- initramfs source: https://github.com/DionKill/ps4-linux-tutorial (archived)
- Guide: https://dionkill.github.io/ps4-linux-tutorial/

### Mobuntu-L4T (Happy Mask Salesman) — Architecture Pivot + Initial Scaffold [0.1.0]
5-stage standalone pipeline replaced with thin wrapper on upstream Switchroot
l4t-image-buildscripts. Codename assigned: Happy Mask Salesman (dev), Tatl/Majora (release).
UIs: Phosh, Plasma Mobile, KDE, LXDE, MATE. GNOME excluded (known L4T regressions).
Joy-Con via joycond + Hekate calibration dump. Full audit trail in Mobuntu-L4T/audit/.



## May 2, 2026 — Multi-Platform Expansion

### Project Rename
- **Mobuntu Orange** is now **Mobuntu**. Releases are color-coded going forward. The name change is cosmetic; the upstream baseline and build architecture are unchanged.

### New Variant: Mobuntu-L4T (Nintendo Switch)
5-script bash pipeline targeting Nintendo Switch (Tegra X1, T210/T210B01) via the switchroot L4T stack.

| Detail | Value |
|--------|-------|
| Kernel | CTCaer/switch-l4t-kernel-4.9 (`linux-5.1.2`) + kernel-nvidia + platform-t210-nx |
| Distro debs | theofficialgman/l4t-debs (prebuilt, no kernel compilation by default) |
| Output | hekate-installable `.7z` — extract to SD FAT32, then hekate Flash Linux |
| Bootloader | hekate >= 6.0.6 required |
| Suite | Ubuntu Noble 24.04 |
| SD layout | `bootloader/ini/L4T-Mobuntu.ini` + `switchroot/install/l4t.NN` chunks + `switchroot/mobuntu/` branding |

Build host: Ubuntu 24.04 x86-64 (WSL2 supported). arm64 target — uses `qemu-user-static`, same host detection logic as the SDM845 pipeline.

Pipeline stages mirror the SDM845 pattern: bootstrap → fetch debs → customize chroot → `mke2fs -d` raw image → split + 7z.

### New Variant: Mobuntu-PS4 (PlayStation 4)
5-script bash pipeline targeting PS4 consoles on firmware 12.52 via GoldHen.

| Detail | Value |
|--------|-------|
| Hardware | CUH-12xx (Belize/Aeolia southbridge) |
| Kernel | feeRnt/ps4-linux-12xx (6.15.4, March 2026) — WiFi/BT for Marvell 8897 |
| Kernel mode | `prebuilt` (GitHub release fetch via API) or `source` (compile from repo) |
| Output | Raw MBR disk image — `dd` directly to USB drive |
| USB layout | p1: FAT32 (bzImage + initramfs.cpio.gz) / p2: ext4 (rootfs, label MOBU-PS4) |
| Suite | Ubuntu Noble 24.04 |

Build host: any Ubuntu 24.04 x86-64. **No QEMU** — host and target are both amd64. Simplest variant by far.

Known-good kernel cmdline:
```
panic=0 clocksource=tsc consoleblank=0 net.ifnames=0 radeon.dpm=0 amdgpu.dpm=0
drm.debug=0 console=uart8250,mmio32,0xd0340000 console=ttyS0,115200n8
console=tty0 drm.edid_firmware=edid/1920x1080.bin
```

### devkit.py — Multi-Variant Auto-Runner
`devkit.py` has been updated to detect and drive all Mobuntu variants from a single repo root. It walks up from the current directory to find the repo root, then scans for known variant folders and parses each `build.env`.

Detected variants:

| Folder | Purpose |
|--------|---------|
| `Mobuntu/` | SDM845 phones (existing) |
| `Mobuntu-PDK/` | Ubuntu PDK adaptation (planned) |
| `Mobuntu-L4T/` | Nintendo Switch |
| `Mobuntu-PS4/` | PlayStation 4 |

Modes:

```bash
python3 devkit.py               # full curses TUI (split-pane, ASCII-only)
python3 devkit.py --list        # headless variant + config summary
python3 devkit.py --build <variant>  # headless build dispatch
```

Build.env parser updated to correctly handle `${VAR:-default}` patterns and strip inline shell comments.

---

## May 1, 2026 — Grand Developer Kit Reset

### Summary

Mobuntu has transitioned from a standalone RC-numbered build pipeline to a wrapper layer built directly on top of **arkadin91/mobuntu-recipes**. This is the foundation for all future development.

### Architecture Shift

The legacy RC pipeline (RC1–RC17) is retired as a development baseline. All future versions build on top of upstream `arkadin91/mobuntu-recipes`, with Mobuntu customizations applied as a clean layer on top.

| Before | After |
|--------|-------|
| Standalone 5-script bash pipeline | Wrapper on arkadin91/mobuntu-recipes |
| Manual upstream tracking | `sync.py` auto-pulls and merges upstream |
| Hardcoded device values in scripts | Per-device `device.conf` files |
| RC-versioned release branches | Continuous integration on upstream HEAD |

**Build performance:** arkadin91's debos pipeline is approximately 50% faster with a 60% reduction in total build time versus the legacy RC pipeline.

### Multi-Device Support
- `devices/beryllium/` — Xiaomi Poco F1, plucky, confirmed booting
- `devices/fajita/` — OnePlus 6T, resolute, confirmed booting
- `devices/enchilada/` — OnePlus 6, stubbed, pending validation

### `build.sh` — Multi-Device Entrypoint
Replaces upstream's minimal single-device script with full argument parsing, device conf loading, suite override support, resolute double-confirmation gate, and debos variable passthrough.

### `sync.py` — Upstream Sync Engine
Pulls latest upstream, extracts hardcoded device vars, updates device confs, and tracks sync state via SHA comparison. Pinned files are never overwritten.

### Bug Fix — debos environment passthrough
debos silently ignores environment blocks on script actions. Fixed by overlaying scripts into the rootfs and calling them via command with template-expanded inline variables.

### Upstream Baseline

- **Upstream:** arkadin91/mobuntu-recipes — main branch
- **Kernel:** linux-image-6.18-sdm845 via Mobian apt repo
- **Firmware:** bundled debs in files/ installed via /opt/*.deb
- **Audio fix:** Mobian alsa-ucm-conf + mask alsa-state, alsa-restore
- **Suite:** upstream defaults to resolute — Mobuntu defaults to plucky for SDM845 stability
