# Mobuntu-L4T Changelog & Audit Log
# Codename: Happy Mask Salesman
# Release Codename (planned): Tatl / Majora
# Maintained by: Mobuntu Project & Claude (Anthropic)
# External audit: this file tracks every structural and script decision

---

## [0.1.0] — 2026-05-06 — Initial Scaffolding

### Project Definition
- Codename: Happy Mask Salesman (development), Tatl/Majora (release)
- Target hardware: Nintendo Switch (all models with Switchroot L4T support)
- Build host: Ubuntu 24.04 x86-64 (WSL2 compatible)
- Upstream: Switchroot l4t-image-buildscripts (https://github.com/switchroot)
- Philosophy: thin wrapper + overlay model — upstream script integrity preserved

### Architecture Decisions
- Mobuntu-L4T does NOT fork upstream Switchroot scripts 
- Upstream scripts are referenced via `upstream/` symlink or submodule
- Kernel and initramfs are NOT built by Mobuntu-L4T — sourced from upstream Switchroot
- Joy-Con calibration data is dumped by Hekate before booting L4T — no calibration script included
- GNOME explicitly excluded from UI options due to known L4T regressions

### UI Support Added
- Phosh (primary mobile UI) — wayland session
- Plasma Mobile (secondary mobile UI) — wayland session
- KDE Plasma (traditional desktop) — xsession
- LXDE (traditional desktop, lightweight) — xsession
- MATE (traditional desktop) — xsession
- GNOME: EXCLUDED (known issues on L4T)

### Files Added
- `build.sh` — main entry point, wraps upstream apply.sh, layers overlays
- `devices/switch/device.conf` — Switch device metadata and UI selection
- `overlays/etc/systemd/system/joycond.service` — Joy-Con daemon service
- `overlays/etc/systemd/system/mobuntu-ui-select.service` — UI selection on first boot
- `overlays/etc/udev/rules.d/99-joycon.rules` — Joy-Con device permissions
- `overlays/etc/lightdm/lightdm.conf.d/50-mobuntu.conf` — display manager config
- `overlays/usr/share/wayland-sessions/phosh.desktop` — Phosh session entry
- `overlays/usr/share/wayland-sessions/plasma-mobile.desktop` — Plasma Mobile session entry
- `scripts/apply-overlays.sh` — applies Mobuntu overlays onto upstream rootfs
- `scripts/select-ui.sh` — first-boot UI selection and preseed logic
- `upstream/UPSTREAM_SOURCES.md` — upstream kernel/initramfs reference links with checksums
- `docs/BUILD.md` — build instructions
- `docs/HEKATE_CALIBRATION.md` — Joy-Con calibration dump procedure via Hekate
- `audit/CHANGELOG.md` — this file

### Overlay Philosophy
- Session .desktop files installed by UI packages themselves — not duplicated here
- Overlays only contain: systemd drops, udev rules, display manager config, UI picker logic
- No upstream Switchroot files modified or duplicated

### Known Limitations (v0.1.0)
- GNOME excluded — known L4T regressions, revisit post-1.0
- PS4 project (Spider-Man) scaffolding tracked separately
- Audio on L4T not tested with Phosh/Plasma Mobile — may need PipeWire tuning post-scaffold

---

## Audit Trail Format
Each future entry must include:
- Version bump
- Date
- Author or session reference
- Files added/modified/removed
- Reason for each change
- Any upstream dependency changes
