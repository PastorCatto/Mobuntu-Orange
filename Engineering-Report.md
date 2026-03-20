

# Engineering Report: Beryllium Mainline Architecture
**Project:** Ubuntu Desktop for POCO F1 (Beryllium)
**Document Version:** 1.0 (Post-Lomiri Pivot)

This document serves as a technical deep-dive into the automated build suite. It explains the mechanics of bypassing the Android bootloader, resolving hardware race conditions, and compiling a native ARM64 Linux environment using cross-architecture chroots.

---

## 1. The Bootchain & The "Partition Hijack"

Booting a mainline Linux kernel on an Android device requires tricking the Android Bootloader (ABL). The Poco F1's ABL expects a standard Android boot image structure (Header + Kernel + Ramdisk + DTB) and expects to boot from internal eMMC/UFS partitions formatted in a highly specific way.

### 1.1 The ABL Trigger (`pmos_boot.img`)
We utilize `pmbootstrap` as our core engine to compile the mainline Snapdragon 845 kernel. Once compiled, `pmbootstrap export` wraps the `vmlinuz` kernel and the postmarketOS `initramfs` into an Android-compatible `.img` file. We flash this tiny image to the POCO F1's internal `/boot` partition. This acts as the "Hardware Trigger"—it wakes up the CPU, initializes the RAM, and hands execution over to the mainline kernel.

### 1.2 The Partition Hijack & UUID Spoofing
Instead of risking the device by re-partitioning the UFS storage layout, we hijack existing Android partitions:
* **Android `/system` (approx. 2-3GB):** Becomes our Linux `/boot` (BootFS).
* **Android `/userdata` (approx. 64GB+):** Becomes our Linux `/` (RootFS).

**The Challenge:** The postmarketOS `initramfs` is hardcoded during compilation to look for specific partition UUIDs to mount the RootFS. 
**The Solution:** Script 2 scrapes the expected `PMOS_ROOT_UUID` and `PMOS_BOOT_UUID` directly from the generated pmOS `fstab`. During Script 6 (Image Sealing), we use `mkfs.ext4 -U` to forcefully clone these exact UUIDs onto our custom Ubuntu ext4 images. When the kernel boots, it finds the matching UUIDs and mounts the Ubuntu OS, completely unaware that it isn't running postmarketOS.

---

## 2. Hardware Initialization Quirks

Getting the kernel to boot is only half the battle; getting it to talk to the hardware requires specific workarounds.

### 2.1 The `rootdelay=5` Race Condition
Mainline kernels on Beryllium suffer from a UFS initialization race condition. The kernel boots so fast that it attempts to mount the RootFS before the UFS storage controller has fully powered on, resulting in a kernel panic ("Waiting for root device").
* **The Fix:** Script 2 automatically injects `rootdelay=5` into the `deviceinfo` kernel command line. This forces a hard 5-second pause, ensuring the UFS controller is awake before the mount command is issued.

### 2.2 The DSI Display Bug (Kernels >6.14)
During development, we discovered that bleeding-edge `edge` kernels suffer from a DRM/KMS synchronization issue with the Beryllium's Display Serial Interface (DSI). This results in a completely blank screen upon boot, even though the OS is running in the background.
* **The Fix:** We enforce the use of the `v25.06` channel during `pmbootstrap init`. This locks the build to a stable kernel branch where the `msm` DRM driver correctly initializes the Tianma and EBBG display panels.

### 2.3 The Mobian Firmware Bridge
Audio routing (ALSA UCM profiles), Bluetooth, and Cellular Modems on Snapdragon devices require proprietary firmware blobs that are intricately tied to the vendor partition. Rather than guessing which blobs work, Script 3 opens an SSH bridge to a device running **Mobian**. Mobian has already stabilized these blobs for the SDM845, allowing us to surgically harvest `/usr/share/alsa/ucm2` and `/lib/firmware/postmarketos/` to ensure day-zero hardware compatibility.

