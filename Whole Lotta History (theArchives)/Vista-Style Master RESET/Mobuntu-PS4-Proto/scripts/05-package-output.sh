#!/usr/bin/env bash
# =============================================================================
# 05-package-output.sh  (PS4 variant)
# Assembles a raw disk image with two partitions:
#
#   Partition 1: FAT32 (${BOOT_PART_SIZE_MIB} MiB)
#       /bzImage
#       /initramfs.cpio.gz
#       /cmdline.txt         <- kernel cmdline hint, not used by payload directly
#
#   Partition 2: ext4 (${ROOTFS_SIZE_MIB} MiB)
#       [rootfs contents from stage 04]
#
# dd the output image directly to a USB drive:
#   sudo dd if=output/mobuntu-ps4-noble-dev.img of=/dev/sdX bs=4M status=progress conv=fsync
#
# On the PS4 side the GoldHen/kexec payload loads bzImage + initramfs from
# either the FAT32 partition or the internal /data/linux/boot/ path (after
# first boot auto-copy, if the payload supports it).
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../build.env"

log()  { printf '[05 %s] %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '[05 WARN] %s\n' "$*" >&2; }
fail() { printf '[05 FAIL] %s\n' "$*" >&2; exit 1; }

ROOTFS_IMG="${IMAGE_DIR}/rootfs.img"
[[ -f "${ROOTFS_IMG}" ]] || fail "rootfs.img not found at ${ROOTFS_IMG}. Run stage 04 first."

command -v parted   >/dev/null 2>&1 || apt-get install -y --no-install-recommends parted
command -v mkdosfs  >/dev/null 2>&1 || apt-get install -y --no-install-recommends dosfstools
command -v mcopy    >/dev/null 2>&1 || apt-get install -y --no-install-recommends mtools

OUTPUT_PATH="${OUTPUT_DIR}/${OUTPUT_IMG}"
mkdir -p "${OUTPUT_DIR}"
rm -f "${OUTPUT_PATH}"

# ---- Geometry (all in MiB) --------------------------------------------------
SECTOR=512
MIB=$((1024*1024))
SECTORS_PER_MIB=$(( MIB / SECTOR ))

GPT_OVERHEAD_MIB=2
BOOT_START_MIB=1
BOOT_END_MIB=$(( BOOT_START_MIB + BOOT_PART_SIZE_MIB - 1 ))
ROOT_START_MIB=$(( BOOT_END_MIB + 1 ))
ROOT_END_MIB=$(( ROOT_START_MIB + ROOTFS_SIZE_MIB - 1 ))
TOTAL_MIB=$(( ROOT_END_MIB + GPT_OVERHEAD_MIB + 1 ))

log "Disk layout:"
log "  Partition 1 (FAT32): ${BOOT_START_MIB}..${BOOT_END_MIB} MiB (${BOOT_PART_SIZE_MIB} MiB)"
log "  Partition 2 (ext4):  ${ROOT_START_MIB}..${ROOT_END_MIB} MiB (${ROOTFS_SIZE_MIB} MiB)"
log "  Total image:         ${TOTAL_MIB} MiB"

# ---- Allocate and partition -------------------------------------------------
log "Allocating image: ${OUTPUT_PATH}"
truncate -s "${TOTAL_MIB}M" "${OUTPUT_PATH}"

log "Partitioning with MBR (DOS) table (PS4 kexec payloads use MBR)"
parted -s "${OUTPUT_PATH}" \
    mklabel msdos \
    mkpart primary fat32 "${BOOT_START_MIB}MiB" "${BOOT_END_MIB}MiB" \
    mkpart primary ext4  "${ROOT_START_MIB}MiB"  "${ROOT_END_MIB}MiB" \
    set 1 boot on

# ---- Format FAT32 boot partition via mtools (no loopback mount) -------------
BOOT_OFFSET_SECTORS=$(( BOOT_START_MIB * SECTORS_PER_MIB ))
BOOT_SIZE_SECTORS=$(( BOOT_PART_SIZE_MIB * SECTORS_PER_MIB ))

log "Formatting boot partition (FAT32, mtools)"
MFORMAT_OPTS="-i ${OUTPUT_PATH}@@$((BOOT_OFFSET_SECTORS * SECTOR)) -F -v MOBU-BOOT"
# shellcheck disable=SC2086
mformat ${MFORMAT_OPTS}

mtools_env="MTOOLS_SKIP_CHECK=1 MTOOLS_FAT_COMPATIBILITY=1"
mtool() {
    env MTOOLS_SKIP_CHECK=1 "$@" -i "${OUTPUT_PATH}@@$((BOOT_OFFSET_SECTORS * SECTOR))"
}

# ---- Copy kernel artifacts --------------------------------------------------
if [[ -f "${KERNEL_DIR}/bzImage" ]]; then
    log "Copying bzImage to boot partition"
    mcopy -i "${OUTPUT_PATH}@@$((BOOT_OFFSET_SECTORS * SECTOR))" "${KERNEL_DIR}/bzImage" "::/bzImage"
else
    warn "No bzImage at ${KERNEL_DIR}/bzImage (catch-and-warn: skipping). PS4 will not boot without it."
fi

if [[ -f "${KERNEL_DIR}/initramfs.cpio.gz" ]]; then
    log "Copying initramfs.cpio.gz to boot partition"
    mcopy -i "${OUTPUT_PATH}@@$((BOOT_OFFSET_SECTORS * SECTOR))" \
        "${KERNEL_DIR}/initramfs.cpio.gz" "::/initramfs.cpio.gz"
else
    warn "No initramfs.cpio.gz at ${KERNEL_DIR}/initramfs.cpio.gz (catch-and-warn: skipping)."
fi

# cmdline hint
CMDLINE_TMP="$(mktemp)"
echo "${PS4_CMDLINE}" > "${CMDLINE_TMP}"
mcopy -i "${OUTPUT_PATH}@@$((BOOT_OFFSET_SECTORS * SECTOR))" "${CMDLINE_TMP}" "::/cmdline.txt"
rm -f "${CMDLINE_TMP}"

# ---- Embed rootfs.img into partition 2 -------------------------------------
ROOT_OFFSET_BYTES=$(( ROOT_START_MIB * MIB ))
ROOT_SIZE_BYTES=$(( ROOTFS_SIZE_MIB * MIB ))
ROOTFS_SIZE_BYTES=$(stat -c%s "${ROOTFS_IMG}")

log "Embedding rootfs.img into partition 2 (dd)"
dd if="${ROOTFS_IMG}" of="${OUTPUT_PATH}" \
    bs=1M \
    seek="${ROOT_START_MIB}" \
    conv=notrunc \
    status=progress

TOTAL_SIZE_MIB=$(du -m "${OUTPUT_PATH}" | awk '{print $1}')
log "Stage 05 done."
log ""
log "Output: ${OUTPUT_PATH} (${TOTAL_SIZE_MIB} MiB)"
log ""
log "Write to USB (replace /dev/sdX — CHECK BEFORE RUNNING):"
log "  sudo dd if='${OUTPUT_PATH}' of=/dev/sdX bs=4M status=progress conv=fsync"
log ""
log "On PS4 side (GoldHen + Linux payload):"
log "  - The payload reads bzImage + initramfs.cpio.gz from partition 1 (FAT32)"
log "  - The rootfs is on partition 2 (ext4, label MOBU-PS4)"
log "  - First boot: login mobuntu/mobuntu, change password immediately"
log "  - Kernel cmdline is in /etc/mobuntu/kernel-cmdline.txt for reference"
