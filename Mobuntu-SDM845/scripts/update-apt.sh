#!/bin/sh

set -eu

echo "Update full source.list"
apt-get update
apt-get full-upgrade -y

echo "Remove for sucesfull generated initrd"
rm -rf /etc/kernel/postinst.d/dkms
