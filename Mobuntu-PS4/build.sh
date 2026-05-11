#!/usr/bin/env bash
# Mobuntu-PS4 build.sh
# Codename: Spider-Man / Spider-Man: Doctor Octavius (Theseus build)
# Version: 0.2.0
#
# Builds a minimal Debian rootfs for jailbroken PS4 consoles.
# Bundles the correct initramfs and drops bootloader files based on boot mode.
# Mesa 25 is built via FalsePhilosopher/mesa-docker-ps4 Docker container.
# Kernel (strawberry 6.18.21) is NOT built here — sourced from upstream.
#
# Codenames:
#   Spider-Man            — baseline build (no Theseus)
#   Spider-Man: Doctor Octavius — Theseus Xbox dashboard build (-m theseus)
#
# Usage:
#   sudo ./build.sh -d ps4 -p <variant> [-u <ui>] [-b <suite>] [-m <modes>] [-h]
#
#   -d  Device codename (ps4)                          [required]
#   -p  Boot/platform variant:
#         external        — USB/external storage, works on any board
#         aeolia          — Internal HDD, older fat PS4 (Aeolia board)
#         belize          — Internal HDD, PS4 Slim/newer (Belize board)
#   -u  UI selection: gnustep|lxde|lxqt               [default: from device.conf]
#   -b  Debian suite: bookworm|trixie                  [default: from device.conf]
#   -m  Mode overlays (comma-separated):
#         theseus         — Theseus Xbox dashboard (Doctor Octavius build)
#         desktop         — LXDE fallback desktop (requires theseus)
#   -h  Help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INITRAMFS_DIR="${SCRIPT_DIR}/initramfs"
OVERLAYS_DIR="${SCRIPT_DIR}/overlays"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
OUTPUT_DIR="${SCRIPT_DIR}/output"
VERSION="0.2.0"
CODENAME="Spider-Man"

# ── Colours ──────────────────────────────────────────────────────────────────
red()   { echo -e "\e[91m$*\e[0m" >&2; }
cyan()  { echo -e "\e[96m$*\e[0m" >&2; }
green() { echo -e "\e[92m$*\e[0m" >&2; }
yellow(){ echo -e "\e[93m$*\e[0m" >&2; }

error()   { red   "ERROR: $*";   exit 1; }
status()  { cyan  "  $*"; }
success() { green "$*"; }
warn()    { yellow "  WARNING: $*"; }

# ── Root check ────────────────────────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    echo "Re-running as root..."
    exec sudo -E bash "$0" "$@"
fi

# ── Argument parsing ──────────────────────────────────────────────────────────
DEVICE=""
PLATFORM=""
UI_OVERRIDE=""
SUITE_OVERRIDE=""
MODE_OVERLAYS=""

while getopts "d:p:u:b:m:h" opt; do
    case $opt in
        d) DEVICE="$OPTARG" ;;
        p) PLATFORM="$OPTARG" ;;
        u) UI_OVERRIDE="$OPTARG" ;;
        b) SUITE_OVERRIDE="$OPTARG" ;;
        m) MODE_OVERLAYS="$OPTARG" ;;
        h)
            grep '^#' "$0" | grep -v '#!/' | sed 's/^# \?//'
            exit 0
            ;;
        *) error "Unknown option. Use -h for help." ;;
    esac
done

# ── Resolve mode flags ────────────────────────────────────────────────────────
ENABLE_THESEUS=false
ENABLE_DESKTOP=false
if [ -n "$MODE_OVERLAYS" ]; then
    IFS=',' read -ra MODES <<< "$MODE_OVERLAYS"
    for mode in "${MODES[@]}"; do
        case "$mode" in
            theseus) ENABLE_THESEUS=true ;;
            desktop) ENABLE_DESKTOP=true ;;
            *) error "Unknown mode overlay '${mode}'. Valid: theseus, desktop" ;;
        esac
    done
fi

# desktop requires theseus
if [ "$ENABLE_DESKTOP" = true ] && [ "$ENABLE_THESEUS" = false ]; then
    error "'-m desktop' requires '-m theseus' — use '-m theseus,desktop'"
fi

# Set codename based on mode
if [ "$ENABLE_THESEUS" = true ]; then
    CODENAME="Spider-Man: Doctor Octavius"
