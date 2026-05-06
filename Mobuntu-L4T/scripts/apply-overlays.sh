#!/usr/bin/env bash
# scripts/apply-overlays.sh
# Applies Mobuntu-L4T overlays onto the upstream rootfs.
# Called by build.sh after upstream apply.sh completes.
#
# Usage:
#   apply-overlays.sh --rootfs <path> --overlays <path> --ui <ui>

set -euo pipefail

ROOTFS=""
OVERLAYS=""
UI=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rootfs)   ROOTFS="$2";   shift 2 ;;
        --overlays) OVERLAYS="$2"; shift 2 ;;
        --ui)       UI="$2";       shift 2 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

[ -d "$ROOTFS" ]   || { echo "ERROR: rootfs not found at ${ROOTFS}"; exit 1; }
[ -d "$OVERLAYS" ] || { echo "ERROR: overlays not found at ${OVERLAYS}"; exit 1; }

cyan()  { echo -e "\e[96m$*\e[0m"; }
green() { echo -e "\e[92m$*\e[0m"; }

# ── Step 1: Copy base overlays ────────────────────────────────────────────────
cyan "  Applying base overlays..."
cp -r "${OVERLAYS}/etc"  "${ROOTFS}/" 2>/dev/null || true
cp -r "${OVERLAYS}/usr"  "${ROOTFS}/" 2>/dev/null || true

# ── Step 2: Install UI packages in chroot ─────────────────────────────────────
cyan "  Installing UI packages for: ${UI}..."

case "$UI" in
    phosh)
        PACKAGES="phosh phosh-mobile-settings fonts-cantarell"
        SESSION_TYPE="wayland"
        ;;
    plasma-mobile)
        PACKAGES="plasma-mobile plasma-nm plasma-pa"
        SESSION_TYPE="wayland"
        ;;
    kde)
        PACKAGES="kde-standard"
        SESSION_TYPE="x11"
        ;;
    lxde)
        PACKAGES="lxde"
        SESSION_TYPE="x11"
        ;;
    mate)
        PACKAGES="mate-desktop-environment-core"
        SESSION_TYPE="x11"
        ;;
    *)
        echo "ERROR: Unknown UI: ${UI}"; exit 1 ;;
esac

# Install in chroot
chroot "${ROOTFS}" /bin/bash -c "
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y --no-install-recommends ${PACKAGES}
    apt-get clean
"

# ── Step 3: Configure display manager ────────────────────────────────────────
cyan "  Configuring display manager for ${UI} (${SESSION_TYPE})..."

if [ "$SESSION_TYPE" = "wayland" ]; then
    # Set autologin session to wayland UI
    sed -i "s|^autologin-session=.*|autologin-session=${UI}|" \
        "${ROOTFS}/etc/lightdm/lightdm.conf.d/50-mobuntu.conf" 2>/dev/null || true
else
    sed -i "s|^autologin-session=.*|autologin-session=${UI}|" \
        "${ROOTFS}/etc/lightdm/lightdm.conf.d/50-mobuntu.conf" 2>/dev/null || true
fi

# ── Step 4: Joy-Con service ───────────────────────────────────────────────────
cyan "  Enabling Joy-Con daemon..."
chroot "${ROOTFS}" /bin/bash -c "
    systemctl enable joycond.service 2>/dev/null || true
"

# ── Step 5: UI select service ─────────────────────────────────────────────────
cyan "  Enabling Mobuntu UI select service..."
chroot "${ROOTFS}" /bin/bash -c "
    systemctl enable mobuntu-ui-select.service 2>/dev/null || true
"

green "  Overlays applied successfully."
