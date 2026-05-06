# Mobuntu — Developer Documentation
**Last updated: May 6, 2026**

---

## Repository Layout

```
PastorCatto/Mobuntu/
├── devkit.py                  # Multi-variant TUI auto-runner — run from here
├── sync.py                    # Upstream sync engine (SDM845)
├── CHANGELOG.md
├── DOCUMENTATION.md
├── README.md
│
├── Mobuntu-SDM845/            # SDM845 build root (arkadin91/mobuntu-recipes wrapper)
│   ├── build.sh
│   ├── image.yaml
│   ├── rootfs.yaml
│   ├── devices/
│   │   ├── beryllium/
│   │   ├── fajita/
│   │   └── enchilada/
│   ├── scripts/
│   ├── files/
│   ├── overlays/
│   └── packages/
│
├── Mobuntu-L4T/               # Nintendo Switch — thin wrapper on Switchroot upstream
│   ├── build.sh               # Codename: Happy Mask Salesman → Tatl/Majora
│   ├── devices/switch/
│   │   └── device.conf
│   ├── scripts/
│   │   └── apply-overlays.sh
│   ├── overlays/
│   ├── upstream/
│   │   ├── l4t-image-buildscripts/  # Switchroot upstream scripts (bundled)
│   │   └── UPSTREAM_SOURCES.md
│   ├── docs/
│   ├── initramfs/             # Not applicable — sourced from Switchroot upstream
│   └── audit/
│       ├── CHANGELOG.md
│       └── OVERLAY_DIFF.md
│
├── Mobuntu-PS4/               # PlayStation 4 — Debian rootfs builder
│   ├── build.sh               # Codename: Spider-Man
│   ├── devices/ps4/
│   │   └── device.conf
│   ├── scripts/
│   │   ├── build-mesa.sh
│   │   ├── customize-rootfs.sh
│   │   └── stage-boot.sh
│   ├── overlays/
│   ├── initramfs/
│   │   ├── external/
│   │   ├── internal-aeolia/
│   │   └── internal-belize/
│   ├── upstream/
│   │   ├── bzImage            # Place strawberry kernel here
│   │   ├── mesa-debs/         # Optional pre-built Mesa .deb files
│   │   └── UPSTREAM_SOURCES.md
│   ├── docs/
│   └── audit/
│       └── CHANGELOG.md
│
└── Mobuntu-PDK/               # Ubuntu PDK target (planned)
```

---

## devkit.py — Multi-Variant Auto-Runner

`devkit.py` lives at the repo root and auto-detects all Mobuntu variants
present in sibling directories. It provides a split-pane curses TUI and a
headless CLI for CI/scripted builds.

### Variant Detection

devkit.py walks up from the current directory to locate the repo root (first
ancestor containing `.git` or a recognized variant folder), then scans for:

| Folder | Variant |
|--------|---------|
| `Mobuntu-SDM845/` | SDM845 phones |
| `Mobuntu-PDK/` | Ubuntu PDK |
| `Mobuntu-L4T/` | Nintendo Switch |
| `Mobuntu-PS4/` | PlayStation 4 |

Each variant is detected by the presence of both `build.env` and `build.sh`
inside its folder. The `build.env` is parsed to extract display metadata
(`UBUNTU_SUITE`, `FLAVOR`, `L4T_RELEASE`, `RELEASE_TAG`, etc.).

### Usage

```bash
python3 devkit.py               # full curses TUI
python3 devkit.py --list        # headless variant + parsed build.env summary
python3 devkit.py --build <variant_name>      # headless full pipeline
python3 devkit.py --build <variant_name> STAGES='04 05'  # headless staged build
```

### TUI Layout

