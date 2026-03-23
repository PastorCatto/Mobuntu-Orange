#!/bin/bash
set -e

CHROOT_DIR=$1

if [ -z "$CHROOT_DIR" ]; then
    echo "Usage: sudo $0 /path/to/your/mnt_root"
    exit 1
fi

echo "--- Preparing Chroot Environment at $CHROOT_DIR ---"

# 1. Mount virtual filesystems securely
mount --bind /dev "$CHROOT_DIR/dev"
mount --bind /dev/pts "$CHROOT_DIR/dev/pts"
mount --bind /proc "$CHROOT_DIR/proc"
mount --bind /sys "$CHROOT_DIR/sys"
cp /etc/resolv.conf "$CHROOT_DIR/etc/resolv.conf"

# 2. Generate the Payload Script directly inside the chroot
cat << 'EOF' > "$CHROOT_DIR/tmp/apply_fixes.sh"
#!/bin/bash
set -ex
export DEBIAN_FRONTEND=noninteractive

echo "--- 1. Installing Required Stacks ---"
apt-get update
apt-get install -y alsa-ucm-conf bluez git rsync

echo "--- 2. Applying ALSA UCM Audio Fixes ---"
rm -rf /tmp/sdm845-ucm
git clone --depth 1 https://gitlab.com/sdm845-mainline/alsa-ucm-conf.git /tmp/sdm845-ucm
cp -rv /tmp/sdm845-ucm/ucm2/* /usr/share/alsa/ucm2/

echo "--- 3. Injecting Beryllium Firmware (WiFi/BT/DSP) ---"
rm -rf /tmp/beryllium-fw
git clone --depth 1 https://github.com/TheMuppets/proprietary_vendor_xiaomi_beryllium.git /tmp/beryllium-fw

# Create exact target directories
mkdir -p /lib/firmware/qcom/sdm845
mkdir -p /lib/firmware/ath10k/WCN3990/hw1.0
mkdir -p /lib/firmware/qca

# Nuke old, corrupted, or mismatched firmware to prevent SCM -22 errors
rm -f /lib/firmware/qcom/sdm845/wlanmdsp*
rm -f /lib/firmware/ath10k/WCN3990/hw1.0/*

# 3a. Secure DSP Firmware
cp -v /tmp/beryllium-fw/proprietary/vendor/firmware/wlanmdsp.* /lib/firmware/qcom/sdm845/

# 3b. WiFi Firmware & Board Data
find /tmp/beryllium-fw -name "wlanmdsp.mbn" -exec cp -v {} /lib/firmware/ath10k/WCN3990/hw1.0/ \;
find /tmp/beryllium-fw -name "bdwlan.bin" -exec cp -v {} /lib/firmware/ath10k/WCN3990/hw1.0/board-2.bin \;

# 3c. Bluetooth Firmware
cp -rv /tmp/beryllium-fw/proprietary/vendor/firmware/qca/* /lib/firmware/qca/

echo "--- 4. Enabling Services ---"
# Ensure the Bluetooth daemon starts on boot
systemctl enable bluetooth.service

# Ensure the Qualcomm services we built earlier are enabled
# (Using || true so the script doesn't fail if one