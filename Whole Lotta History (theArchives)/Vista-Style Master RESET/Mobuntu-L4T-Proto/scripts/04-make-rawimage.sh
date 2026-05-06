#!/usr/bin/env bash
# =============================================================================
# 04-make-rawimage.sh
# Builds a raw ext4 disk image from the customized rootfs. Hekate's
# "Flash Linux" expects this format (split into l4t.NN chunks in stage 05).
#
# Uses mke2fs -d to populate the image directly without loop-mounting —
# faster and works inside WSL2 where loop devices can be flaky.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../build.env
source "${SCRIPT_DIR}/../build.env"

log()  { printf '[04 %s] %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '[04 WARN] %s\n' "$*" >&2; }
fail() { printf '[04 FAIL] %s\n' "$*" >&2; exit 1; }

[[ -d "${ROOTFS_DIR}" ]] || fail "Rootfs not found at ${ROOTFS_DIR}"

command -v mke2fs >/dev/null 2>&1 || { apt-get update -qq && apt-get install -y --no-install-recommends e2fsprogs; }

RAW_IMG="${IMAGE_DIR}/l4t.img"
mkdir -p "${IMAGE_DIR}"

# ---- Sanity: rootfs size vs configured image size ---------------------------
ROOTFS_SIZE_MIB=$(du -sm "${ROOTFS_DIR}" | awk '{print $1}')
log "Rootfs size: ${ROOTFS_SIZE_MIB} MiB / Image size: ${IMAGE_SIZE_MIB} MiB"

if (( ROOTFS_SIZE_MIB + 512 > IMAGE_SIZE_MIB )); then
    fail "Image size ${IMAGE_SIZE_MIB} MiB too small for rootfs (${ROOTFS_SIZE_MIB} MiB + 512 MiB headroom). Bump IMAGE_SIZE_MIB in build.env."
fi

# ---- Allocate raw image -----------------------------------------------------
log "Allocating raw image: ${RAW_IMG} (${IMAGE_SIZE_MIB} MiB)"
rm -f "${RAW_IMG}"
truncate -s "${IMAGE_SIZE_MIB}M" "${RAW_IMG}"

# ---- Build ext4 in-place from rootfs directory ------------------------------
log "Building ext4 filesystem with rootfs contents (mke2fs -d)"
mke2fs \
    -t ext4 \
    -L "${DISTRO_LABEL}" \
    -d "${ROOTFS_DIR}" \
    -E lazy_itable_init=0,lazy_journal_init=0 \
    -O ^has_journal \
    "${RAW_IMG}" \
    "${IMAGE_SIZE_MIB}M"
# Note: ^has_journal disables journal for fastrootfs install perf.
# Hekate flashes this raw to ext4 partition; user can `tune2fs -O has_journal`
# post-install if desired. theofficialgman's images ship without journal too.

# Re-enable journal for the actual user-facing filesystem (best of both):
log "Re-enabling ext4 journal for runtime safety"
tune2fs -O has_journal "${RAW_IMG}"

log "Stage 04 done. Raw image: ${RAW_IMG} ($(du -m "${RAW_IMG}" | awk '{print $1}') MiB)"
