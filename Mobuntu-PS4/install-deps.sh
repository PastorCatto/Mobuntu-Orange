#!/usr/bin/env bash
# Mobuntu-PS4 — Build Host Dependency Installer
# Codename: Spider-Man / Spider-Man: Doctor Octavius
# Version: 0.2.1
# Target host: Ubuntu 26.04 (resolute) x86-64
#
# Usage:
#   sudo ./install-deps.sh
#   sudo ./install-deps.sh --no-docker    # skip Docker install
#   sudo ./install-deps.sh --check        # check only, don't install

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
red()    { echo -e "\e[91m$*\e[0m"; }
cyan()   { echo -e "\e[96m  $*\e[0m"; }
green()  { echo -e "\e[92m$*\e[0m"; }
yellow() { echo -e "\e[93m  $*\e[0m"; }

error()  { red    "ERROR: $*"; exit 1; }
status() { cyan   "$*"; }
warn()   { yellow "WARNING: $*"; }
ok()     { green  "  [OK]  $*"; }
miss()   { red    "  [!!]  $*"; }
skip()   { echo   "  [--]  $*"; }

# ── Args ──────────────────────────────────────────────────────────────────────
INSTALL_DOCKER=true
CHECK_ONLY=false

for arg in "$@"; do
    case "$arg" in
        --no-docker) INSTALL_DOCKER=false ;;
        --check)     CHECK_ONLY=true ;;
        --help|-h)
            grep '^#' "$0" | grep -v '#!/' | sed 's/^# \?//'
            exit 0
            ;;
        *) error "Unknown argument: $arg" ;;
    esac
done

# ── Root check ────────────────────────────────────────────────────────────────
if [ "$CHECK_ONLY" = false ] && [ "$(id -u)" -ne 0 ]; then
    echo "Re-running as root..."
    exec sudo -E bash "$0" "$@"
fi

# ── Host check ────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║     Mobuntu-PS4 Dependency Installer v0.2.1          ║"
echo "║     Target host: Ubuntu 26.04 (resolute)             ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Verify we're on Ubuntu 26.04
if [ -f /etc/os-release ]; then
    . /etc/os-release
    HOST_ID="${ID:-unknown}"
    HOST_VERSION="${VERSION_ID:-unknown}"
else
    HOST_ID="unknown"
    HOST_VERSION="unknown"
fi

status "Detected host: ${HOST_ID} ${HOST_VERSION}"

if [ "$HOST_ID" != "ubuntu" ] || [ "$HOST_VERSION" != "26.04" ]; then
    warn "This script targets Ubuntu 26.04. Detected: ${HOST_ID} ${HOST_VERSION}"
    warn "Proceeding anyway — some package names may differ."
fi
echo ""

# ── Dependency definitions ────────────────────────────────────────────────────
#
# PS4 is x86-64 — no QEMU needed (unlike SDM845/beryllium builds).
# Ubuntu 26.04 uses qemu-user-binfmt-hwe for arm64 chroots, but that's
# irrelevant here. No QEMU packages required for Spider-Man/Doctor Octavius.

APT_DEPS=(
    # Debootstrap
    debootstrap

    # Chroot utilities
    arch-test
    systemd-container         # for systemd-nspawn if needed

    # Archive / compression
    tar
    xz-utils
    zip
    unzip

    # Build tools (for session switcher C compilation in chroot)
    # Note: these are host-side only for verification; actual build happens in rootfs chroot
    gcc
    make
    pkg-config

    # Networking / download
    curl
    wget
    ca-certificates
    git

    # Disk utilities
    parted
    dosfstools               # mkfs.fat for FAT32 USB partition
    e2fsprogs                # mkfs.ext4 for rootfs partition

    # Misc
    gnupg
    lsb-release
    sudo
)

DOCKER_DEPS=(
    # Docker — required for Mesa 25 build via FalsePhilosopher/mesa-docker-ps4
    # Skip with --no-docker if you have pre-built Mesa debs in upstream/mesa-debs/
    docker.io
    docker-compose-v2
)

# ── Check function ────────────────────────────────────────────────────────────
MISSING=()

check_apt_pkg() {
    local pkg="$1"
    if dpkg -s "$pkg" &>/dev/null; then
        ok "$pkg"
    else
        miss "$pkg"
        MISSING+=("$pkg")
    fi
}

check_cmd() {
    local cmd="$1"
    local label="${2:-$1}"
    if command -v "$cmd" &>/dev/null; then
        ok "$label ($(command -v "$cmd"))"
    else
        miss "$label — not found in PATH"
    fi
}

# ── Run checks ────────────────────────────────────────────────────────────────
echo "── Checking apt packages ─────────────────────────────────────────────"
for pkg in "${APT_DEPS[@]}"; do
    check_apt_pkg "$pkg"
done

if [ "$INSTALL_DOCKER" = true ]; then
    echo ""
    echo "── Checking Docker ───────────────────────────────────────────────────"
    for pkg in "${DOCKER_DEPS[@]}"; do
        check_apt_pkg "$pkg"
    done
else
    skip "Docker check skipped (--no-docker)"
fi

echo ""
echo "── Checking key commands ─────────────────────────────────────────────"
check_cmd debootstrap
check_cmd git
check_cmd curl
check_cmd unzip
check_cmd mkfs.fat  "mkfs.fat (dosfstools)"
check_cmd mkfs.ext4 "mkfs.ext4 (e2fsprogs)"
if [ "$INSTALL_DOCKER" = true ]; then
    check_cmd docker
fi
echo ""

