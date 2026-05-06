# Hekate Joy-Con Calibration Guide
# Mobuntu-L4T — Codename: Happy Mask Salesman

Mobuntu-L4T does NOT include a calibration script.
Joy-Con calibration data is dumped from Horizon OS via Hekate before booting L4T.
This ensures accurate stick and button calibration without reverse-engineering Nintendo's data.

---

## Steps

### 1. Boot into Hekate
- Hold VOL+ while powering on (or use a jig/modchip)
- You should see the Hekate bootloader menu

### 2. Dump Joy-Con calibration
- Navigate to: **Tools → Partition Manager → emuMMC / sysMMC**
- Or: **Tools → Backup & Restore → Backup eMMC**
- Hekate writes calibration data to the SD card

### 3. Place calibration data
The joycond daemon on Mobuntu-L4T will look for calibration data at:
```
/sys/kernel/debug/hid/   (runtime, from kernel)
```
Hekate passes calibration data to the kernel at boot via DTB/memory maps.
No manual file placement is required if using a compatible Switchroot kernel.

### 4. Boot Mobuntu-L4T
- Select Mobuntu-L4T from Hekate menu
- joycond.service starts automatically
- Joy-Cons connect via Bluetooth or rail

---

## Troubleshooting

**Joy-Cons not detected:**
- Ensure joycond.service is running: `systemctl status joycond`
- Check udev rules: `ls /etc/udev/rules.d/99-joycon.rules`
- Reload udev: `sudo udevadm control --reload-rules`

**Calibration off:**
- Re-dump from Hekate with Joy-Cons attached to console
- Ensure using a Switchroot kernel with Joy-Con calibration patches

---

## References
- Hekate: https://github.com/CTCaer/hekate/releases
- joycond: https://github.com/nicman23/joycond
- Switchroot kernel: See upstream/UPSTREAM_SOURCES.md