---

## 3. Chroot Hardening & Architecture Crossing

To build an ARM64 (aarch64) OS on an x86_64 host PC, we utilize `debootstrap` and `qemu-user-static`. However, running complex package managers inside a virtualized jail presents severe challenges.

### 3.1 The `/proc` and `/run` Bind Mounts
Many system-level packages evaluate the host kernel to determine security features (AppArmor) or communicate with background services (DBus). If the chroot jail lacks access to these virtual filesystems, installations will fail.
* **The Fix:** Script 4 and Script 5 implement "Hardened Mounts." We utilize a loop to `mount --bind` the host's `/dev`, `/dev/pts`, `/sys`, `/proc`, and crucially `/run` directly into the `Ubuntu-Beryllium` workspace. This tricks the package manager into seeing a fully operational kernel, allowing complex hooks to compile without panicking.

---

## 4. UI Evolution & The War on Bloat

The build suite underwent a massive architectural pivot regarding how the user interface is deployed. 

### 4.1 The Lomiri Deprecation
Initially, the project attempted to deploy **Lomiri (Ubuntu Touch)**. This was ultimately deprecated due to extreme technical debt:
1. **The `click` Package Manager:** Lomiri relies on `click` to handle sandboxed apps. `click` aggressively probes the kernel for AppArmor profiles.
2. **Architecture Spoofing Failure:** Because we compile on an x86 host, `dpkg-architecture` reported the wrong CPU type to Lomiri's Python installation scripts, causing violent subprocess crashes. 
3. **The Pivot:** Rather than writing endlessly complex hotfixes to spoof architectures and mock `/proc` states, we pivoted to natively supported Linux sessions (Phosh, GNOME, KDE, XFCE).

### 4.2 Minimal Sessions & `--no-install-recommends`
Standard Ubuntu metapackages (e.g., `ubuntu-desktop`) are designed for x86 laptops. Installing them on a phone pulls in gigabytes of bloat—printer spoolers (CUPS), LibreOffice, Thunderbird, and telemetry services that choke the Snapdragon 845.
* **The Anti-Bloat Strategy:** We completely abandoned metapackages. The script now strictly targets "session" packages (e.g., `gnome-session`, `plasma-desktop`, `unity-session`).
* **The Enforcer:** Script 4 runs `apt-get install` with the `--no-install-recommends` flag. This forces `apt` to ignore all suggested bloatware, installing only the raw binaries required to render the window manager and virtual keyboard.

### 4.3 Dynamic Display Manager Routing
Because we offer multiple OS flavors, we cannot hardcode a single login screen. GNOME requires `gdm3`, KDE requires `sddm`, and XFCE/Unity require `lightdm`. 
* **The Fix:** Script 1 maps the chosen UI to its required Display Manager variable (`DM_PKG`). Script 4 uses `debconf-set-selections` to pre-seed the `apt` database, allowing the Display Manager to install silently. It then hardcodes `/etc/X11/default-display-manager` to ensure the OS boots directly to the correct lock screen without user intervention.

---

## 5. Image Serialization (Sparse vs. Raw)

The final step is converting the raw Linux folder into something the POCO F1 can actually swallow.

### 5.1 Android Fastboot Limitations
Android's `fastboot` protocol cannot flash raw disk images larger than a few gigabytes without hitting memory buffers and timing out. 
* **The Fix:** Script 6 uses the `img2simg` tool to convert our massive 8GB+ `ext4` filesystems into Android **Sparse Images**. This process compresses the empty data blocks within the filesystem. When `fastboot flash userdata` is executed, the bootloader reads the sparse header and perfectly reconstructs the 8GB filesystem on the phone's internal memory. 

For users wishing to dual-boot or test safely without wiping their phone, the script intentionally leaves the original **Raw Ext4** images intact so they can be written directly to a MicroSD card via the `dd` command.
