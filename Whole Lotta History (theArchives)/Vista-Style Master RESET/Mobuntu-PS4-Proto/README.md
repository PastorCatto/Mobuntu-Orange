# Mobuntu-PS4

PS4 Linux target for the Mobuntu project. Produces a `dd`-able USB disk image
for PlayStation 4 consoles running firmware 12.52 via GoldHen.

Target hardware: **CUH-12xx** (Belize/Aeolia southbridge)
Kernel upstream: **feeRnt/ps4-linux-12xx** (6.15.4 as of March 2026)

---

## Pipeline

| Stage | Script                   | Purpose                                              |
|------:|--------------------------|------------------------------------------------------|
| 01    | `bootstrap-rootfs.sh`    | Native amd64 debootstrap — no QEMU                  |
| 02    | `pull-kernel.sh`         | Fetch prebuilt bzImage from feeRnt releases, or build from source |
| 03    | `customize-rootfs.sh`    | chroot: packages, GPU/WiFi config, PS4 overlays      |
| 04    | `make-rawimage.sh`       | raw ext4 image via `mke2fs -d`                       |
| 05    | `package-output.sh`      | Assemble MBR disk image: FAT32 (boot) + ext4 (rootfs)|

---

## Quick start

```bash
sudo apt install debootstrap ubuntu-keyring e2fsprogs \
                 parted dosfstools mtools curl jq python3
cd Mobuntu-PS4
sudo ./build.sh
```

Output: `output/mobuntu-ps4-noble-dev.img`

Write to USB:
```bash
sudo dd if=output/mobuntu-ps4-noble-dev.img of=/dev/sdX bs=4M status=progress conv=fsync
```

---

## USB disk layout

```
/dev/sdX
├── p1: FAT32 (256 MiB)      <- kernel artifacts
│   ├── bzImage
│   ├── initramfs.cpio.gz
│   └── cmdline.txt           (reference only)
└── p2: ext4 (8 GiB)         <- rootfs (label: MOBU-PS4)
    └── [Ubuntu noble amd64]
```

---

## Kernel

Default: `KERNEL_MODE=prebuilt` — fetches the latest `feeRnt/ps4-linux-12xx`
release from GitHub (no compilation needed).

To build from source:
```bash
sudo KERNEL_MODE=source ./build.sh
```

Known-good cmdline (from feeRnt 6.15.4):
```
panic=0 clocksource=tsc consoleblank=0 net.ifnames=0 radeon.dpm=0 amdgpu.dpm=0
drm.debug=0 console=uart8250,mmio32,0xd0340000 console=ttyS0,115200n8
console=tty0 drm.edid_firmware=edid/1920x1080.bin
```
Override via `PS4_CMDLINE` in `build.env`.

---

## PS4 side: boot flow

1. Jailbreak with GoldHen (supports FW 12.52)
2. Launch the Linux kexec payload from the homebrew launcher
3. Payload reads `bzImage` + `initramfs.cpio.gz` from USB FAT32 (p1)
4. kexec boots into the kernel; rootfs mounts from USB ext4 (p2)
5. Login: `mobuntu` / `mobuntu` — **change immediately**

---

## Known gaps / TODO

- [ ] PS4 controller (DualShock 4) input — likely needs `hid-playstation` or
      a PS4-specific driver; verify in `linux-firmware` or the kernel config
- [ ] Internal storage boot — after first boot, some payloads copy
      `bzImage`+`initramfs` to `/data/linux/boot/` on the PS4's internal
      drive. Wire a post-install script if needed.
- [ ] Bluetooth pairing — `bluez` is installed; verify BT firmware blob
      (`BCM20702A1-0a5c-21e8.hcd` or similar) lands from `linux-firmware`
- [ ] HDMI — feeRnt's kernel has HDMI fixes for CUH-12xx; the `amdgpu`
      Xorg config is a starting point, may need `drm.edid_firmware` tuning
      per display
- [ ] Verify PS4 Pro (CUH-7xxx) — different GPU, `feeRnt/ps4-linux-12xx`
      is CUH-12xx focused. Pro needs a separate kernel branch.
