#!/usr/bin/env bash
# scripts/customize-rootfs.sh
# Installs UI packages, overlays, user setup, and PS4-specific config
# into the debootstrapped rootfs.

set -euo pipefail

ROOTFS="" OVERLAYS="" UI="" SUITE="" HOSTNAME_VAL="" USERNAME="" PASSWORD=""
ENABLE_THESEUS="false"
ENABLE_DESKTOP="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rootfs)   ROOTFS="$2";       shift 2 ;;
        --overlays) OVERLAYS="$2";     shift 2 ;;
        --ui)       UI="$2";           shift 2 ;;
        --suite)    SUITE="$2";        shift 2 ;;
        --hostname) HOSTNAME_VAL="$2"; shift 2 ;;
        --username) USERNAME="$2";     shift 2 ;;
        --password) PASSWORD="$2";     shift 2 ;;
        --theseus)  ENABLE_THESEUS="$2"; shift 2 ;;
        --desktop)  ENABLE_DESKTOP="$2"; shift 2 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

cyan()  { echo -e "\e[96m    $*\e[0m"; }
green() { echo -e "\e[92m    $*\e[0m"; }
error() { echo -e "\e[91mERROR: $*\e[0m" >&2; exit 1; }

[ -d "$ROOTFS" ]   || error "rootfs not found"
[ -d "$OVERLAYS" ] || error "overlays not found"

# ── Resolve UI packages ───────────────────────────────────────────────────────
case "$UI" in
    gnustep)
        UI_PACKAGES="gnustep gnustep-devel windowmaker"
        UI_SESSION="gnustep"
        ;;
    lxde)
        UI_PACKAGES="lxde lxde-core"
        UI_SESSION="LXDE"
        ;;
    lxqt)
        UI_PACKAGES="lxqt"
        UI_SESSION="lxqt"
        ;;
    *)
        error "Unknown UI: ${UI}"
        ;;
esac

# ── Apply overlays ────────────────────────────────────────────────────────────
cyan "Applying overlays..."
cp -r "${OVERLAYS}/etc"  "${ROOTFS}/" 2>/dev/null || true
cp -r "${OVERLAYS}/usr"  "${ROOTFS}/" 2>/dev/null || true

# Apply Theseus overlay (Doctor Octavius builds)
if [ "$ENABLE_THESEUS" = "true" ]; then
    cyan "Applying Theseus overlay (Doctor Octavius)..."
    cp -r "${OVERLAYS}/theseus/etc" "${ROOTFS}/"  2>/dev/null || true
    cp -r "${OVERLAYS}/theseus/var" "${ROOTFS}/"  2>/dev/null || true
fi

# ── Hostname ──────────────────────────────────────────────────────────────────
cyan "Setting hostname: ${HOSTNAME_VAL}..."
echo "$HOSTNAME_VAL" > "${ROOTFS}/etc/hostname"
cat > "${ROOTFS}/etc/hosts" <<EOF
127.0.0.1   localhost
127.0.1.1   ${HOSTNAME_VAL}
EOF

# ── Install packages in chroot ────────────────────────────────────────────────
cyan "Installing UI and system packages (${UI})..."

# Base session packages — LightDM for standard builds, xinit for Theseus
if [ "$ENABLE_THESEUS" = "true" ]; then
    SESSION_PKGS="xinit x11-xserver-utils"
else
    SESSION_PKGS="lightdm"
fi

# Desktop fallback packages (only with Theseus)
DESKTOP_PKGS=""
if [ "$ENABLE_DESKTOP" = "true" ]; then
    DESKTOP_PKGS="lxde lxde-core"
fi

# Theseus build dependencies
THESEUS_PKGS=""
if [ "$ENABLE_THESEUS" = "true" ]; then
    THESEUS_PKGS="build-essential pkg-config libsdl2-dev libsdl2-mixer-dev libmpv-dev libcurl4-openssl-dev"
fi

