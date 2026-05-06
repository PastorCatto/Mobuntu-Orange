#!/usr/bin/env bash
# =============================================================================
# 05-package-hekate-7z.sh
# Splits the raw ext4 image into 4092 MiB chunks named l4t.00, l4t.01, ...
# and packages the FAT32 layout that hekate's "Flash Linux" expects:
#
#   bootloader/
#     ini/
#       L4T-Mobuntu.ini
#   switchroot/
#     install/
#       l4t.00 l4t.01 ...
#     mobuntu/
#       icon.bmp
#       bootlogo.bmp
#       README_CONFIG.txt
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../build.env
source "${SCRIPT_DIR}/../build.env"

log()  { printf '[05 %s] %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '[05 WARN] %s\n' "$*" >&2; }
fail() { printf '[05 FAIL] %s\n' "$*" >&2; exit 1; }

command -v 7z >/dev/null 2>&1 || { apt-get update -qq && apt-get install -y --no-install-recommends p7zip-full; }
command -v split >/dev/null 2>&1 || fail "split command missing (coreutils)"

RAW_IMG="${IMAGE_DIR}/l4t.img"
[[ -f "${RAW_IMG}" ]] || fail "Raw image not found at ${RAW_IMG}. Run stage 04 first."

# ---- Stage SD layout in IMAGE_DIR/sd/ ---------------------------------------
SD_STAGE="${IMAGE_DIR}/sd"
rm -rf "${SD_STAGE}"
mkdir -p "${SD_STAGE}/bootloader/ini"
mkdir -p "${SD_STAGE}/switchroot/install"
mkdir -p "${SD_STAGE}/switchroot/${DISTRO_NAME}"

# ---- Split raw image into l4t.NN chunks -------------------------------------
log "Splitting raw image into ${SPLIT_SIZE_MIB} MiB chunks"
cd "${SD_STAGE}/switchroot/install"
split \
    --bytes="${SPLIT_SIZE_MIB}M" \
    --numeric-suffixes=0 \
    --suffix-length=2 \
    "${RAW_IMG}" \
    "l4t."
cd "${PROJECT_ROOT}"

CHUNKS=$(find "${SD_STAGE}/switchroot/install" -name 'l4t.*' | wc -l)
log "Created ${CHUNKS} chunk(s) in switchroot/install/"

# ---- Hekate ini -------------------------------------------------------------
INI_SRC="${PROJECT_ROOT}/bootloader/ini/${HEKATE_INI_NAME}"
INI_DST="${SD_STAGE}/bootloader/ini/${HEKATE_INI_NAME}"
if [[ -f "${INI_SRC}" ]]; then
    log "Copying hekate ini: ${HEKATE_INI_NAME}"
    cp "${INI_SRC}" "${INI_DST}"
else
    warn "No ini at ${INI_SRC}; generating default"
    cat > "${INI_DST}" <<EOF
[Mobuntu L4T]
l4t=1
boot_prefixes=${HEKATE_BOOT_PREFIX}
id=${DISTRO_LABEL}
uart_port=0
r2p_action=self
icon=switchroot/${DISTRO_NAME}/icon.bmp
logopath=switchroot/${DISTRO_NAME}/bootlogo.bmp
EOF
fi

# ---- Branding assets --------------------------------------------------------
for asset in icon.bmp bootlogo.bmp; do
    if [[ -f "${PROJECT_ROOT}/assets/${asset}" ]]; then
        cp "${PROJECT_ROOT}/assets/${asset}" "${SD_STAGE}/switchroot/${DISTRO_NAME}/${asset}"
    else
        warn "Missing asset ${asset} (catch-and-warn: continuing without)"
    fi
done

# ---- README inside the SD root ----------------------------------------------
cat > "${SD_STAGE}/switchroot/${DISTRO_NAME}/README_CONFIG.txt" <<EOF
Mobuntu L4T (${UBUNTU_SUITE} / ${RELEASE_TAG})
Built against switchroot L4T ${L4T_RELEASE}.

Hekate ${HEKATE_MIN_VERSION} or newer required.
Boot prefix: ${HEKATE_BOOT_PREFIX}
FAT label  : ${DISTRO_LABEL}
EOF

# ---- 7z everything ----------------------------------------------------------
OUTPUT_PATH="${OUTPUT_DIR}/${OUTPUT_7Z}"
mkdir -p "${OUTPUT_DIR}"
rm -f "${OUTPUT_PATH}"

log "Packaging ${OUTPUT_PATH}"
cd "${SD_STAGE}"
7z a -t7z -mx=5 "${OUTPUT_PATH}" . > /dev/null
cd "${PROJECT_ROOT}"

SIZE_MIB=$(du -m "${OUTPUT_PATH}" | awk '{print $1}')
log "Stage 05 done. Final 7z: ${OUTPUT_PATH} (${SIZE_MIB} MiB)"
log ""
log "To install on Switch:"
log "  1. Format SD card with hekate (Tools -> Partition SD Card)"
log "  2. Extract this 7z to FAT32 root"
log "  3. Hekate -> Tools -> Partition SD Card -> Flash Linux"
log "  4. Boot from More Configs -> Mobuntu L4T"
