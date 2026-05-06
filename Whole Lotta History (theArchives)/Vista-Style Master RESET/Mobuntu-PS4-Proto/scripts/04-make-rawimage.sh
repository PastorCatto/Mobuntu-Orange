#!/usr/bin/env bash
# =============================================================================
# 04-make-rawimage.sh  (PS4 variant)
# Identical strategy to Mobuntu-L4T stage 04 — mke2fs -d to avoid loop mounts.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../build.env"

log()  { printf '[04 %s] %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '[04 WARN] %s\n' "$*" >&2; }
fail() { printf '[04 FAIL] %s\n' "$*" >&2; exit 1; }

[[ -d "${ROOTFS_DIR}" ]] || fail "Rootfs not found at ${ROOTFS_DIR}"

command -v mke2fs >/dev/null 2>&1 || { apt-get update -qq && apt-get install -y e2fsprogs; }

RAW_IMG="${IMAGE_DIR}/rootfs.img"
mkdir -p "${IMAGE_DIR}"

ROOTFS_SIZE_ACTUAL_MIB=$(du -sm "${ROOTFS_DIR}" | awk '{print $1}')
log "Rootfs actual size: ${ROOTFS_SIZE_ACTUAL_MIB} MiB / allocated: ${ROOTFS_SIZE_MIB} MiB"

if (( ROOTFS_SIZE_ACTUAL_MIB + 512 > ROOTFS_SIZE_MIB )); then
    fail "ROOTFS_SIZE_MIB=${ROOTFS_SIZE_MIB} too small for rootfs (${ROOTFS_SIZE_ACTUAL_MIB} MiB + 512 MiB headroom). Bump in build.env."
fi

log "Allocating ${ROOTFS_SIZE_MIB} MiB raw ext4 image"
rm -f "${RAW_IMG}"
truncate -s "${ROOTFS_SIZE_MIB}M" "${RAW_IMG}"

log "Building ext4 from rootfs (mke2fs -d)"
mke2fs \
    -t ext4 \
    -L "MOBU-PS4" \
    -d "${ROOTFS_DIR}" \
    -E lazy_itable_init=0,lazy_journal_init=0 \
    "${RAW_IMG}" \
    "${ROOTFS_SIZE_MIB}M"

log "Re-enabling ext4 journal"
tune2fs -O has_journal "${RAW_IMG}"

log "Stage 04 done. rootfs.img: $(du -m "${RAW_IMG}" | awk '{print $1}') MiB"