fi

[ -z "$DEVICE" ]   && error "Device required. Use -d ps4"
[ -z "$PLATFORM" ] && error "Platform variant required. Use -p external|aeolia|belize"

# ── Load device config ────────────────────────────────────────────────────────
DEVICE_CONF="${SCRIPT_DIR}/devices/${DEVICE}/device.conf"
[ -f "$DEVICE_CONF" ] || error "No device.conf at ${DEVICE_CONF}"
# shellcheck source=/dev/null
source "$DEVICE_CONF"

DEVICE_UI="${UI_OVERRIDE:-${DEVICE_UI:-gnustep}}"
DEBIAN_SUITE="${SUITE_OVERRIDE:-${DEBIAN_SUITE:-bookworm}}"

# ── Validate platform variant ─────────────────────────────────────────────────
case "$PLATFORM" in
    external)
        INITRAMFS_SRC="${INITRAMFS_DIR}/external/initramfs.cpio.gz"
        BOOT_MODE="external"
        BOOT_DESC="USB/External storage (any board)"
        ;;
    aeolia)
        INITRAMFS_SRC="${INITRAMFS_DIR}/internal-aeolia/initramfs.cpio.gz"
        BOOT_MODE="internal"
        BOOT_DEST="/data/linux/boot"
        BOOT_DESC="Internal HDD — Aeolia board (fat PS4)"
        ;;
    belize)
        INITRAMFS_SRC="${INITRAMFS_DIR}/internal-belize/initramfs.cpio.gz"
        BOOT_MODE="internal"
        BOOT_DEST="/data/linux/boot"
        BOOT_DESC="Internal HDD — Belize board (PS4 Slim/newer)"
        ;;
    *)
        error "Invalid platform '${PLATFORM}'. Valid: external, aeolia, belize"
        ;;
esac

[ -f "$INITRAMFS_SRC" ] || error "Initramfs not found at ${INITRAMFS_SRC}"

# ── Validate UI ───────────────────────────────────────────────────────────────
case "$DEVICE_UI" in
    gnustep|lxde|lxqt) ;;
    *) error "Invalid UI '${DEVICE_UI}'. Valid: gnustep, lxde, lxqt" ;;
esac

# ── Validate suite ────────────────────────────────────────────────────────────
case "$DEBIAN_SUITE" in
    bookworm|trixie) ;;
    *) error "Invalid suite '${DEBIAN_SUITE}'. Valid: bookworm, trixie" ;;
esac

# ── Validate kernel ───────────────────────────────────────────────────────────
KERNEL_PATH="${SCRIPT_DIR}/upstream/bzImage"
if [ ! -f "$KERNEL_PATH" ]; then
    warn "bzImage not found at upstream/bzImage"
    warn "Download strawberry kernel (6.18.21) from:"
    warn "  https://github.com/rmuxnet/ps4-linux-12xx/releases"
    warn "Place bzImage at: upstream/bzImage"
    error "Kernel missing — cannot continue. See upstream/UPSTREAM_SOURCES.md"
fi

# ── Validate Theseus binary (Doctor Octavius builds only) ─────────────────────
if [ "$ENABLE_THESEUS" = true ]; then
    THESEUS_BIN="${SCRIPT_DIR}/upstream/theseus/theseus"
    if [ ! -f "$THESEUS_BIN" ]; then
        warn "Theseus binary not found at upstream/theseus/theseus"
        warn "Download the pre-built Linux binary from TeamUIX:"
        warn "  https://github.com/MrMilenko/Theseus/releases"
        warn "Extract and place the 'theseus' binary at: upstream/theseus/theseus"
        error "Theseus binary missing — cannot build Doctor Octavius variant."
    fi
fi

# ── Dependency checks ─────────────────────────────────────────────────────────
for dep in debootstrap docker; do
    command -v "$dep" &>/dev/null || error "Missing dependency: ${dep}"
done

