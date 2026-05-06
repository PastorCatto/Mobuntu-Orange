#!/usr/bin/env bash
# scripts/build-mesa.sh
# Builds PS4-patched Mesa 25 via FalsePhilosopher/mesa-docker-ps4 Docker container.
# Installs resulting packages into the rootfs.
#
# Usage:
#   build-mesa.sh --rootfs <path> --suite <suite>

set -euo pipefail

ROOTFS=""
SUITE=""
MESA_DOCKER_REPO="https://github.com/FalsePhilosopher/mesa-docker-ps4"
MESA_DOCKER_IMAGE="mesa-docker-ps4"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MESA_BUILD_DIR="/tmp/mobuntu-mesa-build"

cyan()  { echo -e "\e[96m    $*\e[0m"; }
green() { echo -e "\e[92m    $*\e[0m"; }
error() { echo -e "\e[91mERROR: $*\e[0m" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rootfs) ROOTFS="$2"; shift 2 ;;
        --suite)  SUITE="$2";  shift 2 ;;
        *) error "Unknown arg: $1" ;;
    esac
done

[ -d "$ROOTFS" ] || error "rootfs not found: ${ROOTFS}"

# ── Check for pre-built Mesa debs ─────────────────────────────────────────────
MESA_DEBS_DIR="${SCRIPT_DIR}/../upstream/mesa-debs"
if [ -d "$MESA_DEBS_DIR" ] && ls "$MESA_DEBS_DIR"/*.deb &>/dev/null 2>&1; then
    cyan "Pre-built Mesa debs found at upstream/mesa-debs/ — skipping Docker build"
    cyan "Installing pre-built Mesa packages..."
    cp "$MESA_DEBS_DIR"/*.deb "${ROOTFS}/tmp/"
    chroot "$ROOTFS" /bin/bash -c "
        export DEBIAN_FRONTEND=noninteractive
        dpkg -i /tmp/*.deb || apt-get install -f -y
        rm -f /tmp/*.deb
    "
    green "Mesa installed from pre-built debs."
    exit 0
fi

# ── Build via Docker ──────────────────────────────────────────────────────────
cyan "No pre-built debs found — building Mesa 25 via Docker..."
cyan "Source: ${MESA_DOCKER_REPO}"

command -v docker &>/dev/null || error "Docker not installed. Install Docker or place pre-built Mesa debs at upstream/mesa-debs/"

# Clone mesa-docker-ps4 if not present
if [ ! -d "$MESA_BUILD_DIR" ]; then
    cyan "Cloning mesa-docker-ps4..."
    git clone --depth=1 "$MESA_DOCKER_REPO" "$MESA_BUILD_DIR"
else
    cyan "Updating mesa-docker-ps4..."
    git -C "$MESA_BUILD_DIR" pull --ff-only 2>/dev/null || true
fi

# Build Docker image
cyan "Building Docker image (this may take a while first run)..."
docker build -t "$MESA_DOCKER_IMAGE" "$MESA_BUILD_DIR"

# Run build — outputs .deb files
mkdir -p "${MESA_BUILD_DIR}/output"
docker run --rm \
    -v "${MESA_BUILD_DIR}/output:/output" \
    "$MESA_DOCKER_IMAGE"

# Check output
ls "${MESA_BUILD_DIR}/output"/*.deb &>/dev/null || \
    error "Mesa Docker build produced no .deb files"

# Copy debs into rootfs and install
cyan "Installing Mesa packages into rootfs..."
cp "${MESA_BUILD_DIR}/output"/*.deb "${ROOTFS}/tmp/"
chroot "$ROOTFS" /bin/bash -c "
    export DEBIAN_FRONTEND=noninteractive
    dpkg -i /tmp/*.deb || apt-get install -f -y
    rm -f /tmp/*.deb
"

# Cache debs for future builds
mkdir -p "$MESA_DEBS_DIR"
cp "${MESA_BUILD_DIR}/output"/*.deb "$MESA_DEBS_DIR/"
cyan "Mesa debs cached at upstream/mesa-debs/ for future builds"

green "Mesa 25 (PS4-patched) installed successfully."
