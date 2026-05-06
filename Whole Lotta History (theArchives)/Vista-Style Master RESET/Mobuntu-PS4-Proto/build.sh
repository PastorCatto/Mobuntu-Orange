#!/usr/bin/env bash
# =============================================================================
# Mobuntu-PS4 build orchestrator
# =============================================================================
# Mirrors the SDM845 / L4T pipeline pattern.
# Run as root (debootstrap + losetup + mkfs need it).
#
# STAGES env var lets you re-run subsets:
#   STAGES="01 02" ./build.sh          bootstrap + kernel only
#   STAGES="04 05" ./build.sh          repackage from existing rootfs
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source "${SCRIPT_DIR}/build.env"

ALL_STAGES="01 02 03 04 05"
STAGES="${STAGES:-$ALL_STAGES}"

LOG_DIR="${BUILD_DIR}/logs"
mkdir -p "$LOG_DIR"
BUILD_LOG="${LOG_DIR}/build-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$BUILD_LOG") 2>&1

log()   { printf '[BUILD %s] %s\n' "$(date +%H:%M:%S)" "$*"; }
fatal() { printf '[BUILD ERROR] %s\n' "$*" >&2; exit 1; }
warn()  { printf '[BUILD WARN] %s\n' "$*" >&2; }

[[ $EUID -eq 0 ]] || fatal "Must run as root."

HOST_ARCH="$(uname -m)"
[[ "$HOST_ARCH" == "x86_64" ]] || fatal "Mobuntu-PS4 targets x86-64. Build host must be x86-64 (got: ${HOST_ARCH})."

log "Mobuntu-PS4 build starting"
log "Suite=${UBUNTU_SUITE} Arch=${ARCH} Kernel=${KERNEL_MODE}/${KERNEL_TAG}"
log "Output: ${OUTPUT_DIR}/${OUTPUT_IMG}"

mkdir -p "$BUILD_DIR" "$ROOTFS_DIR" "$KERNEL_DIR" "$IMAGE_DIR" "$OUTPUT_DIR"

run_stage() {
    local num="$1" script
    script=$(find "${SCRIPT_DIR}/scripts" -maxdepth 1 -name "${num}-*.sh" | head -n1)
    [[ -n "$script" ]] || { warn "No stage script for ${num}, skipping"; return 0; }
    log "=== Stage ${num}: $(basename "$script") ==="
    bash "$script" || fatal "Stage ${num} failed. Log: $BUILD_LOG"
    log "=== Stage ${num} complete ==="
}

for stage in $STAGES; do
    run_stage "$stage"
done

log "Build complete."
log "Artifact: ${OUTPUT_DIR}/${OUTPUT_IMG}"
log "Log:      ${BUILD_LOG}"
log ""
log "To write to USB (replace /dev/sdX with your drive — DOUBLE CHECK THIS):"
log "  sudo dd if=${OUTPUT_DIR}/${OUTPUT_IMG} of=/dev/sdX bs=4M status=progress conv=fsync"
