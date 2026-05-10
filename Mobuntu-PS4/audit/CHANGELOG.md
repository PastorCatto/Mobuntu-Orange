# Mobuntu-PS4 Changelog & Audit Log
# Codename: Spider-Man
# Maintained by: Mobuntu Project
# External audit: this file tracks every structural and script decision

---

## [0.1.0] — 2026-05-06 — Initial Scaffolding

### Project Definition
- Codename: Spider-Man (PlayStation Protoplace retired)
- Target hardware: Jailbroken PlayStation 4 (all board variants)
- Build host: Ubuntu 24.04 x86-64 — no QEMU (host and PS4 are both amd64)
- Base distro: Debian Bookworm or Trixie (Trixie recommended for Mesa 25)
- Philosophy: build rootfs + bundle initramfs + reference upstream kernel

### Architecture Decisions
- Mobuntu-PS4 does NOT build kernels — strawberry (6.18.21) sourced from
  rmuxnet/ps4-linux-12xx releases
- initramfs variants are BUNDLED from DionKill/ps4-linux-tutorial (original
  source dead — files preserved with attribution)
- Mesa 25 built via FalsePhilosopher/mesa-docker-ps4 Docker container at
  build time, or from pre-built .deb files if placed at upstream/mesa-debs/
- 7.0 kernel exists but has known boot issues — strawberry (6.18.21) is
  the stable recommendation

### Platform/Boot Mode Design
-p flag drives both initramfs selection AND boot file placement:

| -p value  | initramfs                           | Boot file destination    |
|-----------|-------------------------------------|--------------------------|
| external  | initramfs/external/                 | FAT32 USB root           |
| aeolia    | initramfs/internal-aeolia/          | /data/linux/boot/        |
| belize    | initramfs/internal-belize/          | /data/linux/boot/        |

Separate bootloader flag considered but rejected — boot mode fully implied
by -p variant. Single flag, single responsibility.

### UI Support Added
- GNUstep (primary) — minimal, X11-native, sub-600MB idle target
- LXDE (secondary) — lightweight GTK desktop
- LXQT (tertiary) — lightweight Qt desktop
- Steam installed on all variants — X11 + Steam capable

### Files Added
- `build.sh` — main entry point with -d/-p/-u/-b flags
- `devices/ps4/device.conf` — PS4 device metadata
- `scripts/build-mesa.sh` — Mesa 25 Docker build + pre-built deb fallback
- `scripts/customize-rootfs.sh` — UI install, user setup, PS4 config
- `scripts/stage-boot.sh` — initramfs + kernel + bootargs staging per platform
- `initramfs/external/initramfs.cpio.gz` — bundled, source: DionKill guide
- `initramfs/internal-aeolia/initramfs.cpio.gz` — bundled, source: DionKill guide
- `initramfs/internal-belize/initramfs.cpio.gz` — bundled, source: DionKill guide
- `upstream/UPSTREAM_SOURCES.md` — kernel/Mesa/GoldHen reference links
- `docs/INSTALL.md` — full install instructions
- `audit/CHANGELOG.md` — this file

### Initramfs Attribution
Source: https://github.com/DionKill/ps4-linux-tutorial
Original download source: dead link (archived January 2023)
Files preserved in-tree with source attribution in UPSTREAM_SOURCES.md.
Three variants cover all major PS4 board/boot configurations.

### Known Limitations (v0.1.0)
- DualShock 4 input via hid-playstation — not explicitly configured, likely
  works via kernel but not verified
- Internal HDD boot requires external USB first-boot to set up
- Mesa Docker build requires internet access and significant build time on
  first run — provide pre-built debs via upstream/mesa-debs/ to skip
- PS4 Pro (CUH-7xxx, Baikal board) not explicitly targeted — may work with
  external variant but untested

---

## Audit Trail Format
Each future entry must include:
- Version bump
- Date
- Files added/modified/removed
- Reason for each change
- Any upstream dependency changes

---

## [0.2.0] — 2026-05-10 — Spider-Man: Doctor Octavius

### Codename Split
- Spider-Man — baseline build (no Theseus), unchanged behaviour
- Spider-Man: Doctor Octavius — new variant, Theseus Xbox dashboard + session switcher

### New: -m flag in build.sh
- `-m theseus` enables Doctor Octavius mode (Theseus build + session switcher)
- `-m theseus,desktop` adds LXDE as desktop fallback alongside Theseus
- `-m desktop` alone is an error (requires theseus)
- CODENAME variable set dynamically: "Spider-Man" or "Spider-Man: Doctor Octavius"

### New: overlays/theseus/
- `etc/X11/xinit/xinitrc` — reads /var/mobuntu/session-mode, launches Theseus or LXDE
- `etc/systemd/system/mobuntu-session.service` — starts X on boot as mobuntu user, no display manager
- `var/mobuntu/session-mode` — default: console
- `session-switcher/session-switcher.c` — SDL2 C app, controller-first UI
- `session-switcher/Makefile` — pkg-config SDL2 build

### New: upstream/theseus/
- Placeholder README with clone instructions
- Theseus source must be cloned here before Doctor Octavius builds
- customize-rootfs.sh detects presence and builds from local source (no internet at build time)

### Modified: scripts/customize-rootfs.sh
- Added --theseus / --desktop flags
- Doctor Octavius path: installs xinit (not lightdm), SDL2/mpv/curl build deps,
  copies Theseus source + session-switcher into rootfs, builds both in chroot,
  enables mobuntu-session.service
- Spider-Man path: unchanged (lightdm + autologin)

### Modified: scripts/customize-rootfs.sh — debootstrap include
- lightdm removed from Stage 1 include list for Doctor Octavius builds
  (resolved at Stage 3 based on --theseus flag)
- Note: Stage 1 still includes lightdm in --include for baseline Spider-Man

### Modified: upstream/UPSTREAM_SOURCES.md
- Added Theseus entry (MrMilenko/Theseus)
- Added session-switcher entry

### Modified: README.md, docs/INSTALL.md
- Updated for 0.2.0, both codenames documented

### Known Limitations (v0.2.0)
- Session switcher renders coloured boxes only (no text) — SDL2 TTF not linked
  to keep deps minimal. Text labels planned for 0.3.0.
- SELECT+START hold detection not yet wired into Theseus itself — must be
  launched as a separate process via a wrapper or keybinding for now.
- Theseus DualShock 4 axis mapping unverified on real PS4 hardware.
- LXDE desktop fallback untested with Mesa 25 / PS4 GCN GPU.
