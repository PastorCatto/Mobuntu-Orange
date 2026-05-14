# Credits

This file must be carried into any fork of this project.
You may add to it. You may never remove from it.

---

## Core Team

**PastorCatto**
Project founder and primary developer. Designed and built the original 5-script build pipeline, the RC release series (RC10 through RC17), the Python curses developer toolkit (`mobuntu-developer-masterkit.py`), the firmware organisation system, the multi-device architecture, and the mobuntu-recipes integration layer. Initiated and directed the project from inception through handoff.

**arkadin91**
Co-developer and hardware specialist. Provided the `mobuntu-recipes` upstream scripts that became the project's build foundation, contributed reference images and kernel builds for SDM845, and provided critical hardware insights throughout development. The pivot to Debian-based builds and the `mobuntu-recipes-multidevice` baseline are built on their work.

---

## Projects & Communities

**Mobian**
The `linux-sdm845` and `qcom-linux` kernel packages, the SDM845 device support infrastructure, and the `mobuntu-recipes` build system that forms the upstream foundation of this project are all Mobian team work. This project would not exist without them.
https://mobian-project.org

**postmarketOS / pmaports**
Device files, `hexagonrpcd` configuration, and SDM845 mainline kernel support. The beryllium device package and associated patches informed much of the device-specific configuration used in this project.
https://postmarketos.org

**linux-msm**
Upstream `hexagonrpcd` daemon used for Qualcomm DSP remoteproc management on SDM845.
https://github.com/linux-msm/hexagonrpc

**Debian**
The foundation that Mobian and this project's Debian-based pivot builds on.
https://www.debian.org

**Ubuntu**
The original target userland for Mobuntu. Ubuntu's toolchain, repositories, and release infrastructure were used throughout the project's earlier development.
https://ubuntu.com

---

## Hardware

**Xiaomi Poco F1 (beryllium)** — Primary development and test device throughout the project.

---

## Development Notes

This project was developed with AI assistance. Claude (Anthropic) was used throughout development as a technical collaborator — for architecture decisions, debugging, code generation, and documentation.

---

*If you fork this project and add contributors, add them here.*
*Do not remove anyone from this file.*
