#!/usr/bin/env bash
# =============================================================================
# 01-bootstrap-rootfs.sh
# Bootstraps a minimal Ubuntu arm64 rootfs via debootstrap + qemu-user-static.
#
# Notes:
#   - For GNOME flavor, switchroot upstream uses Ubuntu's official RPi arm64
#     image. We don't do that here — we debootstrap from scratch so we have
#     full control over base packages. Switch to RPi image fetch later if a
#     truly minimal GNOME path is needed.
#   - Mirrors switchroot/theofficialgman's nv_build_samplefs.sh approach for
#     kubuntu/ubuntu-unity flavors.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../build.env
source "${SCRIPT_DIR}/../build.env"

log()  { printf '[01 %s] %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '[01 WARN] %s\n' "$*" >&2; }
fail() { printf '[01 FAIL] %s\n' "$*" >&2; exit 1; }

# ---- Host Ubuntu version detection (mirrors SDM845 pipeline RC13.4 fix) -----
HOST_VER="$(lsb_release -rs 2>/dev/null || echo unknown)"
case "$HOST_VER" in
    24.04) QEMU_PKG="qemu-user-static" ;;
    26.04) QEMU_PKG="qemu-user-binfmt-hwe" ;;
    *)     QEMU_PKG="qemu-user-static" ;;  # best effort
esac

# ---- Tooling check ----------------------------------------------------------
need_pkgs=()
command -v debootstrap >/dev/null 2>&1 || need_pkgs+=("debootstrap")
command -v qemu-aarch64-static >/dev/null 2>&1 || need_pkgs+=("$QEMU_PKG")
dpkg-query -W ubuntu-keyring >/dev/null 2>&1 || need_pkgs+=("ubuntu-keyring")

if (( ${#need_pkgs[@]} > 0 )); then
    log "Installing missing host packages: ${need_pkgs[*]}"
    apt-get update -qq
    apt-get install -y --no-install-recommends "${need_pkgs[@]}"
fi

# ---- Idempotency: skip if rootfs looks already-bootstrapped -----------------
if [[ -e "${ROOTFS_DIR}/etc/os-release" ]]; then
    if grep -q "VERSION_CODENAME=${UBUNTU_SUITE}" "${ROOTFS_DIR}/etc/os-release" 2>/dev/null; then
        log "Rootfs already bootstrapped at ${ROOTFS_DIR} (suite=${UBUNTU_SUITE}). Skipping."
        log "To force re-bootstrap: rm -rf ${ROOTFS_DIR}"
        exit 0
    else
        warn "Existing rootfs at ${ROOTFS_DIR} is a different suite. Wiping."
        rm -rf "${ROOTFS_DIR}"
    fi
fi

mkdir -p "${ROOTFS_DIR}"

# ---- Debootstrap ------------------------------------------------------------
MIRROR="http://ports.ubuntu.com/ubuntu-ports"
if [[ -n "${UBUNTU_SNAPSHOT}" ]]; then
    MIRROR="https://snapshot.ubuntu.com/ubuntu/${UBUNTU_SNAPSHOT}"
    log "Using Ubuntu snapshot mirror: ${MIRROR}"
fi

log "Running debootstrap (suite=${UBUNTU_SUITE}, arch=${ARCH})..."
debootstrap \
    --arch="${ARCH}" \
    --foreign \
    --variant=minbase \
    --components=main,universe,multiverse \
    --include=ca-certificates,gnupg,locales,sudo \
    "${UBUNTU_SUITE}" \
    "${ROOTFS_DIR}" \
    "${MIRROR}"

log "Copying qemu-aarch64-static into rootfs"
cp -v "${QEMU_BIN}" "${ROOTFS_DIR}${QEMU_BIN}"

log "Running second-stage debootstrap inside chroot"
chroot "${ROOTFS_DIR}" /debootstrap/debootstrap --second-stage

# ---- APT sources ------------------------------------------------------------
log "Writing APT sources for ${UBUNTU_SUITE}"
cat > "${ROOTFS_DIR}/etc/apt/sources.list" <<EOF
deb ${MIRROR} ${UBUNTU_SUITE} main universe multiverse restricted
deb ${MIRROR} ${UBUNTU_SUITE}-updates main universe multiverse restricted
deb ${MIRROR} ${UBUNTU_SUITE}-security main universe multiverse restricted
EOF

log "Stage 01 done. Rootfs at: ${ROOTFS_DIR}"
