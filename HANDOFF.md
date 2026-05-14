# Mobuntu — Developer Handoff

**Date:** May 2026  
**Status:** Maintenance / Handoff  
**Primary maintainers stepping back:** PastorCatto, arkadin91

---

## What This Project Was

Mobuntu was a mobile OS build toolkit targeting SDM845 devices, with the Xiaomi Poco F1 (`beryllium`) as the primary target. The original goal was to produce Ubuntu-based Linux images for SDM845 phones, delivered via a bash pipeline running on an Ubuntu 24.04 host.

The project produced two LTS maintenance branches, an active development branch, and eventually pivoted to building on top of arkadin91's `mobuntu-recipes` upstream scripts rather than a standalone pipeline.

---

## Why We Stopped

Both primary contributors got busy with life. This is not a technical failure — the project reached a natural pause point after a successful architecture pivot. The decision was also made that:

- Ubuntu as a userland target adds significant maintenance overhead for limited benefit over Debian/Mobian on the SDM845 target specifically
- The SDM845 kernel team is Mobian-based; fighting Ubuntu's toolchain on top of hardware quirks is unnecessary friction
- The PS4 and L4T variants are Debian-based and will be maintained as separate repos (TBA)
- The SDM845 target remains Ubuntu

PastorCatto's active development focus has moved on. Work currently in progress and future projects are available at **https://github.com/PastorCatto**.

---

## If You Want to Continue This Project

You are welcome to fork and continue. Before you do, read this section carefully.

### License

This project is GPL-licensed. You must maintain GPL integrity across any fork. The license is non-negotiable.

### Credits

A `Credits.md` file exists in this repo. **You must carry it into your fork.** The rule is simple:

> You may add to `Credits.md`. You may never remove from it.

This applies to every fork, every rebrand, every downstream project. If you build on this work, the people who built it before you stay in the file.

### Attribution

If you rebrand the project, you must include a clear statement in your README and documentation indicating where the project originated. Something like:

> "This project is a fork of Mobuntu, originally developed by PastorCatto and arkadin91."

### arkadin91's Involvement

arkadin91 contributed the `mobuntu-recipes` upstream scripts that form the current build foundation. Their work is foundational to any serious continuation of this project. Respect their contributions. If you reach out to them directly, understand they have stepped back from active development.

---

## What Was Built

### Release Structure (retired)

- **RC10.2-LTS** — pre-hexagonrpcd, stable baseline. Security patches only.
- **RC13-LTS** — hexagonrpcd with `After=multi-user.target`. Security patches only.
- **RC13.4** (Snapshot Rollback) — active development branch. Retired in favour of mobuntu-recipes upstream.
- **RC17** — experimental branch. Retired.

The RC-numbered pipeline work is historical reference only. Do not resume it.

### Current Architecture (mobuntu-recipes-based)

All current builds use arkadin91's `mobuntu-recipes-multidevice.zip` as the upstream baseline. The RC pipeline is not the starting point for any new work.

---

## Critical Technical Constants

These are hard-won findings. Treat them as the safe default unless you have confirmed upstream fixes.

| Constant | Detail |
|---|---|
| hexagonrpcd | systemd service with `After=multi-user.target`. udev remoteproc gating caused 60s thrash on SDM845 at time of handoff — verify before trying it. |
| Build host | Ubuntu 24.04 worked reliably. 26.04 had QEMU segfaults with arm64 chroots — check current state before using it. |
| Build tool | Try mkosi first on bare-metal — it is what arkadin91 uses. The 5-script bash pipeline is the fallback if mkosi does not work in your environment. |
| Target release | Ubuntu 25.04 (plucky) was the planned 1.0 target. 26.04 had SDM845 WiFi/BT/audio regressions at handoff — check current state. |
| Kernel | `linux-6.18-sdm845` is current. `linux-6.12-sdm845` is the confirmed stable LTS fallback. |

---

## Outstanding Regression (Unresolved at Handoff)

**Symptom:** Audio and Bluetooth failed on SDM845 with kernel `6.18.21+`. Last known-good kernel was `6.18.20`.

**Errors observed:**
```
q6asm-dai: Memory_map_regions failed
fastrpc: reserved-memory node missing reg property
```

**Suspected cause:** CVE-2026-31431 "Copy Fail" patch, landed upstream ~April 1 2026, pulled into Mobian's `qcom-linux` repo approximately April 3–8 2026. Not confirmed at time of handoff.

**Recommended first step:** Test the latest `linux-6.18-sdm845` from the current Mobian repo — upstream fixes may have landed since handoff. If audio/BT still fail, test `6.18.20` specifically to confirm the regression boundary.

A full differential comparison between arkadin91's reference image and the Mobuntu build (`collect_dump.sh`) was started but not completed.

---

## Repo & Community

- **Discord:** https://discord.gg/RZV2HveyBg
- **PastorCatto's active projects:** https://github.com/PastorCatto
- **mobuntu-recipes upstream:** arkadin91's work — treat as reference unless you have explicit permission to PR

---

## Where to Start

1. Read `AI_CONTEXT.md` — paste into your AI assistant before asking technical questions
2. Join the Discord
3. Test the latest kernel on hardware before assuming old regressions still apply
4. Check https://github.com/PastorCatto for related active projects

---

*Mobuntu was a good project worked on by good people. Build something worthy of it.*
