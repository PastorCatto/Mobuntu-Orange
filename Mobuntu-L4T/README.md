# Mobuntu-L4T
**Codename: Happy Mask Salesman**
**Release Codename (planned): Tatl / Majora**
**Version: 0.1.0**

Mobuntu-L4T is a thin wrapper around the upstream Switchroot L4T image build scripts,
adding mobile-first UI options (Phosh, Plasma Mobile) and Joy-Con support out of the gate.

## Philosophy
- Upstream script integrity is preserved — Switchroot scripts are NOT forked
- Kernel and initramfs are sourced from upstream Switchroot — NOT built here
- Overlays add UI choice and device configuration without touching upstream logic
- Every change is tracked in `audit/CHANGELOG.md` for external auditability

## Quick Start
```bash
git submodule update --init --recursive
sudo ./build.sh -d switch
```

See `docs/BUILD.md` for full instructions.

## UI Options
| UI | Type |
|----|------|
| phosh | Mobile (Wayland) — default |
| plasma-mobile | Mobile (Wayland) |
| kde | Desktop (X11) |
| lxde | Desktop (X11) |
| mate | Desktop (X11) |
| ~~gnome~~ | Excluded (known L4T regressions) |

## Structure
```
Mobuntu-L4T/
  build.sh                          ← entry point
  devices/switch/device.conf        ← device metadata + UI selection
  overlays/                         ← systemd, udev, display manager configs
  scripts/apply-overlays.sh         ← applies overlays onto upstream rootfs
  upstream/UPSTREAM_SOURCES.md      ← kernel/initramfs reference links
  docs/BUILD.md                     ← build instructions
  docs/HEKATE_CALIBRATION.md        ← Joy-Con calibration via Hekate
  audit/CHANGELOG.md                ← full audit trail
```

## Audit
All structural and script decisions are logged in `audit/CHANGELOG.md`.
This file is intended to be auditable by external parties.

## Related Projects
- Mobuntu-SDM845 (Poco F1 / beryllium) — main project
- Mobuntu-PS4 (Spider-Man) — PlayStation 4 port