```
+----------------------+-------------------------------------------+
|  [ Variants ]        |  [ Mobuntu-L4T  --  build output ]        |
|                      |                                            |
|  Mobuntu-L4T         |  [02 14:32:11] Cloning l4t-debs...        |
|    -> /path/...      |  [02 14:33:01] Staged 47 debs             |
|  Mobuntu-PS4         |  [03 14:33:02] Entering chroot            |
|    -> /path/...      |                                  [RUNNING] |
|                      |                                            |
|  [ Actions ]         |                                            |
|   b  Build (full)    |                                            |
|   s  Build stage...  |                                            |
|   c  Clean build/    |                                            |
|   e  Edit build.env  |                                            |
|   v  View build.env  |                                            |
|   k  Cancel build    |                                            |
|   r  Refresh         |                                            |
|   q  Quit            |                                            |
+----------------------+-------------------------------------------+
|  UP/DOWN: select  --  letter keys: action  --  q: quit           |
+------------------------------------------------------------------+
```

ASCII-only — no emoji. Regedit-style split: variants + actions on the left,
live build output streaming on the right.

### Keybindings

| Key | Action |
|-----|--------|
| Up / Down | Select variant |
| `b` | Full build (all stages, runs `sudo ./build.sh`) |
| `s` | Build specific stages (prompts: e.g. `04 05`) |
| `c` | Clean `build/` directory (requires typing `DELETE`) |
| `e` | Edit `build.env` in `$EDITOR` (TUI suspends, resumes after) |
| `v` | View `build.env` contents in right pane |
| `k` | Cancel running build (sends SIGTERM) |
| `r` | Refresh variant list from filesystem |
| `q` | Quit (prompts if a build is running) |

### build.env Parser

devkit.py parses shell-style `build.env` files. Handles:
- `FOO="bar"` — quoted string values
- `FOO="${FOO:-bar}"` — `${VAR:-default}` expansion (returns default)
- `export FOO=bar` — leading export keyword
- Inline comments stripped correctly

---

## Mobuntu — SDM845

### build.sh

Full multi-device build entrypoint. Requires root (re-execs via sudo automatically).

#### Usage

```bash
sudo bash Mobuntu-SDM845/build.sh -d <device> [options]

sudo bash Mobuntu-SDM845/build.sh -d beryllium
sudo bash Mobuntu-SDM845/build.sh -d beryllium -s plucky
sudo bash Mobuntu-SDM845/build.sh -d fajita -i
sudo bash Mobuntu-SDM845/build.sh -h
```

#### Flags

| Flag | Description |
|------|-------------|
| `-d <device>` | Device codename — required |
| `-s <suite>` | Ubuntu suite override |
| `-i` | Image only — skip rootfs debootstrap |
| `-h` | Print usage and list available devices |

#### Suite Gate

If the resolved suite is `resolute`, build.sh requires double confirmation:

```
Type YES to confirm resolute: YES
Type RESOLUTE to confirm again: RESOLUTE
```

#### Build Stages

```
Stage 1: rootfs    debos rootfs.yaml  (debootstrap + packages)
Stage 2: image     debos image.yaml   (overlay + firmware + kernel + seal)
```

Output: `mobuntu-<device>-<YYYYMMDD>.img` and `root-mobuntu-<device>-<YYYYMMDD>.img`

---

### sync.py

Pulls latest upstream from arkadin91/mobuntu-recipes, extracts device vars, updates fork.

#### Usage

```bash
python3 sync.py
python3 sync.py --dry-run
python3 sync.py --extract-only
python3 sync.py --fork-dir PATH
```

#### Sync Stages

```
[ 1/4 ] Fetching upstream
[ 2/4 ] Extracting device vars
[ 3/4 ] Diffing upstream
[ 4/4 ] Applying updates
```

#### Pinned Files

Never overwritten by sync:

```
build.sh
image.yaml
rootfs.yaml
devices/
scripts/fetch-firmware.sh
overlays/etc/systemd/system/hexagonrpcd.service.d/
overlays/usr/share/dbus-1/
overlays/usr/share/polkit-1/
```

Add additional paths to `Mobuntu-SDM845/.devkit-sync-lock` (one per line, `#` for comments).

---

### Device Configuration

#### device.conf Format

