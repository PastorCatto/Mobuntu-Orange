#!/usr/bin/env bash
# =============================================================================
# Mobuntu-L4T build orchestrator
# =============================================================================
# Runs the 5-script pipeline. Stages can be skipped via STAGES env var:
#   STAGES="01 02 03" ./build.sh    # only run bootstrap, fetch, customize
#   STAGES="04 05" ./build.sh       # only repackage from existing rootfs
#
# Pattern mirrors the SDM845 pipeline so the devkit can drive both.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# shellcheck source=build.env
source "${SCRIPT_DIR}/build.env"

# ---- Stage selection --------------------------------------------------------
ALL_STAGES="01 02 03 04 05"
STAGES="${STAGES:-$ALL_STAGES}"

# ---- Logging ----------------------------------------------------------------
LOG_DIR="${BUILD_DIR}/logs"
mkdir -p "$LOG_DIR"
BUILD_LOG="${LOG_DIR}/build-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$BUILD_LOG") 2>&1

log()   { printf '[BUILD %s] %s\n' "$(date +%H:%M:%S)" "$*"; }
fatal() { printf '[BUILD ERROR] %s\n' "$*" >&2; exit 1; }
warn()  { printf '[BUILD WARN] %s\n' "$*" >&2; }

# ---- Preflight --------------------------------------------------------------
[[ $EUID -eq 0 ]] || fatal "This script must run as root (debootstrap + chroot needed). Try: sudo ./build.sh"

# Detect host Ubuntu version for QEMU package selection.
HOST_UBUNTU_VERSION="$(lsb_release -rs 2>/dev/null || echo unknown)"
case "$HOST_UBUNTU_VERSION" in
    24.04) log "Host: Ubuntu 24.04 (supported)";;
    26.04) warn "Host: Ubuntu 26.04 — known QEMU segfault regression with arm64 chroots. Proceed at your own risk.";;
    *)     warn "Host: Ubuntu ${HOST_UBUNTU_VERSION} (untested for L4T builds — recommended: 24.04)";;
esac

# ---- Stage runner -----------------------------------------------------------
run_stage() {
    local num="$1" script
    script=$(find "${SCRIPT_DIR}/scripts" -maxdepth 1 -name "${num}-*.sh" | head -n1)
    [[ -n "$script" ]] || { warn "No stage script found for ${num}, skipping"; return 0; }
    log "=== Stage ${num}: $(basename "$script") ==="
    if ! bash "$script"; then
        fatal "Stage ${num} failed. Log: $BUILD_LOG"
    fi
    log "=== Stage ${num} complete ==="
}

log "Mobuntu-L4T build starting"
log "Suite=${UBUNTU_SUITE} Flavor=${FLAVOR} Arch=${ARCH} L4T=${L4T_RELEASE}"
log "Stages: ${STAGES}"
log "Output: ${OUTPUT_DIR}/${OUTPUT_7Z}"

mkdir -p "$BUILD_DIR" "$ROOTFS_DIR" "$DEBS_DIR" "$IMAGE_DIR" "$OUTPUT_DIR"

for stage in $STAGES; do
    run_stage "$stage"
done

log "Build complete. Artifact: ${OUTPUT_DIR}/${OUTPUT_7Z}"
log "Log saved: ${BUILD_LOG}"
