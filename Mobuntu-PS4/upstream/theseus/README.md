# upstream/theseus/

This directory must contain the pre-built Theseus binary before building a
**Spider-Man: Doctor Octavius** image.

## How to populate

1. Download the Linux public beta from TeamUIX:
   https://github.com/MrMilenko/Theseus/releases

2. Extract and place the binary here:
   ```bash
   unzip UIX-Desktop-Linux-Public_Beta_*.zip
   cp UIX-Desktop-Linux-Public_Beta_*/theseus upstream/theseus/theseus
   chmod +x upstream/theseus/theseus
   ```

The build system checks for `upstream/theseus/theseus` before starting a
Doctor Octavius build and will error early if it's missing.

## Runtime dependencies (installed into rootfs automatically)

- libsdl2-2.0-0
- libsdl2-mixer-2.0-0
- libmpv1
- libcurl4

No build tools required — the binary is dropped straight into the rootfs.

## Reference

- Releases: https://github.com/MrMilenko/Theseus/releases
- TeamUIX:  https://github.com/OfficialTeamUIX
