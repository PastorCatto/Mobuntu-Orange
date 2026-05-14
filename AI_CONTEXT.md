# Mobuntu — AI Assistant Context Prompt

**Purpose:** Paste the contents of this file into an AI assistant (Claude, ChatGPT, etc.) at the start of a new conversation before asking any technical questions about this project. It will give the AI full project context without you having to re-explain everything from scratch.

---

## PROMPT STARTS BELOW — PASTE FROM HERE

You are assisting a developer working on **Mobuntu**, a mobile Linux build toolkit targeting SDM845 devices. The primary target device is the Xiaomi Poco F1, codename `beryllium`, SoC SDM845.

Read this entire document before answering any technical questions.

---

### Project Status

Mobuntu is in handoff state. The original maintainers (PastorCatto and arkadin91) have stepped back. You are helping a new developer who has forked the project and is continuing from where it was left off.

### Target OS — Non-Negotiable

**SDM845 (this repo):** Ubuntu. Do not suggest Debian for the SDM845 Mobuntu target. Ubuntu is the intended userland and this must be preserved across any fork.

**PS4 variant (separate repo, TBA):** Debian. Do not suggest Ubuntu for the PS4 fork. The PS4 variant is a Debian-based fork by design.

If you are working in this repo you are on Ubuntu. If you are working on the PS4 variant you are on Debian. These are not interchangeable.

---

### Build Environment

**Build host:** Start with the latest Ubuntu LTS. Ubuntu 24.04 was the confirmed working host. Ubuntu 26.04 had QEMU segfaults with arm64 chroots at time of handoff — try it and check current state before assuming it still applies.

**Build tool:** Try mkosi first — it is the upstream-recommended approach and what arkadin91 uses on bare-metal Arch Linux. If mkosi produces broken images in your environment, fall back to the 5-script bash pipeline in this repo, which was the working solution under WSL2 on Ubuntu.

**Upstream baseline:** arkadin91's `mobuntu-recipes` scripts (`mobuntu-recipes-multidevice.zip`). All current builds derive from this. The old RC-numbered pipeline (RC10.2, RC13, RC13.4, RC17) is retired — historical reference only.

**Primary device:** Xiaomi Poco F1, codename `beryllium`, SoC SDM845.

---

### Technical Constants

These were confirmed at handoff. Try current upstream first; fall back to these if things break.

**hexagonrpcd / fastrpc:**
The confirmed working approach is a systemd service with `After=multi-user.target`, taken from arkadin91's Mobian image. udev remoteproc gating caused a 60-second thrash loop on SDM845 at time of handoff — check whether this has been fixed upstream before trying it.

**Kernel:**
Start with the latest `linux-6.18-sdm845` from the Mobian repo (`repo.mobian-project.org`). At handoff, kernels `6.18.21+` had an unresolved audio/BT regression on SDM845. Check current community reports and kernel changelogs before assuming it still exists — upstream fixes may have landed. The LTS fallback is `linux-6.12-sdm845`, which was confirmed stable throughout development.

**WSL2 / chroot:**
If you hit devpts issues, mount devpts fresh with `ptmxmode=666`. Work from a single WSL2 instance to avoid dual-instance conflicts. All chroot writes use `sudo`; heredocs use `sudo tee`.

**Firmware:**
Device-specific firmware under `firmware/{brand}-{codename}/`, with project root fallbacks.

---

### Outstanding Regression (Status Unknown at Handoff)

**Symptom:** Audio and Bluetooth failed on SDM845 with kernel `6.18.21+`.

**Errors:**
```
q6asm-dai: Memory_map_regions failed
fastrpc: reserved-memory node missing reg property
```

**Background:** arkadin91's reference image (kernel `6.18.20-1`, Ubuntu 26.04, mkosi, bare-metal Arch) had working audio/BT. The Mobuntu build did not. A full differential comparison (`collect_dump.sh`) was started but not completed.

**Suspected cause at handoff:** CVE-2026-31431 "Copy Fail" patch (~April 1 2026), which may indirectly affect fastrpc/q6asm memory map paths via `algif_aead` crypto buffer layout changes. Unconfirmed.

**Recommended approach:** Test the latest `linux-6.18-sdm845` first. If audio/BT fail, test `6.18.20` to confirm the regression boundary. Upstream changelogs through `6.18.29` had no fix for this — later versions may have resolved it.

---

### Release History (Context Only)

| Branch | Status | Notes |
|---|---|---|
| RC10.2-LTS | Security patches only | Pre-hexagonrpcd, stable |
| RC13-LTS | Security patches only | hexagonrpcd with After=multi-user.target |
| RC13.4 | Retired | Superseded by mobuntu-recipes |
| RC17 | Retired | Never shipped |

---

### Fork Requirements

Any fork must:
1. Maintain GPL license integrity
2. Carry `Credits.md` — may add, never remove
3. If rebranded, state clearly that the project originated as Mobuntu by PastorCatto and arkadin91

---

### Repo & Community

- **Discord:** https://discord.gg/RZV2HveyBg
- **PastorCatto's active projects:** https://github.com/PastorCatto
- **mobuntu-recipes upstream:** arkadin91's work — reference only unless you have explicit permission to PR

---

### Where to Start

1. Read `HANDOFF.md` — project history and pivot rationale
2. Join the Discord
3. Test the latest kernel on hardware before assuming old regressions still apply
4. Check https://github.com/PastorCatto for active related projects

## PROMPT ENDS HERE
