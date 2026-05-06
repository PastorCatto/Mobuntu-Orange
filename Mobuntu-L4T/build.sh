#!/usr/bin/env bash
# Mobuntu-L4T build.sh
# Codename: Happy Mask Salesman
# Version: 0.1.0
#
# Thin wrapper around upstream Switchroot L4T build scripts.
# Mobuntu-L4T does NOT fork upstream — it layers overlays on top.
#
# Usage:
#   sudo ./build.sh -d switch [-u <ui>] [-f <flavor>] [-h]
#
#   -d  Device codename (currently: switch)
#   -u  UI selection (phosh|plasma-mobile|kde|lxde|mate) — default: from device.conf
#   -f  L4T flavor (kde-noble|gnome-noble|unity-noble) — default: from device.conf
#   -h  Help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM_DIR="${SCRIPT_DIR}/upstream/l4t-image-buildscripts"
OVERLAYS_DIR="${SCRIPT_DIR}/overlays"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
VERSION="0.1.0"
CODENAME="Happy Mask Salesman"

# ── Colours ──────────────────────────────────────────────────────────────────
red()   { echo -e "\e[91m$*\e[0m" >&2; }
cyan()  { echo -e "\e[96m$*\e[0m" >&2; }
green() { echo -e "\e[92m$*\e[0m" >&2; }

error() { red "ERROR: $*"; exit 1; }
status() { cyan "$*"; }
success() { green "$*"; }

# ── Root check ────────────────────────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    echo "Re-running as root..."
    exec sudo -E bash "$0" "$@"
fi

# ── Argument parsing ──────────────────────────────────────────────────────────
DEVICE=""
UI_OVERRIDE=""
FLAVOR_OVERRIDE=""

while getopts "d:u:f:h" opt; do
    case $opt in
        d) DEVICE="$OPTARG" ;;
        u) UI_OVERRIDE="$OPTARG" ;;
        f) FLAVOR_OVERRIDE="$OPTARG" ;;
        h)
            grep '^#' "$0" | grep -v '#!/' | sed 's/^# \?//'
            exit 0
            ;;
        *) error "Unknown option. Use -h for help." ;;
    esac
done

[ -z "$DEVICE" ] && error "Device required. Use -d <codename> (e.g. -d switch)"

# ── Load device config ────────────────────────────────────────────────────────
DEVICE_CONF="${SCRIPT_DIR}/devices/${DEVICE}/device.conf"
[ -f "$DEVICE_CONF" ] || error "No device.conf at ${DEVICE_CONF}"
# shellcheck source=/dev/null
source "$DEVICE_CONF"

DEVICE_UI="${UI_OVERRIDE:-${DEVICE_UI:-phosh}}"
L4T_FLAVOR="${FLAVOR_OVERRIDE:-${L4T_FLAVOR:-kde-noble}}"

# ── Validate upstream ─────────────────────────────────────────────────────────
[ -f "${UPSTREAM_DIR}/scripts/apply.sh" ] || \
    error "Upstream L4T scripts not found at ${UPSTREAM_DIR}. Run: git submodule update --init"

# ── Validate UI choice ────────────────────────────────────────────────────────
VALID_UIS="phosh plasma-mobile kde lxde mate"
echo "$VALID_UIS" | grep -qw "$DEVICE_UI" || \
    error "Invalid UI '${DEVICE_UI}'. Valid options: ${VALID_UIS}"

[ "$DEVICE_UI" = "gnome" ] && \
    error "GNOME is excluded from Mobuntu-L4T due to known L4T regressions."

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║         Mobuntu-L4T Build System v${VERSION}             ║"
echo "║         Codename: ${CODENAME}          ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
status "  Device   : ${DEVICE_MODEL:-Switch} (${DEVICE})"
status "  UI       : ${DEVICE_UI}"
status "  Flavor   : ${L4T_FLAVOR}"
status "  Upstream : ${UPSTREAM_DIR}"
echo ""

# ── Stage 1: Upstream L4T build ───────────────────────────────────────────────
status "[ 1/3 ] Running upstream Switchroot L4T build (${L4T_FLAVOR})..."
bash "${UPSTREAM_DIR}/scripts/apply.sh" "${L4T_FLAVOR}" || \
    error "Upstream apply.sh failed."

# ── Stage 2: Apply Mobuntu overlays ──────────────────────────────────────────
status "[ 2/3 ] Applying Mobuntu-L4T overlays (UI: ${DEVICE_UI})..."
bash "${SCRIPTS_DIR}/apply-overlays.sh" \
    --rootfs "${UPSTREAM_DIR}/output/rootfs" \
    --overlays "${OVERLAYS_DIR}" \
    --ui "${DEVICE_UI}" || \
    error "Overlay application failed."

# ── Stage 3: Repackage ────────────────────────────────────────────────────────
status "[ 3/3 ] Repackaging for Hekate..."
bash "${UPSTREAM_DIR}/scripts/create_image.sh" "${L4T_FLAVOR}" || \
    error "Image creation failed."

echo ""
success "╔══════════════════════════════════════════════════════╗"
success "║         Mobuntu-L4T build complete!                  ║"
success "║  Output: upstream/l4t-image-buildscripts/output/    ║"
success "║  See docs/HEKATE_CALIBRATION.md before booting.     ║"
success "╚══════════════════════════════════════════════════════╝"
echo ""
