# Mobuntu-PS4 — Upstream Sources Reference
# Codename: Spider-Man
# Version: 0.1.0
# Last Updated: 2026-05-06
#
# Mobuntu-PS4 does NOT build kernels.
# Place bzImage from upstream at upstream/bzImage before building.

---

## Kernel — strawberry (6.18.21) [RECOMMENDED — STABLE]
Repo:    https://github.com/rmuxnet/ps4-linux-12xx
Release: 6.18.21 (strawberry)
File:    bzImage
Place at: upstream/bzImage

NOTE: 7.0 kernel also available in releases but has known boot issues.
      Use strawberry (6.18.21) unless you know what you're doing.

Kernel lineage:
  fail0verflow/ps4-linux
    → codedwrench/ps4-linux
      → feeRnt/ps4-linux-12xx
        → rmuxnet/ps4-linux-12xx

## Initramfs [BUNDLED — sourced from DionKill/ps4-linux-tutorial]
Three variants pre-bundled in initramfs/ directory.
Original source: https://github.com/DionKill/ps4-linux-tutorial (guide)
Original download source: archived (dead link — files preserved here)

| Variant          | Path                                    | Use case              |
|------------------|-----------------------------------------|-----------------------|
| external         | initramfs/external/initramfs.cpio.gz    | USB/external storage  |
| internal-aeolia  | initramfs/internal-aeolia/initramfs.cpio.gz | Internal, fat PS4 |
| internal-belize  | initramfs/internal-belize/initramfs.cpio.gz | Internal, Slim    |

## Mesa 25 — PS4-patched [BUILT AT BUILD TIME via Docker]
Docker repo: https://github.com/FalsePhilosopher/mesa-docker-ps4
Patch source: https://github.com/kreciorek/mesa-ps4patch

If you have pre-built Debian .deb files, place them at:
  upstream/mesa-debs/*.deb
build-mesa.sh will use these instead of triggering a Docker build.

Known pre-built Debian sources:
  - triki1's Debian Trixie release (Mesa 25.0.5) — ps4linux.com forums
  - Debian experimental repo: deb http://deb.debian.org/debian experimental main

## Build Guide Reference
Guide:   https://dionkill.github.io/ps4-linux-tutorial/
GitHub:  https://github.com/DionKill/ps4-linux-tutorial

## GoldHen (Jailbreak payload)
URL:     https://github.com/GoldHEN/GoldHEN
Purpose: Required to jailbreak PS4 before loading Linux payload
Firmware support: varies by release — check releases page

---

## Checksums
# Update when pinning to specific kernel release
# Format: sha256sum  filename

# BZIMAGE_SHA256=
# INITRAMFS_EXTERNAL_SHA256=
# INITRAMFS_AEOLIA_SHA256=
# INITRAMFS_BELIZE_SHA256=

---
Last updated: 2026-05-06
