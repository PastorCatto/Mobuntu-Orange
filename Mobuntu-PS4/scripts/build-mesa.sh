#!/usr/bin/env bash
# scripts/build-mesa.sh
# Installs PS4-patched Mesa 25 into the rootfs.
#
# Priority order:
#   1. upstream/mesa-ps4-*.7z  — pre-built filesystem overlay (recommended)
#   2. upstream/mesa-debs/*.deb — pre-built Debian packages (fallback)
#   3. Docker build via FalsePhilosopher/mesa-docker-ps4 (last resort)
#
# Usage:
#   build-mesa.sh --rootfs <path> --suite <suite>

set -euo pipefail

ROOTFS=""
SUITE=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM_DIR="${SCRIPT_DIR}/../upstream"
MESA_DOCKER_REPO="https://github.com/FalsePhilosopher/mesa-docker-ps4"
MESA_DOCKER_IMAGE="mesa-docker-ps4"
MESA_BUILD_DIR="/tmp/mobuntu-mesa-build"

cyan()  { echo -e "\e[96m    $*\e[0m"; }
green() { echo -e "\e[92m    $*\e[0m"; }
error() { echo -e "\e[91mERROR: $*\e[0m" >&2; exit 1; }
warn()  { echo -e "\e[93m    WARNING: $*\e[0m"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rootfs) ROOTFS="$2"; shift 2 ;;
        --suite)  SUITE="$2";  shift 2 ;;
        *) error "Unknown arg: $1" ;;
    esac
done

[ -d "$ROOTFS" ] || error "rootfs not found: ${ROOTFS}"

# ── Method 1: 7z filesystem overlay ──────────────────────────────────────────
MESA_7Z="$(ls "${UPSTREAM_DIR}"/mesa-ps4-*.7z 2>/dev/null | head -1 || true)"
if [ -n "$MESA_7Z" ]; then
    cyan "Found Mesa 7z overlay: $(basename "$MESA_7Z")"

    # Ensure p7zip is available
    if ! command -v 7z &>/dev/null; then
        cyan "Installing p7zip-full..."
        apt-get install -y --no-install-recommends p7zip-full
    fi

    # Detect the inner directory name (e.g. mesa-ps4-25.3.0-devel)
    cyan "Detecting inner directory name..."
    MESA_INNER="$(7z l "$MESA_7Z" | awk '/^[0-9]{4}-/{print $NF}' | grep -v "^libdrm-git\|^mesa-git\|^Howto\|^folders\|\." | grep "/" | head -1 | cut -d'/' -f1 || true)"

    if [ -z "$MESA_INNER" ]; then
        # Fallback: just use the known name
        MESA_INNER="mesa-ps4-25.3.0-devel"
        warn "Could not auto-detect inner dir — using fallback: ${MESA_INNER}"
    fi
    cyan "Inner directory: ${MESA_INNER}"

    # Extract only usr/ and etc/ from the overlay — skip source trees
    cyan "Extracting ${MESA_INNER}/usr and ${MESA_INNER}/etc into rootfs..."
    EXTRACT_TMP="$(mktemp -d)"
    cyan "Temp dir: ${EXTRACT_TMP}"

    7z x "$MESA_7Z" \
        "${MESA_INNER}/usr" \
        "${MESA_INNER}/etc" \
        -o"${EXTRACT_TMP}" \
        -y || error "7z extraction failed — is the archive corrupt or incomplete?"

    # Verify extraction produced something
    [ -d "${EXTRACT_TMP}/${MESA_INNER}/usr" ] || error "Extraction succeeded but usr/ not found at ${EXTRACT_TMP}/${MESA_INNER}/usr"
    [ -d "${EXTRACT_TMP}/${MESA_INNER}/etc" ] || error "Extraction succeeded but etc/ not found at ${EXTRACT_TMP}/${MESA_INNER}/etc"

    # Overlay into rootfs
    cyan "Overlaying usr/ and etc/ into rootfs..."
    cp -a "${EXTRACT_TMP}/${MESA_INNER}/usr/." "${ROOTFS}/usr/"
    cp -a "${EXTRACT_TMP}/${MESA_INNER}/etc/." "${ROOTFS}/etc/"

    rm -rf "$EXTRACT_TMP"
    green "Mesa installed from 7z overlay. (libdrm 2.4.125, Mesa 25.3.0-devel)"
    exit 0
fi

# ── Method 2: Pre-built .deb files ───────────────────────────────────────────
MESA_DEBS_DIR="${UPSTREAM_DIR}/mesa-debs"
if [ -d "$MESA_DEBS_DIR" ] && ls "${MESA_DEBS_DIR}"/*.deb &>/dev/null 2>&1; then
    cyan "Pre-built Mesa debs found at upstream/mesa-debs/ — skipping Docker build"
    cp "${MESA_DEBS_DIR}"/*.deb "${ROOTFS}/tmp/"
    chroot "$ROOTFS" /bin/bash -c "
        export DEBIAN_FRONTEND=noninteractive
        dpkg -i /tmp/*.deb || apt-get install -f -y
        rm -f /tmp/*.deb
    "
    green "Mesa installed from pre-built debs."
    exit 0
fi

# ── No pre-built Mesa found — bail out with clear instructions ────────────────
error "No Mesa source found. Cannot continue.

Please provide one of the following before building:

  RECOMMENDED — Mesa 7z overlay (triki1, ps4linux.com forums):
    Place at: upstream/mesa-ps4-25.3.0-devel-trixie.7z

  ALTERNATIVE — Pre-built Debian .deb files:
    Place at: upstream/mesa-debs/*.deb

The Docker build method has been removed (mesa-docker-ps4 has no Dockerfile).
See upstream/UPSTREAM_SOURCES.md for details."
