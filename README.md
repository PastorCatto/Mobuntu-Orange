# Mobuntu

Multi-platform Ubuntu image builder. Each variant targets a different device
family and produces a different output format. All variants share the same
`devkit.py` auto-runner at the repo root.

Built on top of [arkadin91/mobuntu-recipes](https://github.com/arkadin91/mobuntu-recipes)
for the SDM845 target. L4T and PS4 variants are standalone pipelines.

---

## Variants

| Variant | Target | Output | Codename | Status |
|---------|--------|--------|----------|--------|
| `Mobuntu-SDM845/` | SDM845 phones (Poco F1, OnePlus 6/6T) | flashable `.img` | — | Active |
| `Mobuntu-L4T/` | Nintendo Switch (Tegra X1) | hekate `.7z` | Happy Mask Salesman → Tatl/Majora | Scaffold |
| `Mobuntu-PS4/` | PlayStation 4 (jailbroken, all boards) | rootfs tarball | Spider-Man | Scaffold |
| `Mobuntu-PDK/` | Ubuntu Phone PDK | TBD | — | Planned |

Releases are color-coded. See CHANGELOG.md for per-release details.

---

## Devkit

Run from the repo root. Auto-detects all variants present:

```bash
python3 devkit.py               # curses TUI
python3 devkit.py --list        # headless variant summary
python3 devkit.py --build Mobuntu-L4T   # headless build
```

---

## Mobuntu — SDM845

Multi-device Ubuntu ARM64 image builder for SDM845 phones.

### Requirements

- Ubuntu 24.04 host (**do not use 26.04** — QEMU arm64 chroot regression)
- `debos` installed
- Network access during build (firmware + kernel fetched at build time)

### Usage

```sh
# Build for Xiaomi Poco F1 (beryllium) — confirmed working baseline
./Mobuntu-SDM845/build.sh -d beryllium

# Build for OnePlus 6T (fajita)
./Mobuntu-SDM845/build.sh -d fajita

# Skip rootfs stage, reuse existing tarball
./Mobuntu-SDM845/build.sh -d beryllium -i

# Override suite
./Mobuntu-SDM845/build.sh -d fajita -s plucky

# List available devices
./Mobuntu-SDM845/build.sh -h
```

### Device Support

| Codename | Device | Suite | Status |
|----------|--------|-------|--------|
| beryllium | Xiaomi Poco F1 | plucky | Confirmed working |
| fajita | OnePlus 6T | resolute | Suite warning |
| enchilada | OnePlus 6 | — | Stubbed |

### Suite Notes

- **plucky (25.04)** — recommended for all SDM845 devices
- **resolute (26.04)** — known regressions: WiFi, Bluetooth, audio on SDM845; build.sh requires double confirmation

### Structure

```
Mobuntu/
├── build.sh                    # Entry point — loads device.conf, calls debos
├── rootfs.yaml                 # Stage 1: debootstrap + base packages
├── image.yaml                  # Stage 2: overlays, firmware, final config
├── packages/
├── overlays/
├── scripts/
│   ├── fetch-firmware.sh
│   ├── final.sh
│   ├── setup-user.sh
│   └── update-apt.sh
├── files/                      # Firmware debs + GNOME extensions
└── devices/
    ├── beryllium/
    │   ├── device.conf
    │   └── overlays/
    ├── fajita/
    │   ├── device.conf
    │   └── overlays/
    └── enchilada/
        ├── device.conf
        └── overlays/
```

---

## Mobuntu-L4T — Nintendo Switch
**Codename:** Happy Mask Salesman (dev) → Tatl / Majora (release)

See `Mobuntu-L4T/README.md` for full documentation.

Thin wrapper on upstream Switchroot L4T scripts. UIs: Phosh, Plasma Mobile, KDE, LXDE, MATE (no GNOME).
Joy-Con calibration via Hekate. Kernel/initramfs from upstream Switchroot — not built here.

```bash
sudo ./Mobuntu-L4T/build.sh -d switch
```

Output: hekate-installable `.7z`. Requires hekate >= 6.0.6.

---

## Mobuntu-PS4 — PlayStation 4
**Codename:** Spider-Man

See `Mobuntu-PS4/README.md` for full documentation.

Debian-based rootfs builder for jailbroken PS4. Kernel (strawberry 6.18.21) referenced upstream.
initramfs bundled (3 variants). Mesa 25 built via Docker. UIs: GNUstep, LXDE, LXQT.

The `-p` flag selects both initramfs variant and boot file placement:

```bash
sudo ./Mobuntu-PS4/build.sh -d ps4 -p external   # USB boot (any board)
sudo ./Mobuntu-PS4/build.sh -d ps4 -p aeolia      # Internal HDD, fat PS4
sudo ./Mobuntu-PS4/build.sh -d ps4 -p belize      # Internal HDD, PS4 Slim
```

Output: `output/boot-files/` + `output/mobuntu-ps4-*.tar.xz`
