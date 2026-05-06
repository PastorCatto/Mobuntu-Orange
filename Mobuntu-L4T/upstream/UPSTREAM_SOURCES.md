# Mobuntu-L4T — Upstream Sources Reference
# Codename: Happy Mask Salesman
# Version: 0.1.0
#
# Mobuntu-L4T does NOT build kernels or initramfs.
# Source these from upstream before building or flashing.

---

## Switchroot L4T Build Scripts (REQUIRED — upstream)
URL: https://github.com/nicman23/joycond
Purpose: Joy-Con daemon
License: GPL-3.0

---

## Switchroot L4T Image Build Scripts (REQUIRED — upstream)
URL: https://github.com/switchroot/l4t-image-buildscripts
Branch: main
Purpose: Base L4T image generation (apply.sh, apply_binaries.sh, create_image.sh)
Setup:
    git submodule add https://github.com/switchroot/l4t-image-buildscripts \
        upstream/l4t-image-buildscripts

---

## Switchroot Kernel (REQUIRED)
Purpose: Linux kernel for Nintendo Switch
Source: https://gitlab.com/switchroot/kernel/linux-nintendo-switch
Recommended branch: L4T-5.1.x (Noble) or L4T-4.9.x (Jammy)
NOTE: Mobuntu-L4T does NOT build kernels. Pull pre-built from Switchroot releases.
Releases: https://gitlab.com/switchroot/kernel/linux-nintendo-switch/-/releases

---

## Switchroot Initramfs (REQUIRED)
Purpose: Early boot environment
Source: Bundled with Switchroot kernel releases above
Place at: upstream/l4t-image-buildscripts/files/ per upstream instructions

---

## joycond (Joy-Con daemon — included via apt)
URL: https://github.com/nicman23/joycond
Package: Available in Switchroot apt repo (applied via BSP layer)
Calibration: Handled by Hekate — see docs/HEKATE_CALIBRATION.md

---

## Hekate Bootloader
URL: https://github.com/CTCaer/hekate/releases
Purpose: Bootloader, Joy-Con calibration dump
See: docs/HEKATE_CALIBRATION.md

---

## Checksums
# Update this section when pinning to specific upstream releases.
# Format: sha256sum  filename

# KERNEL_SHA256=
# INITRAMFS_SHA256=

---
Last updated: 2026-05-06
