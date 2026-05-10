# upstream/theseus/

This directory must contain the Theseus source tree before building a
**Spider-Man: Doctor Octavius** image.

## How to populate

```bash
git clone https://github.com/MrMilenko/Theseus upstream/theseus
```

Or for a pinned release:

```bash
git clone --branch <tag> https://github.com/MrMilenko/Theseus upstream/theseus
```

## Why it's not pre-bundled in this repo

Theseus is an actively developed project. Check its license before
redistributing in a devkit bundle — if redistribution is permitted,
the devkit packaging script will clone and commit it automatically.

## Build requirements (installed into rootfs automatically)

- C++17
- OpenGL 3.2
- SDL2, SDL2_mixer, libmpv, libcurl

These are pulled via apt during the customize-rootfs.sh stage.

## Reference

- Repo: https://github.com/MrMilenko/Theseus
- TeamUIX: https://github.com/OfficialTeamUIX