```bash
DEVICE_CODENAME="beryllium"
DEVICE_BRAND="xiaomi"
DEVICE_MODEL="Poco F1"
DEVICE_SOC="sdm845"

DEVICE_SUITE="plucky"

KERNEL_APT_NAME="linux-image-6.18-sdm845"
KERNEL_HEADERS_APT_NAME="linux-headers-6.18-sdm845"
KERNEL_VERSION="6.18-sdm845"
KERNEL_IMAGE_URL="https://..."
KERNEL_HEADERS_URL="https://..."

FW_DEB="linux-firmware-xiaomi-beryllium-sdm845.deb"
FW_ARCHIVE_URL="https://..."

ALSA_UCM_URL="https://repo.mobian.org/..."
DEVICE_MASKED_SERVICES="alsa-state alsa-restore"

DEVICE_DISPLAYS="tianma ebbg"
DEVICE_DEFAULT_DISPLAY="tianma"
DEVICE_DTB_TIANMA="sdm845-xiaomi-beryllium-tianma.dtb"
DEVICE_DTB_EBBG="sdm845-xiaomi-beryllium-ebbg.dtb"

DEVICE_PACKAGES="abootimg zstd hexagonrpcd libqrtr-glib0"
DEVICE_SERVICES="hexagonrpcd grow-rootfs"
HEXAGONRPCD_AFTER="multi-user.target"
```

#### Adding a New Device

1. Create `Mobuntu-SDM845/devices/<codename>/device.conf`
2. Create `Mobuntu-SDM845/devices/<codename>/overlays/`
3. Place firmware deb in `Mobuntu-SDM845/files/`
4. Press `r` in devkit to refresh
5. Build with `sudo bash Mobuntu-SDM845/build.sh -d <codename>`

---

### SDM845 Platform Notes

#### hexagonrpcd

Must use `After=multi-user.target`. **Do not use udev remoteproc gating** — causes a 60-second fastrpc thrash loop on SDM845. Drop-in lives at:

```
overlays/etc/systemd/system/hexagonrpcd.service.d/mobuntu-ordering.conf
```

```ini
[Unit]
After=multi-user.target
```

#### Audio

UCM2 maps from Mobian required. `alsa-state` and `alsa-restore` must be masked. Handled by `final.sh` via `ALSA_UCM_URL` from device.conf.

#### Suite Recommendations

| Suite | Ubuntu | SDM845 |
|-------|--------|--------|
| `plucky` | 25.04 | Recommended |
| `resolute` | 26.04 | Known WiFi/BT/audio regressions |

#### Build Host

Ubuntu 24.04 required. Ubuntu 26.04 host has a QEMU segfault regression with arm64 chroots.

---

### debos Notes

#### Variable Passthrough

Pass variables via `-t key:value` flags; expand in YAML with `{{ $varname }}`. The `environment:` block in debos `run` actions **only works with `command:`, not `script:`**. Use the overlay + command pattern:

```yaml
- action: overlay
  source: scripts
  destination: /usr/local/sbin/

- action: run
  chroot: true
  command: DEVICE="{{ $device }}" bash /usr/local/sbin/fetch-firmware.sh
```

Run debos with `--scratchsize=10G --disable-fakemachine` for WSL2 compatibility.

---

## Mobuntu-L4T — Nintendo Switch
**Codename:** Happy Mask Salesman (dev) → Tatl / Majora (release)

### Overview

Targets Nintendo Switch (Tegra X1, T210/T210B01) via the switchroot L4T stack.
Output is a hekate-installable `.7z`. Requires hekate >= 6.0.6 at runtime.

Kernel is sourced as prebuilt `.deb`s from `theofficialgman/l4t-debs` — no kernel
compilation required. The kernel itself is CTCaer's `switch-l4t-kernel-4.9`
(`linux-5.1.2`), which is NVIDIA BSP 4.9-based (not mainline — required for Tegra X1).

Build host: Ubuntu 24.04 x86-64. arm64 target — uses `qemu-user-static`. Same
host detection logic as SDM845 (24.04: `qemu-user-static`, 26.04: `qemu-user-binfmt-hwe`).

