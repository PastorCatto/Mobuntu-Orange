#!/usr/bin/env bash
# scripts/stage-boot.sh
# Stages bzImage and initramfs.cpio.gz into the correct output layout
# based on the -p platform flag (external | aeolia | belize).
#
# External:  outputs a ready-to-copy FAT32 folder structure
# Internal:  outputs files for placement at /data/linux/boot/ on PS4 HDD

set -euo pipefail

PLATFORM="" BOOT_MODE="" INITRAMFS_SRC="" KERNEL_SRC="" OUTPUT_DIR="" TARBALL=""
SUMMARY_ONLY=false

cyan()  { echo -e "\e[96m    $*\e[0m"; }
green() { echo -e "\e[92m    $*\e[0m"; }
error() { echo -e "\e[91mERROR: $*\e[0m" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --platform)      PLATFORM="$2";      shift 2 ;;
        --boot-mode)     BOOT_MODE="$2";     shift 2 ;;
        --initramfs-src) INITRAMFS_SRC="$2"; shift 2 ;;
        --kernel-src)    KERNEL_SRC="$2";    shift 2 ;;
        --output-dir)    OUTPUT_DIR="$2";    shift 2 ;;
        --tarball)       TARBALL="$2";       shift 2 ;;
        --summary)       SUMMARY_ONLY=true;  shift ;;
        *) error "Unknown arg: $1" ;;
    esac
done

# ── Summary mode (called post-build for instructions) ─────────────────────────
if [ "$SUMMARY_ONLY" = true ]; then
    case "$BOOT_MODE" in
        external)
            echo -e "\e[96m  Flash instructions (external boot):\e[0m"
            echo "    1. Format USB (>=16GB, USB 3.0) — FAT32 (p1) + ext4 (p2, label: MOBU-PS4)"
            echo "    2. Copy output/boot-files/* to FAT32 root"
            echo "    3. Extract rootfs tarball to ext4 partition:"
            echo "       sudo tar -xJf output/mobuntu-ps4-*.tar.xz -C /mnt/usb-ext4/"
            echo "    4. Jailbreak PS4 with GoldHen, launch Linux payload"
            ;;
        internal)
            echo -e "\e[96m  Flash instructions (internal boot — ${PLATFORM}):\e[0m"
            echo "    1. Boot PS4 into Linux via USB first (use external variant)"
            echo "    2. From rescue shell, mount internal HDD"
            echo "    3. Copy output/boot-files/* to /data/linux/boot/ on internal HDD"
            echo "    4. Extract rootfs tarball to internal ext4 partition"
            echo "    5. Reboot — payload will auto-detect internal boot files"
            ;;
    esac
    exit 0
fi

[ -f "$INITRAMFS_SRC" ] || error "Initramfs not found: ${INITRAMFS_SRC}"
[ -f "$KERNEL_SRC" ]    || error "Kernel not found: ${KERNEL_SRC}"
[ -d "$OUTPUT_DIR" ]    || error "Output dir not found: ${OUTPUT_DIR}"

BOOT_OUT="${OUTPUT_DIR}/boot-files"
mkdir -p "$BOOT_OUT"

# ── Copy kernel and initramfs ─────────────────────────────────────────────────
cyan "Staging boot files for platform: ${PLATFORM}..."
cp "$KERNEL_SRC"    "${BOOT_OUT}/bzImage"
cp "$INITRAMFS_SRC" "${BOOT_OUT}/initramfs.cpio.gz"

# ── Write bootargs.txt ────────────────────────────────────────────────────────
cat > "${BOOT_OUT}/bootargs.txt" <<EOF
panic=0 clocksource=tsc consoleblank=0 net.ifnames=0 radeon.dpm=0 amdgpu.dpm=0 drm.debug=0 console=uart8250,mmio32,0xd0340000 console=ttyS0,115200n8 console=tty0 drm.edid_firmware=edid/1920x1080.bin
EOF

# ── Platform-specific layout notes ───────────────────────────────────────────
case "$BOOT_MODE" in
    external)
        cat > "${BOOT_OUT}/INSTALL_NOTES.txt" <<EOF
Mobuntu-PS4 — External Boot (${PLATFORM})
==========================================
Platform: Any PS4 board (Aeolia/Belize/Baikal)

FAT32 partition (USB root):
  bzImage
  initramfs.cpio.gz
  bootargs.txt         (optional cmdline override)

ext4 partition (label: MOBU-PS4):
  <extract rootfs tarball here>
  sudo tar -xJf mobuntu-ps4-*.tar.xz -C /mnt/ext4-partition/

See docs/INSTALL.md for full instructions.
EOF
        ;;
    internal)
        cat > "${BOOT_OUT}/INSTALL_NOTES.txt" <<EOF
Mobuntu-PS4 — Internal Boot (${PLATFORM})
==========================================
Board: $(echo "$PLATFORM" | tr '[:lower:]' '[:upper:]')

Internal HDD path: /data/linux/boot/
  bzImage
  initramfs.cpio.gz
  bootargs.txt         (optional cmdline override)

Rootfs: extract to internal ext4 partition (label: MOBU-PS4)
  sudo tar -xJf mobuntu-ps4-*.tar.xz -C /mnt/internal-ext4/

NOTE: First boot must use external USB to set up internal HDD.
See docs/INSTALL.md for full instructions.
EOF
        ;;
esac

green "Boot files staged at: output/boot-files/"
ls -lh "${BOOT_OUT}/"
