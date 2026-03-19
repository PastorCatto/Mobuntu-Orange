# Ubuntu Desktop for POCO F1 (Beryllium)

A fully automated, "paste-and-go" script suite to build and install a custom 
Ubuntu Desktop (Lomiri, XFCE, or GNOME) directly onto your POCO F1.

---

[ RESOURCES ]
* Progress Archive: https://github.com/PastorCatto/Ubuntu-PocoF1-Archive
* Technical Details: See Engineering-Report.md for a deep dive into the 
  partition hijack and hardware logic.

---

[ PHILOSOPHY, AI, AND CREDITS ]

* Transparency: The goal is for YOU to know exactly what is on your device. 
  Because you build this from scratch on your own machine, you can see the 
  logs and verify the process.
* The Code: These scripts were AI-generated using Gemini Pro (Feb-Mar 2026). 
  I will NOT use AI for executables or anything beyond human-readable bash 
  scripts to ensure there are no hidden exploits or backdoors. If this 
  project scales, I will move to a human-first development model.
* The Engine: pmbootstrap is used to generate the kernel and boot images. 
  Massive shoutout to the postmarketOS team for their debugging tools!
* The Blobs: Firmware blobs are sourced from Qualcomm and Debian.
* License: GPL 2.0 (same as the Linux Kernel).

---

[ SYSTEM REQUIREMENTS ]

* Host OS: Ubuntu 24.04.1 LTS (WSL or native).
* Storage: 50GB+ (Building 6 large images requires significant overhead).
* Firmware: You MUST have Mobian installed on your device to harvest blobs 
  via SSH, OR download the pre-provided firmware archive from this repo.

---

[ INSTALLATION GUIDE ]

STEP 1: Preparation
1. Install WSL or an Ubuntu 24.04+ container.
2. Prepare Firmware:
   * Option A: Use provided firmware files.
   * Option B: Flash Mobian Weekly SDM845 to your device. Enable SSH:
     'sudo apt update && sudo apt install openssh-server'
     (Mobian default password: 1234)
3. Copy the AIO script from this repo and paste it into your terminal.

STEP 2: Build Process and Quirks
The script will auto-run. Follow prompts until Script 2. Note these quirks:
* THE BLANK SCREEN BUG: For kernels 6.14+, the display often fails to initialize.
  When pmbootstrap asks for a channel, type: v25.06
  (This uses a stable kernel that fixes the display initialization).
* DUMMY PASSWORD: pmbootstrap will ask for a user password during 'install'. 
  Enter anything; it is a ghost requirement we don't actually use.

STEP 3: Script Execution Order
Run the scripts in this specific sequence to build your OS:

  +-- deploy_workspace.sh (Run once to spawn the suite)
  |
  +-- 1_preflight.sh (Host dependencies and config)
  |
  +-- 2_pmos_setup.sh (Kernel build and UUID cloning)
  |
  +-- 3_firmware_fetcher.sh (Harvest audio/modem blobs via SSH)
  |
  +-- 4_the_transplant.sh (Ubuntu RootFS build and UI install)
  |
  +-- 8_lomiri_hotfix.sh (Required ONLY if using Lomiri/Ubuntu Touch)
  |
  +-- 5_enter_chroot.sh (Optional manual tweaks)
  |
  +-- 6_seal_rootfs.sh (Final image packing)
  |
  +-- 7_kernel_menuconfig.sh (Optional kernel hacking)

[ GENERATED OUTPUT IMAGES ]
========================================================================

pmos_boot.img ---------------------------> Target: Internal /boot
                                           (Mandatory ABL Trigger)

[ Raw Ext4 Images ] -> For MicroSD Card Deployment
|
|--- ubuntu_beryllium_boot.img ----------> Target: SD Partition 1
|
'--- ubuntu_beryllium_root.img ----------> Target: SD Partition 2


[ Sparse Images ] -> For Internal Hijack (Fastboot)
|
|--- ubuntu_beryllium_boot_sparse.img ---> Target: Internal /system
|
'--- ubuntu_beryllium_root_sparse.img ---> Target: Internal /userdata

========================================================================

[ FLASHING INSTRUCTIONS ]

1. Reboot POCO F1 into Fastboot mode.
2. Run the following commands:

   fastboot flash boot pmos_boot.img
   fastboot flash system ubuntu_beryllium_boot_sparse.img
   fastboot flash userdata ubuntu_beryllium_root_sparse.img
   fastboot reboot

CRITICAL: After 'fastboot reboot', do NOT touch the power button. The 
initial boot will take a while. Just wait!

Boom! You now have Ubuntu running on your Beryllium.
