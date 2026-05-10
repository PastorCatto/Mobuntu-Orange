# Mobuntu-PS4
**Codenames: Spider-Man / Spider-Man: Doctor Octavius**
**Version: 0.2.0**

Minimal Debian-based Linux image builder for jailbroken PlayStation 4 consoles.
Builds a rootfs, bundles the correct initramfs for your boot mode, and references
the upstream strawberry kernel (6.18.21). Sub-600MB RAM idle target. X11 + Steam capable.

| Codename | Description |
|----------|-------------|
| Spider-Man | Baseline — minimal rootfs, traditional desktop UI |
| Spider-Man: Doctor Octavius | Theseus Xbox dashboard as primary UI, controller-first session switcher |

## Philosophy
- Kernel sourced from upstream (rmuxnet/ps4-linux-12xx) — NOT built here
- initramfs variants bundled with attribution (source: DionKill/ps4-linux-tutorial)
- Mesa 25 built via Docker (FalsePhilosopher/mesa-docker-ps4) or pre-built debs
- Every decision tracked in audit/CHANGELOG.md

## Quick Start

### Spider-Man (baseline)
```bash
# Place bzImage from rmuxnet/ps4-linux-12xx releases at upstream/bzImage
sudo ./build.sh -d ps4 -p external
```

### Spider-Man: Doctor Octavius (Theseus)
```bash
# Place bzImage AND clone Theseus source:
git clone https://github.com/MrMilenko/Theseus upstream/theseus

# Theseus + LXDE desktop fallback
sudo ./build.sh -d ps4 -p external -m theseus,desktop
```

## Flags
| Flag | Description | Options |
|------|-------------|---------|
| `-d` | Device codename | `ps4` (required) |
| `-p` | Platform/boot variant | `external` `aeolia` `belize` (required) |
| `-u` | UI selection | `gnustep` `lxde` `lxqt` |
| `-b` | Debian suite | `bookworm` `trixie` |
| `-m` | Mode overlays | `theseus` `desktop` (comma-separated) |

## Platform Variants
| `-p` | Board | Boot source |
|------|-------|-------------|
| `external` | Any | USB FAT32 root |
| `aeolia` | Fat PS4 (older) | Internal `/data/linux/boot/` |
| `belize` | PS4 Slim/newer | Internal `/data/linux/boot/` |

## Doctor Octavius — Session Switcher
Boot defaults to Theseus (Xbox dashboard). Hold **SELECT + START** for 3 seconds
at any time to open the session switcher. Navigate with D-pad or left stick,
confirm with Cross, cancel with Circle. No keyboard required.

## Structure
```
Mobuntu-PS4/
  build.sh                        <- entry point
  devices/ps4/device.conf         <- device metadata
  scripts/build-mesa.sh           <- Mesa 25 via Docker
  scripts/customize-rootfs.sh     <- UI + user + PS4 config
  scripts/stage-boot.sh           <- initramfs + kernel + bootargs
  overlays/
    theseus/                      <- Doctor Octavius overlay
      session-switcher/           <- SDL2 controller-friendly switcher (C)
      etc/X11/xinit/xinitrc       <- startx session entry
      etc/systemd/system/         <- mobuntu-session.service
      var/mobuntu/session-mode    <- default: console
  initramfs/                      <- bundled initramfs variants
  upstream/
    bzImage                       <- place here from rmuxnet releases
    theseus/                      <- place here: git clone MrMilenko/Theseus
    UPSTREAM_SOURCES.md
    mesa-debs/                    <- optional pre-built Mesa .deb files
  docs/INSTALL.md
  audit/CHANGELOG.md
```

## Related Projects
- Mobuntu-SDM845 (Poco F1 / beryllium) — main project
- Mobuntu-L4T (Nintendo Switch) — Happy Mask Salesman
