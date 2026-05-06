# Mobuntu-L4T

Switchroot L4T target for the Mobuntu project. Builds a hekate-installable
`.7z` for Nintendo Switch (Tegra X1, T210/T210B01).

This branch sits alongside `Mobuntu/` (SDM845) and `Mobuntu-PDK/` in the
repo root. The `devkit.py` auto-runner detects all three.

---

## Pipeline

Mirror of the SDM845 5-script pattern, adapted for L4T:

| Stage | Script                     | Purpose                                      |
|------:|----------------------------|----------------------------------------------|
| 01    | `bootstrap-rootfs.sh`      | debootstrap a clean Ubuntu arm64 rootfs      |
| 02    | `fetch-l4t-debs.sh`        | clone `theofficialgman/l4t-debs` and stage   |
| 03    | `customize-rootfs.sh`      | chroot install, overlays, user/locale/host   |
| 04    | `make-rawimage.sh`         | produce raw ext4 image via `mke2fs -d`       |
| 05    | `package-hekate-7z.sh`     | split into `l4t.NN`, write ini, package 7z   |

---

## Quick start

```bash
sudo apt install debootstrap qemu-user-static ubuntu-keyring \
                 e2fsprogs p7zip-full git python3
cd Mobuntu-L4T
sudo ./build.sh                       # full pipeline
sudo STAGES='04 05' ./build.sh        # only repackage from existing rootfs
```

Output lands in `output/mobuntu-l4t-noble-dev.7z` (name controlled by
`UBUNTU_SUITE` and `RELEASE_TAG` in `build.env`).

---

## Devkit auto-runner

```bash
python3 devkit.py            # full curses TUI
python3 devkit.py --list     # list variants + parsed build.env
python3 devkit.py --build Mobuntu-L4T   # headless build of a specific variant
```

The TUI is regedit-style: variant tree on the left, build output on the
right, action keys at the bottom of the left pane. ASCII-only.

---

## Upstream sources

| Component            | Source                                                       |
|----------------------|--------------------------------------------------------------|
| Kernel               | `CTCaer/switch-l4t-kernel-4.9` (branch `linux-5.1.2`)         |
| GPU module           | `CTCaer/switch-l4t-kernel-nvidia` (branch `linux-5.1.2`)      |
| Platform / DTS       | `CTCaer/switch-l4t-platform-t210-nx` (branch `linux-5.1.2`)   |
| Distro debs          | `theofficialgman/l4t-debs`                                    |
| Image build scripts  | `theofficialgman/l4t-image-buildscripts` (reference only)     |
| Bootloader           | `CTCaer/hekate` (>= 6.0.6 required at runtime)                |

We do **not** rebuild the kernel here — `02-fetch-l4t-debs.sh` pulls
prebuilt `.deb`s from `theofficialgman/l4t-debs`. Move kernel compilation
into a separate `Mobuntu-L4T-kernel/` branch later if needed.

---

## SD card layout produced by stage 05

```
/
|-- bootloader/
|   `-- ini/
|       `-- L4T-Mobuntu.ini
`-- switchroot/
    |-- install/
    |   |-- l4t.00          (4092 MiB chunk)
    |   |-- l4t.01
    |   `-- ...
    `-- mobuntu/
        |-- icon.bmp
        |-- bootlogo.bmp
        `-- README_CONFIG.txt
```

Hekate boot entry (`bootloader/ini/L4T-Mobuntu.ini`):

```ini
[Mobuntu L4T]
l4t=1
boot_prefixes=/switchroot/mobuntu/
id=SWR-MOB
uart_port=0
r2p_action=self
icon=switchroot/mobuntu/icon.bmp
logopath=switchroot/mobuntu/bootlogo.bmp
```

---

## Install procedure (user-facing)

1. Format SD with hekate `Tools -> Partition SD Card`. Leave at least 8 GiB
   for FAT32.
2. Extract this `.7z` to the root of the FAT32 partition (use 7-Zip on
   Windows; built-in extractor on Win11 is broken).
3. Hekate `Tools -> Partition SD Card -> Flash Linux`.
4. Hekate `Nyx Options -> Dump Joy-Con BT` (mandatory, even on Switch Lite —
   dumps factory calibration).
5. Boot via `More Configs -> Mobuntu L4T`.

---

## Known unknowns / TODO

- [ ] Branding: drop real `icon.bmp` / `bootlogo.bmp` into `assets/`. The
      SDM845 build's branding pipeline can probably be reused.
- [ ] Joycond integration — package may already come from `l4t-debs`, verify
      after first successful build.
- [ ] First-boot autoresize equivalent. The SDM845 first-boot service won't
      apply (no fastboot/recovery flow); hekate flashes a fixed-size raw
      image, so partition size is set at flash time.
- [ ] Differential test against switchroot's official 5.1.2 image once a
      build completes — same diff approach as the SDM845 audio root-cause
      hunt.

## Catch-and-warn philosophy

All stage scripts use the `warn` helper for missing optional inputs (no
overlay dir, no branding bmps, etc.) and only `fail` on hard prereqs
(rootfs missing for stages that need it, host tooling absent). Matches the
SDM845 pipeline behavior.