### build.env Key Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `UBUNTU_SUITE` | `noble` | Ubuntu suite (noble = 24.04) |
| `FLAVOR` | `ubuntu-unity-desktop` | Desktop flavor |
| `L4T_RELEASE` | `5.1.2` | switchroot L4T release tracking |
| `IMAGE_SIZE_MIB` | `8192` | Raw ext4 image size |
| `SPLIT_SIZE_MIB` | `4092` | hekate chunk size |
| `DISTRO_LABEL` | `SWR-MOB` | FAT label for hekate `id=` |
| `RELEASE_TAG` | `dev` | Color tag / release identifier |

### Pipeline Stages

| Stage | Script | Purpose |
|------:|--------|---------|
| 01 | `bootstrap-rootfs.sh` | arm64 debootstrap (foreign mode + QEMU) |
| 02 | `fetch-l4t-debs.sh` | Clone `theofficialgman/l4t-debs`, stage into rootfs |
| 03 | `customize-rootfs.sh` | chroot: install flavor + L4T debs, overlays, user/locale |
| 04 | `make-rawimage.sh` | Raw ext4 image via `mke2fs -d` (WSL2-safe, no loop mount) |
| 05 | `package-hekate-7z.sh` | Split to `l4t.NN` chunks, write ini + branding, 7z |

Run subset with `STAGES='04 05' ./build.sh` to repackage without rebuilding rootfs.

### SD Card Layout (inside the 7z)

```
/
├── bootloader/ini/L4T-Mobuntu.ini
└── switchroot/
    ├── install/
    │   ├── l4t.00     (4092 MiB)
    │   ├── l4t.01
    │   └── ...
    └── mobuntu/
        ├── icon.bmp
        ├── bootlogo.bmp
        └── README_CONFIG.txt
```

### Hekate Boot Entry

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

Optional additions:
```ini
emmc=1                 # enable eMMC partition support
usb3_enable=1          # max USB speeds (degrades 2.4GHz BT/WiFi signal)
rootlabel_retries=100  # USB boot: retry rootdev 100 x 200ms = 20s
```

### Install Procedure

1. Format SD with hekate `Tools -> Partition SD Card` (leave >= 8 GiB FAT32)
2. Extract `.7z` to FAT32 root (use 7-Zip on Windows — Win11 built-in is broken)
3. Hekate `Tools -> Partition SD Card -> Flash Linux`
4. Hekate `Nyx Options -> Dump Joy-Con BT` (mandatory, even on Switch Lite)
5. Boot via `More Configs -> Mobuntu L4T`

### Upstream Sources

| Component | Source | Branch |
|-----------|--------|--------|
| Kernel | `CTCaer/switch-l4t-kernel-4.9` | `linux-5.1.2` |
| GPU module | `CTCaer/switch-l4t-kernel-nvidia` | `linux-5.1.2` |
| Platform/DTS | `CTCaer/switch-l4t-platform-t210-nx` | `linux-5.1.2` |
| Distro debs | `theofficialgman/l4t-debs` | `master` |

---

## Mobuntu-PS4 — PlayStation 4
**Codename:** Spider-Man

### Overview

Targets jailbroken PS4 consoles (all board variants). Builds a minimal Debian
rootfs, bundles the correct initramfs, and stages boot files based on the `-p`
platform flag. Kernel NOT built here — place upstream bzImage before building.

**Build host:** Ubuntu 24.04 x86-64. No QEMU — host and PS4 are both amd64.
**Base:** Debian Bookworm or Trixie (Trixie recommended — Mesa 25 available natively).
**Target:** Sub-600MB RAM idle. X11 + Steam capable.

### build.sh Flags

```bash
sudo ./build.sh -d ps4 -p <variant> [-u <ui>] [-b <suite>]
```

| Flag | Description | Options | Default |
|------|-------------|---------|---------|
| `-d` | Device codename | `ps4` | required |
| `-p` | Platform/boot variant | `external` `aeolia` `belize` | required |
| `-u` | UI selection | `gnustep` `lxde` `lxqt` | from device.conf |
| `-b` | Debian suite | `bookworm` `trixie` | from device.conf |

