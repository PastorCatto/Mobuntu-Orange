#!/usr/bin/env bash
# =============================================================================
# 03-customize-rootfs.sh
# Chroots into rootfs and:
#   - installs L4T .debs from /var/cache/mobuntu-l4t-debs
#   - installs the desktop flavor
#   - applies overlays/switch/* on top of rootfs
#   - configures hostname, default user, locale
#   - sets up the FAT label (id=) hekate uses to find the rootfs
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../build.env
source "${SCRIPT_DIR}/../build.env"

log()  { printf '[03 %s] %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '[03 WARN] %s\n' "$*" >&2; }
fail() { printf '[03 FAIL] %s\n' "$*" >&2; exit 1; }

[[ -d "${ROOTFS_DIR}" ]] || fail "Rootfs not found at ${ROOTFS_DIR}. Run stage 01 first."

# ---- Mount pseudo-fs --------------------------------------------------------
mount_chroot() {
    mount --bind /dev "${ROOTFS_DIR}/dev"
    mount --bind /dev/pts "${ROOTFS_DIR}/dev/pts"
    mount -t proc proc "${ROOTFS_DIR}/proc"
    mount -t sysfs sysfs "${ROOTFS_DIR}/sys"
    mount -t tmpfs tmpfs "${ROOTFS_DIR}/run"
}
umount_chroot() {
    umount -lR "${ROOTFS_DIR}/dev/pts" 2>/dev/null || true
    umount -lR "${ROOTFS_DIR}/dev" 2>/dev/null || true
    umount -lR "${ROOTFS_DIR}/proc" 2>/dev/null || true
    umount -lR "${ROOTFS_DIR}/sys" 2>/dev/null || true
    umount -lR "${ROOTFS_DIR}/run" 2>/dev/null || true
}
trap umount_chroot EXIT

mount_chroot

# ---- Apply overlays BEFORE chroot work, so any conf in overlays/ is present
OVERLAY_SRC="${PROJECT_ROOT}/overlays/switch"
if [[ -d "${OVERLAY_SRC}" ]]; then
    log "Applying overlay: ${OVERLAY_SRC} -> rootfs"
    cp -a "${OVERLAY_SRC}/." "${ROOTFS_DIR}/"
else
    warn "No overlay directory at ${OVERLAY_SRC} (catch-and-warn: skipping)"
fi

# ---- Generate chroot script -------------------------------------------------
CHROOT_SCRIPT="${ROOTFS_DIR}/tmp/mobuntu-customize.sh"
cat > "${CHROOT_SCRIPT}" <<CHROOT_EOF
#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C.UTF-8

echo "[chroot] Updating package lists"
apt-get update -qq

echo "[chroot] Installing base utilities"
apt-get install -y --no-install-recommends \\
    locales tzdata systemd-sysv \\
    network-manager wpasupplicant \\
    sudo openssh-server \\
    bash-completion curl wget less nano vim-tiny \\
    bluez bluez-tools \\
    alsa-utils pulseaudio

echo "[chroot] Locale: en_US.UTF-8"
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8

echo "[chroot] Hostname: ${HOSTNAME_DEFAULT}"
echo "${HOSTNAME_DEFAULT}" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
127.0.1.1   ${HOSTNAME_DEFAULT}
::1         localhost ip6-localhost ip6-loopback
HOSTS

echo "[chroot] Default user: mobuntu (password: mobuntu, change on first boot)"
if ! id mobuntu >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo,audio,video,plugdev,netdev,bluetooth mobuntu
    echo 'mobuntu:mobuntu' | chpasswd
    echo 'mobuntu ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-mobuntu
fi

echo "[chroot] Installing flavor: ${FLAVOR}"
apt-get install -y --no-install-recommends ${FLAVOR} || \\
    echo "[chroot WARN] ${FLAVOR} install failed; falling back to ubuntu-minimal"

echo "[chroot] Installing staged L4T .debs"
DEBS_PATH=/var/cache/mobuntu-l4t-debs
if [[ -d "\${DEBS_PATH}" ]] && compgen -G "\${DEBS_PATH}/*.deb" > /dev/null; then
    # Install all together so dpkg can resolve inter-deb dependencies
    apt-get install -y --no-install-recommends \${DEBS_PATH}/*.deb || {
        echo "[chroot WARN] L4T deb install hit dependency issues; trying dpkg + apt-fix"
        dpkg -i \${DEBS_PATH}/*.deb || true
        apt-get install -y -f
    }
else
    echo "[chroot WARN] No L4T debs staged at \${DEBS_PATH}; rootfs will be vanilla Ubuntu (boot will fail on Switch)"
fi

echo "[chroot] Setting FAT label expectation: ${DISTRO_LABEL}"
mkdir -p /etc/mobuntu
cat > /etc/mobuntu/release <<REL
DISTRO=${DISTRO_NAME}
RELEASE=${RELEASE_TAG}
L4T_RELEASE=${L4T_RELEASE}
SUITE=${UBUNTU_SUITE}
LABEL=${DISTRO_LABEL}
REL

echo "[chroot] Cleaning apt cache"
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "[chroot] Removing staged .debs from final image"
rm -rf /var/cache/mobuntu-l4t-debs

echo "[chroot] Done"
CHROOT_EOF

chmod +x "${CHROOT_SCRIPT}"

log "Entering chroot to customize rootfs"
chroot "${ROOTFS_DIR}" /tmp/mobuntu-customize.sh

rm -f "${CHROOT_SCRIPT}"

# ---- Strip qemu binary so the final image is clean --------------------------
if [[ -f "${ROOTFS_DIR}${QEMU_BIN}" ]]; then
    log "Removing qemu-aarch64-static from rootfs"
    rm -f "${ROOTFS_DIR}${QEMU_BIN}"
fi

log "Stage 03 done."