chroot "$ROOTFS" /bin/bash -c "
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq

    # Core system
    apt-get install -y --no-install-recommends \
        ${SESSION_PKGS} \
        xserver-xorg \
        xserver-xorg-input-libinput \
        pulseaudio \
        alsa-utils \
        bluez \
        network-manager \
        sudo \
        curl \
        wget \
        git \
        htop \
        nano \
        steam-installer \
        ${UI_PACKAGES} \
        ${THESEUS_PKGS} \
        ${DESKTOP_PKGS}

    apt-get clean
    rm -rf /var/lib/apt/lists/*
"

# ── Session setup ─────────────────────────────────────────────────────────────
if [ "$ENABLE_THESEUS" = "true" ]; then
    # Doctor Octavius: startx via systemd, no display manager
    cyan "Configuring startx session (Theseus / Doctor Octavius)..."

    # Copy Theseus source into rootfs for build
    SCRIPT_DIR_REL="$(dirname "$0")"
    THESEUS_SRC="${SCRIPT_DIR_REL}/../upstream/theseus"
    if [ -d "$THESEUS_SRC" ]; then
        cyan "Copying Theseus source into rootfs..."
        cp -r "$THESEUS_SRC" "${ROOTFS}/usr/local/src/theseus"
    fi

    # Copy session switcher source
    SWITCHER_SRC="${OVERLAYS}/theseus/session-switcher"
    if [ -d "$SWITCHER_SRC" ]; then
        cp -r "$SWITCHER_SRC" "${ROOTFS}/usr/local/src/session-switcher"
    fi

    # Build Theseus and session switcher inside chroot
    chroot "$ROOTFS" /bin/bash -c "
        set -e
        cd /usr/local/src/theseus/build
        make desktop
        cp theseus /usr/local/bin/theseus
        chmod +x /usr/local/bin/theseus

        # Build session switcher
        cd /usr/local/src/session-switcher
        make
        cp session-switcher /usr/local/bin/mobuntu-session-switcher
        chmod +x /usr/local/bin/mobuntu-session-switcher
    " || { warn "Theseus build failed inside chroot — binary may need manual installation"; }

    # Enable mobuntu-session systemd service (starts X on boot)
    chroot "$ROOTFS" /bin/bash -c "
        systemctl enable mobuntu-session NetworkManager bluetooth 2>/dev/null || true
    "

else
    # Spider-Man baseline: LightDM autologin
    cyan "Configuring LightDM for ${UI}..."
    mkdir -p "${ROOTFS}/etc/lightdm/lightdm.conf.d"
    cat > "${ROOTFS}/etc/lightdm/lightdm.conf.d/50-mobuntu.conf" <<EOF
[Seat:*]
autologin-guest=false
autologin-user=${USERNAME:-mobuntu}
autologin-user-timeout=0
autologin-session=${UI_SESSION}
user-session=${UI_SESSION}
EOF

    chroot "$ROOTFS" /bin/bash -c "
        systemctl enable lightdm NetworkManager bluetooth 2>/dev/null || true
    "
fi

# ── User setup ────────────────────────────────────────────────────────────────
if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
    cyan "Creating preseeded user: ${USERNAME}..."
    chroot "$ROOTFS" /bin/bash -c "
        useradd -m -s /bin/bash -G sudo,audio,video,input,plugdev '${USERNAME}'
        echo '${USERNAME}:${PASSWORD}' | chpasswd
    "
else
    cyan "No preseed credentials — creating default user 'mobuntu'..."
    chroot "$ROOTFS" /bin/bash -c "
        useradd -m -s /bin/bash -G sudo,audio,video,input,plugdev mobuntu
        echo 'mobuntu:mobuntu' | chpasswd
        passwd -e mobuntu
    "
fi

# ── PS4 kernel cmdline reference ──────────────────────────────────────────────
cyan "Writing bootargs reference..."
cat > "${ROOTFS}/etc/mobuntu-bootargs.txt" <<EOF
# Mobuntu-PS4 recommended kernel cmdline
# Pass this to your PS4 Linux payload / bootargs.txt on FAT32 partition
panic=0 clocksource=tsc consoleblank=0 net.ifnames=0 radeon.dpm=0 amdgpu.dpm=0
drm.debug=0 console=uart8250,mmio32,0xd0340000 console=ttyS0,115200n8
console=tty0 drm.edid_firmware=edid/1920x1080.bin
EOF

green "Rootfs customization complete."
