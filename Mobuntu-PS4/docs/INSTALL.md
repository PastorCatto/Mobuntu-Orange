# Mobuntu-PS4 Install Guide
# Codename: Spider-Man

## Prerequisites

- Jailbroken PS4 (GoldHen recommended)
- USB 3.0 drive >= 16GB (for external boot)
- Ubuntu 24.04 build host with Docker installed
- strawberry kernel (6.18.21) bzImage — see upstream/UPSTREAM_SOURCES.md

---

## Step 1 — Get the kernel

Download `bzImage` from:
https://github.com/rmuxnet/ps4-linux-12xx/releases

Place it at:
```
Mobuntu-PS4/upstream/bzImage
```

---

## Step 2 — Build

### External USB boot (recommended for first install)
```bash
sudo ./build.sh -d ps4 -p external
```

### Internal HDD boot — fat PS4 (Aeolia board)
```bash
sudo ./build.sh -d ps4 -p aeolia
```

### Internal HDD boot — PS4 Slim/newer (Belize board)
```bash
sudo ./build.sh -d ps4 -p belize
```

### Options
```bash
sudo ./build.sh -d ps4 -p external -u lxde -b trixie
```

| Flag | Options | Default |
|------|---------|---------|
| `-p` | external, aeolia, belize | required |
| `-u` | gnustep, lxde, lxqt | from device.conf |
| `-b` | bookworm, trixie | from device.conf |

---

## Step 3 — Prepare USB (external boot)

Format USB with two partitions:
```
p1: FAT32  (256MB minimum)
p2: ext4   (label: MOBU-PS4, rest of drive)
```

Copy boot files to FAT32:
```bash
cp output/boot-files/bzImage         /mnt/fat32/
cp output/boot-files/initramfs.cpio.gz /mnt/fat32/
cp output/boot-files/bootargs.txt    /mnt/fat32/
```

Extract rootfs to ext4:
```bash
sudo tar -xJf output/mobuntu-ps4-external-*.tar.xz -C /mnt/ext4/
```

---

## Step 4 — Boot

1. Jailbreak PS4 with GoldHen
2. Launch Linux payload from homebrew launcher
3. Payload reads `bzImage` + `initramfs.cpio.gz` from USB FAT32
4. Rootfs mounts from ext4 partition (label: MOBU-PS4)
5. Login: `mobuntu` / `mobuntu` — forced password change on first login

---

## Internal HDD Boot (after external boot works)

1. Boot via external USB first
2. From rescue shell, mount internal HDD
3. Copy `output/boot-files/*` to `/data/linux/boot/` on internal drive
4. Extract rootfs tarball to internal ext4 partition
5. Reboot — payload auto-detects internal boot files

---

## UI Options

| UI | Notes |
|----|-------|
| `gnustep` | Primary — minimal, X11-native, lowest RAM overhead |
| `lxde` | Lightweight GTK desktop |
| `lxqt` | Lightweight Qt desktop |

All UIs are X11-based. Steam is installed and available on all variants.

---

## Bootargs

The recommended kernel cmdline is written to `output/boot-files/bootargs.txt`
and also to `/etc/mobuntu-bootargs.txt` inside the rootfs.

```
panic=0 clocksource=tsc consoleblank=0 net.ifnames=0 radeon.dpm=0 amdgpu.dpm=0
drm.debug=0 console=uart8250,mmio32,0xd0340000 console=ttyS0,115200n8
console=tty0 drm.edid_firmware=edid/1920x1080.bin
```

---

## References

- Guide: https://dionkill.github.io/ps4-linux-tutorial/
- Kernel: https://github.com/rmuxnet/ps4-linux-12xx/releases
- Mesa: https://github.com/FalsePhilosopher/mesa-docker-ps4
- GoldHen: https://github.com/GoldHEN/GoldHEN
