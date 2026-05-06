#!/bin/sh

set -eu

# ── Firmware ──────────────────────────────────────────────────────────────────
echo "Install firmware"
dpkg -i --force-overwrite /opt/*.deb

# ── Kernel ────────────────────────────────────────────────────────────────────
KERNEL_PKG="${KERNEL_PKG:-linux-image-6.18-sdm845}"
KERNEL_HEADERS_PKG="${KERNEL_HEADERS_PKG:-linux-headers-6.18-sdm845}"
echo "Install kernel: $KERNEL_PKG"
apt-get install -y "$KERNEL_PKG" "$KERNEL_HEADERS_PKG"

# ── Audio ─────────────────────────────────────────────────────────────────────
echo "Fix alsa-ucm-conf"
wget https://repo.mobian.org/pool/main/a/alsa-ucm-conf/alsa-ucm-conf_1.2.15.3-1mobian3_all.deb
dpkg -i --force-overwrite alsa-ucm-conf_1.2.15.3-1mobian3_all.deb
apt-mark hold alsa-ucm-conf

echo "Mask for working speakers"
systemctl mask alsa-state alsa-restore

echo "For working internet if you wanna change image in chroot"
rm -rf /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf

# ── UI ────────────────────────────────────────────────────────────────────────
DEVICE_UI="${DEVICE_UI:-ubuntu-desktop-minimal}"
echo "Install UI: $DEVICE_UI"
case "$DEVICE_UI" in
  phosh)
    apt-get install -y phosh phoc
    systemctl enable phosh
    ;;
  plasma-mobile)
    apt-get install -y plasma-mobile
    systemctl enable sddm
    ;;
  *)
    apt-get install -y gnome-shell-extension-manager gnome-shell-extensions
    ;;
esac

# ── Cleanup ───────────────────────────────────────────────────────────────────
echo "Clean packages"
apt-get -y autoremove --purge

# ── GNOME extensions (desktop only) ──────────────────────────────────────────
case "$DEVICE_UI" in
  phosh|plasma-mobile) ;;
  *)
    echo "Disable verify gnome-shell-extension"
    gsettings set org.gnome.shell disable-extension-version-validation true
    echo "Force scale 3.0"
    glib-compile-schemas /usr/share/glib-2.0/schemas
    echo "Enabling shell-extensions"
    gnome-extensions enable aurora-shell@luminusos.github.io
    gnome-extensions enable touchup@mityax
    gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com
    ;;
esac

# ── Services ──────────────────────────────────────────────────────────────────
echo "For resizing rootfs partition"
systemctl enable grow-rootfs.service
