#!/usr/bin/env bash
# =============================================================================
# 03-customize-rootfs.sh  (PS4 variant)
# Chroots into the amd64 rootfs and installs PS4-specific packages,
# firmware, GPU/WiFi/BT support, and Mobuntu overlays.
#
# No QEMU needed — host and target are both x86-64.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../build.env"

log()  { printf '[03 %s] %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '[03 WARN] %s\n' "$*" >&2; }
fail() { printf '[03 FAIL] %s\n' "$*" >&2; exit 1; }

[[ -d "${ROOTFS_DIR}" ]] || fail "Rootfs not found at ${ROOTFS_DIR}. Run stage 01 first."

mount_chroot() {
    mount --bind /dev "${ROOTFS_DIR}/dev"
    mount --bind /dev/pts "${ROOTFS_DIR}/dev/pts"
    mount -t proc proc "${ROOTFS_DIR}/proc"
    mount -t sysfs sysfs "${ROOTFS_DIR}/sys"
    mount -t tmpfs tmpfs "${ROOTFS_DIR}/run"
}
umount_chroot() {
    for mnt in dev/pts dev proc sys run; do
        umount -lR "${ROOTFS_DIR}/${mnt}" 2>/dev/null || true
    done
}
trap umount_chroot EXIT
mount_chroot

# ---- Apply overlays ---------------------------------------------------------
OVERLAY_SRC="${PROJECT_ROOT}/overlays/ps4"
if [[ -d "${OVERLAY_SRC}" ]]; then
    log "Applying overlays from ${OVERLAY_SRC}"
    cp -a "${OVERLAY_SRC}/." "${ROOTFS_DIR}/"
else
    warn "No overlay directory at ${OVERLAY_SRC} (catch-and-warn: skipping)"
fi

# ---- Stage kernel modules if present ----------------------------------------
# If stage 02 built/fetched kernel modules alongside bzImage, copy them in.
MODULES_TAR="${KERNEL_DIR}/modules.tar.gz"
if [[ -f "${MODULES_TAR}" ]]; then
    log "Staging kernel modules from ${MODULES_TAR}"
    tar -xzf "${MODULES_TAR}" -C "${ROOTFS_DIR}/"
else
    warn "No kernel modules archive at ${MODULES_TAR} (catch-and-warn: continuing)"
    warn "If WiFi/BT/GPU modules are needed, supply modules.tar.gz in ${KERNEL_DIR}/"
fi

# ---- Generate chroot script -------------------------------------------------
CHROOT_SCRIPT="${ROOTFS_DIR}/tmp/mobuntu-ps4-customize.sh"
cat > "${CHROOT_SCRIPT}" <<CHROOT_EOF
#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C.UTF-8

echo "[chroot] Updating package lists"
apt-get update -qq

echo "[chroot] Installing base packages"
apt-get install -y --no-install-recommends \\
    locales tzdata systemd-sysv \\
    network-manager wpasupplicant \\
    sudo openssh-server \\
    bash-completion curl wget less nano vim-tiny \\
    usbutils pciutils \\
    alsa-utils pulseaudio \\
    bluez bluez-tools \\
    mesa-utils \\
    xserver-xorg-core xserver-xorg-video-amdgpu xserver-xorg-video-radeon \\
    firmware-linux firmware-amd-graphics \\
    linux-firmware \\
    libdrm-amdgpu1 libdrm-radeon1 \\
    xfce4 xfce4-terminal lightdm \\
    dbus-x11

echo "[chroot] Locale + hostname"
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8
echo "${HOSTNAME_DEFAULT}" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
127.0.1.1   ${HOSTNAME_DEFAULT}
::1         localhost ip6-localhost ip6-loopback
HOSTS

echo "[chroot] Default user: mobuntu / mobuntu"
if ! id mobuntu >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo,audio,video,plugdev,netdev,bluetooth,input mobuntu
    echo 'mobuntu:mobuntu' | chpasswd
    echo 'mobuntu ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-mobuntu
fi

echo "[chroot] Enabling services"
systemctl enable NetworkManager lightdm 2>/dev/null || true
systemctl enable bluetooth 2>/dev/null || true

echo "[chroot] PS4 GPU cmdline config"
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/10-ps4-gpu.conf <<XORG
Section "Device"
    Identifier  "PS4 Liverpool GPU"
    Driver      "amdgpu"
    Option      "DRI"       "3"
    Option      "TearFree"  "on"
EndSection
XORG

echo "[chroot] Writing /etc/mobuntu/release"
mkdir -p /etc/mobuntu
cat > /etc/mobuntu/release <<REL
DISTRO=${DISTRO_NAME}
RELEASE=${RELEASE_TAG}
SUITE=${UBUNTU_SUITE}
KERNEL_MODE=${KERNEL_MODE}
KERNEL_TAG=${KERNEL_TAG}
FIRMWARE_TARGET=12.52
REL

echo "[chroot] PS4 kernel cmdline hint"
mkdir -p /etc/mobuntu
cat > /etc/mobuntu/kernel-cmdline.txt <<CMD
${PS4_CMDLINE}
CMD

echo "[chroot] Cleaning up"
apt-get clean
rm -rf /var/lib/apt/lists/*
CHROOT_EOF

chmod +x "${CHROOT_SCRIPT}"
log "Running chroot customization"
chroot "${ROOTFS_DIR}" /tmp/mobuntu-ps4-customize.sh
rm -f "${CHROOT_SCRIPT}"

log "Stage 03 done."
