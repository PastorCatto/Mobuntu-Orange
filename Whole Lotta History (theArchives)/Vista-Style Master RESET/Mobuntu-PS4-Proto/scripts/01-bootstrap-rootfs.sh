#!/usr/bin/env bash
# =============================================================================
# 01-bootstrap-rootfs.sh  (PS4 variant)
# Native x86-64 debootstrap — no QEMU, no foreign-mode second stage.
# Much simpler than the arm64 path.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../build.env"

log()  { printf '[01 %s] %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '[01 WARN] %s\n' "$*" >&2; }
fail() { printf '[01 FAIL] %s\n' "$*" >&2; exit 1; }

# ---- Tooling ----------------------------------------------------------------
need_pkgs=()
command -v debootstrap >/dev/null 2>&1 || need_pkgs+=("debootstrap")
dpkg-query -W ubuntu-keyring >/dev/null 2>&1 || need_pkgs+=("ubuntu-keyring")
if (( ${#need_pkgs[@]} > 0 )); then
    apt-get update -qq
    apt-get install -y --no-install-recommends "${need_pkgs[@]}"
fi

# ---- Idempotency ------------------------------------------------------------
if [[ -e "${ROOTFS_DIR}/etc/os-release" ]]; then
    if grep -q "VERSION_CODENAME=${UBUNTU_SUITE}" "${ROOTFS_DIR}/etc/os-release" 2>/dev/null; then
        log "Rootfs already present (suite=${UBUNTU_SUITE}). Skipping."
        log "To re-bootstrap: rm -rf ${ROOTFS_DIR}"
        exit 0
    else
        warn "Existing rootfs has a different suite. Wiping."
        rm -rf "${ROOTFS_DIR}"
    fi
fi

mkdir -p "${ROOTFS_DIR}"

MIRROR="http://archive.ubuntu.com/ubuntu"
if [[ -n "${UBUNTU_SNAPSHOT}" ]]; then
    MIRROR="https://snapshot.ubuntu.com/ubuntu/${UBUNTU_SNAPSHOT}"
    log "Using snapshot mirror: ${MIRROR}"
fi

log "debootstrap amd64 ${UBUNTU_SUITE} (native, no QEMU)"
debootstrap \
    --arch="${ARCH}" \
    --variant=minbase \
    --components=main,universe,multiverse \
    --include=ca-certificates,gnupg,locales,sudo \
    "${UBUNTU_SUITE}" \
    "${ROOTFS_DIR}" \
    "${MIRROR}"

log "Writing APT sources"
cat > "${ROOTFS_DIR}/etc/apt/sources.list" <<EOF
deb ${MIRROR} ${UBUNTU_SUITE} main universe multiverse restricted
deb ${MIRROR} ${UBUNTU_SUITE}-updates main universe multiverse restricted
deb ${MIRROR} ${UBUNTU_SUITE}-security main universe multiverse restricted
EOF

log "Stage 01 done. Rootfs: ${ROOTFS_DIR}"