### Platform Variants (-p)

The `-p` flag drives both initramfs selection and boot file drop location:

| `-p` | Board | initramfs used | Boot file destination |
|------|-------|----------------|-----------------------|
| `external` | Any | `initramfs/external/` | FAT32 USB root |
| `aeolia` | Fat PS4 (older) | `initramfs/internal-aeolia/` | `/data/linux/boot/` |
| `belize` | PS4 Slim/newer | `initramfs/internal-belize/` | `/data/linux/boot/` |

### device.conf Key Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DEBIAN_SUITE` | `trixie` | Debian suite |
| `DEVICE_UI` | `gnustep` | UI installed into rootfs |
| `PRESEED_USERNAME` | `` | Optional — blank = default user `mobuntu` |
| `PRESEED_HOSTNAME` | `mobuntu-ps4` | Hostname |
| `KERNEL_CODENAME` | `strawberry` | Reference codename |
| `KERNEL_VERSION` | `6.18.21` | Reference version |

### Build Pipeline

```
1. Debootstrap — minimal Debian amd64 rootfs (no QEMU)
2. Mesa build  — PS4-patched Mesa 25 via Docker (or pre-built debs)
3. Customize   — UI packages, LightDM, user setup, PS4 bootargs reference
4. Package     — rootfs tarball (xz compressed, /var/cache excluded)
5. Stage boot  — bzImage + initramfs + bootargs.txt → output/boot-files/
```

### Mesa 25

Built via `FalsePhilosopher/mesa-docker-ps4` Docker container. First build
takes significant time. Resulting debs are cached at `upstream/mesa-debs/`
for future builds (skips Docker rebuild).

Pre-built Debian debs can be dropped at `upstream/mesa-debs/*.deb` to skip
the Docker build entirely. Source: triki1's Trixie release (ps4linux.com forums).

### UI Options

| UI | Notes |
|----|-------|
| `gnustep` | Primary — minimal overhead, X11-native |
| `lxde` | Lightweight GTK desktop |
| `lxqt` | Lightweight Qt desktop |

Steam is installed on all variants.

### USB Disk Layout (external boot)

```
USB drive
├── p1: FAT32
│   ├── bzImage              ← from output/boot-files/
│   ├── initramfs.cpio.gz    ← from output/boot-files/
│   └── bootargs.txt         ← from output/boot-files/
└── p2: ext4  (label: MOBU-PS4)
    └── <extract rootfs tarball here>
```

### Boot Flow

1. Jailbreak PS4 with GoldHen
2. Launch Linux kexec payload from homebrew launcher
3. Payload reads `bzImage` + `initramfs.cpio.gz` from FAT32
4. kexec into kernel; rootfs mounts from ext4 (label: MOBU-PS4)
5. Login: `mobuntu` / `mobuntu` — forced password change on first login

### Kernel Reference

| Detail | Value |
|--------|-------|
| Codename | strawberry |
| Version | 6.18.21 |
| Repo | `rmuxnet/ps4-linux-12xx` |
| Status | Stable — recommended |
| 7.0 kernel | Exists, known boot issues — not recommended |

Kernel lineage: `fail0verflow/ps4-linux` → `codedwrench/ps4-linux`
→ `feeRnt/ps4-linux-12xx` → `rmuxnet/ps4-linux-12xx`

### initramfs Attribution

Three variants bundled in-tree. Original source: `DionKill/ps4-linux-tutorial`
(original download link dead — files archived January 2023, preserved with
source attribution in `upstream/UPSTREAM_SOURCES.md`).

### Known Gaps (v0.1.0)

- DualShock 4 input — hid-playstation kernel module likely works; not explicitly configured
- PS4 Pro (CUH-7xxx, Baikal board) — untested; may work with `external` variant
- Internal HDD boot requires external USB for initial setup
- Mesa Docker build requires internet + significant build time on first run

