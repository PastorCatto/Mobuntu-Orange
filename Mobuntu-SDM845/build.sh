#!/bin/sh

export PATH=/sbin:/usr/sbin:$PATH

DEVICE=""
username=
password=
image_only=

while getopts "d:up" opt; do
  case "$opt" in
    d ) DEVICE="$OPTARG" ;;
    u ) username="$OPTARG" ;;
    p ) password="$OPTARG" ;;
  esac
done

if [ -z "$DEVICE" ]; then
  echo "Usage: $0 -d <device> [-u username] [-p password]"
  echo ""
  echo "Available devices:"
  for d in "$(dirname "$0")/devices"/*/; do
    conf="$d/device.conf"
    [ -f "$conf" ] && . "$conf" && echo "  $(basename "$d")  -- $DEVICE_MODEL ($DEVICE_BRAND)"
  done
  exit 1
fi

DEVICE_CONF="$(dirname "$0")/devices/$DEVICE/device.conf"
if [ ! -f "$DEVICE_CONF" ]; then
  echo "ERROR: No device.conf at $DEVICE_CONF"
  exit 1
fi
. "$DEVICE_CONF"

SUITE="${DEVICE_SUITE:-plucky}"
KERNEL_PKG="${KERNEL_APT_NAME:-linux-image-6.18-sdm845}"
KERNEL_HEADERS_PKG="${KERNEL_HEADERS_APT_NAME:-linux-headers-6.18-sdm845}"
DEVICE_UI="${DEVICE_UI:-ubuntu-desktop-minimal}"

IMG_FILE="mobuntu-${DEVICE}-$(date +%Y%m%d).img"
ROOTFS_FILE="mobuntu-rootfs-${DEVICE}.tar.gz"

ARGS="--disable-fakemachine --scratchsize=10G"
ARGS="$ARGS -t device:$DEVICE"
ARGS="$ARGS -t suite:$SUITE"
ARGS="$ARGS -t image:$IMG_FILE"
ARGS="$ARGS -t rootfs:$ROOTFS_FILE"
ARGS="$ARGS -t kernel_pkg:$KERNEL_PKG"
ARGS="$ARGS -t kernel_headers_pkg:$KERNEL_HEADERS_PKG"
ARGS="$ARGS -t device_ui:$DEVICE_UI"

if [ "$username" ]; then
  ARGS="$ARGS -t username:\"$username\""
fi
if [ "$password" ]; then
  ARGS="$ARGS -t password:\"$password\""
fi

cd "$(dirname "$0")"

if [ ! "$image_only" ]; then
  # shellcheck disable=SC2086
  debos $ARGS rootfs.yaml || exit 1
fi
# shellcheck disable=SC2086
debos $ARGS image.yaml

echo ""
echo "Build complete: $IMG_FILE"
echo "Compressing..."
gzip --keep --force "$IMG_FILE"
