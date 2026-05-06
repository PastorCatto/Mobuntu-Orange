# Mobuntu-PS4
**Codename: Spider-Man**
**Version: 0.1.0**

Minimal Debian-based Linux image builder for jailbroken PlayStation 4 consoles.
Builds a rootfs, bundles the correct initramfs for your boot mode, and references
the upstream strawberry kernel (6.18.21). Sub-600MB RAM idle target. X11 + Steam capable.

## Philosophy
- Kernel sourced from upstream (rmuxnet/ps4-linux-12xx) — NOT built here
- initramfs variants bundled with attribution (source: DionKill/ps4-linux-tutorial)
- Mesa 25 built via Docker (FalsePhilosopher/mesa-docker-ps4) or pre-built debs
- Every decision tracked in audit/CHANGELOG.md

## Quick Start
```bash
# Place bzImage from rmuxnet/ps4-linux-12xx releases at:
upstream/bzImage

# Build for USB/external boot
sudo ./build.sh -d ps4 -p external

# Build for internal HDD (fat PS4 — Aeolia board)
sudo ./build.sh -d ps4 -p aeolia

# Build for internal HDD (PS4 Slim — Belize board)
sudo ./build.sh -d ps4 -p belize
```

## Flags
| Flag | Description | Options |
|------|-------------|---------|
| `-d` | Device codename | `ps4` (required) |
| `-p` | Platform/boot variant | `external` `aeolia` `belize` (required) |
| `-u` | UI selection | `gnustep` `lxde` `lxqt` |
| `-b` | Debian suite | `bookworm` `trixie` |

## Platform Variants
| `-p` | Board | Boot source |
|------|-------|-------------|
| `external` | Any | USB FAT32 root |
| `aeolia` | Fat PS4 (older) | Internal `/data/linux/boot/` |
| `belize` | PS4 Slim/newer | Internal `/data/linux/boot/` |

## UI Options
| UI | Notes |
|----|-------|
| `gnustep` | Primary — minimal overhead |
| `lxde` | Lightweight GTK |
| `lxqt` | Lightweight Qt |

## Structure
```
Mobuntu-PS4/
  build.sh                        ← entry point
  devices/ps4/device.conf         ← device metadata
  scripts/build-mesa.sh           ← Mesa 25 via Docker
  scripts/customize-rootfs.sh     ← UI + user + PS4 config
  scripts/stage-boot.sh           ← initramfs + kernel + bootargs
  initramfs/                      ← bundled initramfs variants
    external/
    internal-aeolia/
    internal-belize/
  upstream/
    bzImage                       ← place here from rmuxnet releases
    UPSTREAM_SOURCES.md           ← all upstream references + checksums
    mesa-debs/                    ← optional pre-built Mesa .deb files
  docs/INSTALL.md
  audit/CHANGELOG.md
```

## Related Projects
- Mobuntu-SDM845 (Poco F1 / beryllium) — main project
- Mobuntu-L4T (Nintendo Switch) — Happy Mask Salesman