# ── Install if not check-only ─────────────────────────────────────────────────
if [ "$CHECK_ONLY" = true ]; then
    if [ ${#MISSING[@]} -eq 0 ]; then
        green "All dependencies satisfied."
    else
        warn "${#MISSING[@]} package(s) missing. Run without --check to install."
    fi

    echo ""
    echo "── Checking script permissions and line endings ──────────────────────"
    SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    while IFS= read -r -d '' script; do
        ISSUES=""
        file "$script" | grep -q CRLF && ISSUES="${ISSUES} CRLF"
        [ ! -x "$script" ]            && ISSUES="${ISSUES} not-executable"
        if [ -n "$ISSUES" ]; then
            miss "$script (issues:${ISSUES})"
        else
            ok "$script"
        fi
    done < <(find "$SCRIPT_ROOT" -name "*.sh" -print0)

    echo ""
    exit 0
fi

# ── Install apt deps ──────────────────────────────────────────────────────────
status "Updating apt..."
apt-get update -qq

status "Installing core dependencies..."
apt-get install -y --no-install-recommends "${APT_DEPS[@]}"

# ── Install Docker ────────────────────────────────────────────────────────────
if [ "$INSTALL_DOCKER" = true ]; then
    status "Installing Docker..."

    # Check if Docker is already installed via the official repo
    if command -v docker &>/dev/null; then
        skip "Docker already installed: $(docker --version)"
    else
        # Try docker.io from Ubuntu repos first (simplest for WSL2)
        if apt-get install -y --no-install-recommends "${DOCKER_DEPS[@]}" 2>/dev/null; then
            ok "Docker installed via apt"
        else
            # Fall back to official Docker repo
            warn "docker.io not available — trying official Docker repo..."
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
                -o /etc/apt/keyrings/docker.asc
            chmod a+r /etc/apt/keyrings/docker.asc
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
                https://download.docker.com/linux/ubuntu \
                $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
                > /etc/apt/sources.list.d/docker.list
            apt-get update -qq
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ok "Docker installed via official repo"
        fi
    fi

    # Add current user to docker group if running under sudo
    REAL_USER="${SUDO_USER:-}"
    if [ -n "$REAL_USER" ] && ! groups "$REAL_USER" | grep -q docker; then
        status "Adding ${REAL_USER} to docker group..."
        usermod -aG docker "$REAL_USER"
        warn "Log out and back in (or run 'newgrp docker') for Docker group to take effect"
    fi
fi

# ── WSL2 notes ────────────────────────────────────────────────────────────────
if grep -qi microsoft /proc/version 2>/dev/null; then
    echo ""
    echo "── WSL2 notes ────────────────────────────────────────────────────────"
    warn "Running inside WSL2. A few things to be aware of:"
    warn "  - Docker Desktop for Windows is recommended over docker.io in WSL2"
    warn "  - If Docker daemon won't start: sudo service docker start"
    warn "  - debootstrap chroots work fine (PS4 is x86-64, no QEMU needed)"
    warn "  - Run builds from a Linux filesystem path (not /mnt/c/) for performance"
fi

# ── Cleanup ───────────────────────────────────────────────────────────────────
apt-get autoremove -y
apt-get clean

# ── Make scripts executable + dos2unix ───────────────────────────────────────
echo ""
echo "── Checking script permissions and line endings ──────────────────────"
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure dos2unix is available
if ! command -v dos2unix &>/dev/null; then
    status "Installing dos2unix..."
    apt-get install -y --no-install-recommends dos2unix
fi

while IFS= read -r -d '' script; do
    FIXED=""
    # Fix CRLF
    if file "$script" | grep -q CRLF; then
        dos2unix "$script" 2>/dev/null
        FIXED="${FIXED} dos2unix"
    fi
    # Fix permissions
    if [ ! -x "$script" ]; then
        chmod +x "$script"
        FIXED="${FIXED} chmod+x"
    fi
    if [ -n "$FIXED" ]; then
        ok "$script (fixed:${FIXED})"
    else
        ok "$script"
    fi
done < <(find "$SCRIPT_ROOT" -name "*.sh" -print0)

# ── Final check ───────────────────────────────────────────────────────────────
echo ""
echo "── Final verification ────────────────────────────────────────────────"
MISSING=()
for pkg in "${APT_DEPS[@]}"; do
    check_apt_pkg "$pkg"
done
if [ "$INSTALL_DOCKER" = true ]; then
    check_cmd docker
fi

echo ""
if [ ${#MISSING[@]} -eq 0 ]; then
    green "╔══════════════════════════════════════════════════════╗"
    green "║     All dependencies installed successfully!          ║"
    green "╚══════════════════════════════════════════════════════╝"
    echo ""
    status "You're ready to build. Next steps:"
    echo ""
    echo "    1. Place bzImage at:          upstream/bzImage"
    echo "       https://github.com/rmuxnet/ps4-linux-12xx/releases"
    echo ""
    echo "    2. Spider-Man (baseline):"
    echo "       sudo ./build.sh -d ps4 -p external"
    echo ""
    echo "    3. Spider-Man: Doctor Octavius (Theseus):"
    echo "       Place theseus binary at:   upstream/theseus/theseus"
    echo "       sudo ./build.sh -d ps4 -p external -m theseus,desktop"
    echo ""
    echo "    Optional — skip Mesa Docker build:"
    echo "       Place pre-built Mesa debs at: upstream/mesa-debs/*.deb"
    echo ""
else
    red "╔══════════════════════════════════════════════════════╗"
    red "║     ${#MISSING[@]} package(s) failed to install.                  ║"
    red "╚══════════════════════════════════════════════════════╝"
    red "Missing: ${MISSING[*]}"
    exit 1
fi