mkdir -p "$OUTPUT_DIR"

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║       Mobuntu-PS4 Build System v${VERSION}               ║"
echo "║       Codename: ${CODENAME}        ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
status "Device    : ${DEVICE_MODEL:-PS4} (${DEVICE})"
status "Platform  : ${PLATFORM} — ${BOOT_DESC}"
status "UI        : ${DEVICE_UI}"
status "Suite     : Debian ${DEBIAN_SUITE}"
status "Boot mode : ${BOOT_MODE}"
status "Theseus   : ${ENABLE_THESEUS}"
status "Desktop   : ${ENABLE_DESKTOP}"
echo ""

# ── Stage 1: Debootstrap rootfs ───────────────────────────────────────────────
ROOTFS_DIR="${OUTPUT_DIR}/rootfs"
status "[ 1/5 ] Bootstrapping Debian ${DEBIAN_SUITE} rootfs..."
rm -rf "$ROOTFS_DIR"
debootstrap \
    --arch=amd64 \
    --variant=minbase \
    --include=systemd,systemd-sysv,dbus,apt,sudo,locales,ca-certificates,\
network-manager,openssh-server,alsa-utils,pulseaudio,xserver-xorg-core,\
xserver-xorg-input-libinput,xinit,lightdm \
    "$DEBIAN_SUITE" \
    "$ROOTFS_DIR" \
    "http://deb.debian.org/debian" || error "debootstrap failed"

# ── Stage 2: Build Mesa 25 via Docker ────────────────────────────────────────
status "[ 2/5 ] Building Mesa 25 (PS4-patched) via Docker..."
bash "${SCRIPTS_DIR}/build-mesa.sh" \
    --rootfs "$ROOTFS_DIR" \
    --suite  "$DEBIAN_SUITE" || error "Mesa build failed"

# ── Stage 3: Customize rootfs ─────────────────────────────────────────────────
status "[ 3/5 ] Customizing rootfs (UI: ${DEVICE_UI})..."
bash "${SCRIPTS_DIR}/customize-rootfs.sh" \
    --rootfs   "$ROOTFS_DIR" \
    --overlays "$OVERLAYS_DIR" \
    --ui       "$DEVICE_UI" \
    --suite    "$DEBIAN_SUITE" \
    --hostname "${PRESEED_HOSTNAME:-mobuntu-ps4}" \
    --username "${PRESEED_USERNAME:-}" \
    --password "${PRESEED_PASSWORD:-}" \
    --theseus  "$ENABLE_THESEUS" \
    --desktop  "$ENABLE_DESKTOP" || error "Rootfs customization failed"

# ── Stage 4: Package rootfs tarball ──────────────────────────────────────────
TIMESTAMP="$(date +%Y%m%d)"
TARBALL="${OUTPUT_DIR}/mobuntu-ps4-${PLATFORM}-${DEBIAN_SUITE}-${TIMESTAMP}.tar.xz"
status "[ 4/5 ] Packaging rootfs tarball..."
tar -cJf "$TARBALL" \
    --exclude="${ROOTFS_DIR}/var/cache/apt/archives/*.deb" \
    --exclude="${ROOTFS_DIR}/var/cache/apt/pkgcache.bin" \
    --exclude="${ROOTFS_DIR}/var/cache/apt/srcpkgcache.bin" \
    --one-file-system \
    -C "$ROOTFS_DIR" . || error "Tarball creation failed"

# ── Stage 5: Stage boot files ─────────────────────────────────────────────────
status "[ 5/5 ] Staging boot files for ${PLATFORM}..."
bash "${SCRIPTS_DIR}/stage-boot.sh" \
    --platform      "$PLATFORM" \
    --boot-mode     "$BOOT_MODE" \
    --initramfs-src "$INITRAMFS_SRC" \
    --kernel-src    "$KERNEL_PATH" \
    --output-dir    "$OUTPUT_DIR" \
    --tarball       "$TARBALL" || error "Boot staging failed"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
success "╔══════════════════════════════════════════════════════╗"
success "║         Mobuntu-PS4 build complete!                  ║"
success "╚══════════════════════════════════════════════════════╝"
echo ""
status "Output: ${OUTPUT_DIR}/"
echo ""
bash "${SCRIPTS_DIR}/stage-boot.sh" --summary \
    --platform "$PLATFORM" --boot-mode "$BOOT_MODE" \
    --output-dir "$OUTPUT_DIR" 2>/dev/null || true
echo ""
status "See docs/INSTALL.md for flashing instructions."
echo ""
