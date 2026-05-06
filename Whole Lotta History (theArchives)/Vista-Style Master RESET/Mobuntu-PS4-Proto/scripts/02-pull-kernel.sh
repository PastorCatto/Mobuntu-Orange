#!/usr/bin/env bash
# =============================================================================
# 02-pull-kernel.sh  (PS4 variant)
# Fetches bzImage + initramfs.cpio.gz for the PS4.
#
# KERNEL_MODE=prebuilt (default)
#   Downloads the release assets from ${KERNEL_REPO} on GitHub.
#   Resolves "latest" tag via GitHub API — no auth needed for public repos.
#
# KERNEL_MODE=source
#   Clones the repo and builds the kernel natively.
#   Requires a full build toolchain (build-essential, flex, bison, etc.).
#   This takes 30-60 minutes on a typical machine.
#
# Output in both cases: ${KERNEL_DIR}/bzImage + ${KERNEL_DIR}/initramfs.cpio.gz
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../build.env"

log()  { printf '[02 %s] %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '[02 WARN] %s\n' "$*" >&2; }
fail() { printf '[02 FAIL] %s\n' "$*" >&2; exit 1; }

mkdir -p "${KERNEL_DIR}"

# ---- Idempotency: skip if both artifacts already present --------------------
if [[ -f "${KERNEL_DIR}/bzImage" && -f "${KERNEL_DIR}/initramfs.cpio.gz" ]]; then
    log "Kernel artifacts already present at ${KERNEL_DIR}. Skipping."
    log "To re-fetch: rm ${KERNEL_DIR}/bzImage ${KERNEL_DIR}/initramfs.cpio.gz"
    exit 0
fi

# =============================================================================
# PREBUILT MODE
# =============================================================================
prebuilt() {
    command -v curl >/dev/null 2>&1 || apt-get install -y --no-install-recommends curl
    command -v jq   >/dev/null 2>&1 || apt-get install -y --no-install-recommends jq

    local tag="${KERNEL_TAG}"
    local api_base="https://api.github.com/repos/${KERNEL_REPO}"

    # Resolve "latest" to actual tag name.
    if [[ "$tag" == "latest" ]]; then
        log "Resolving latest release from ${KERNEL_REPO}"
        tag=$(curl -fsSL "${api_base}/releases/latest" | jq -r '.tag_name')
        [[ -n "$tag" && "$tag" != "null" ]] || fail "Could not resolve latest tag from GitHub API."
        log "Latest tag: ${tag}"
    fi

    log "Fetching release assets for ${KERNEL_REPO}@${tag}"
    local assets
    assets=$(curl -fsSL "${api_base}/releases/tags/${tag}" | jq -r '.assets[] | "\(.name) \(.browser_download_url)"')

    if [[ -z "$assets" ]]; then
        fail "No assets found for ${KERNEL_REPO}@${tag}. Check the repo/tag and try again."
    fi

    # Download whatever looks like bzImage and initramfs.
    local found_bz=0 found_initrd=0

    while IFS=' ' read -r name url; do
        case "$name" in
            bzImage*|vmlinuz*)
                log "Downloading kernel: ${name}"
                curl -fSL --progress-bar -o "${KERNEL_DIR}/bzImage" "$url"
                found_bz=1
                ;;
            initramfs*|initrd*)
                log "Downloading initramfs: ${name}"
                curl -fSL --progress-bar -o "${KERNEL_DIR}/initramfs.cpio.gz" "$url"
                found_initrd=1
                ;;
        esac
    done <<< "$assets"

    (( found_bz )) || {
        warn "No bzImage/vmlinuz asset found in release ${tag}."
        warn "Assets available:"
        echo "$assets" | awk '{print "  "$1}' >&2
        warn "Download manually to ${KERNEL_DIR}/bzImage and re-run with STAGES='03 04 05'."
    }
    (( found_initrd )) || {
        warn "No initramfs asset found. You may need to build one or supply it manually."
        warn "Expected at: ${KERNEL_DIR}/initramfs.cpio.gz"
    }
}

# =============================================================================
# SOURCE BUILD MODE
# =============================================================================
source_build() {
    log "KERNEL_MODE=source — building kernel from ${KERNEL_SOURCE_REPO}@${KERNEL_SOURCE_BRANCH}"

    local need_pkgs=(
        build-essential bc flex bison libssl-dev libelf-dev
        libncurses-dev dwarves pahole git
    )
    apt-get update -qq
    apt-get install -y --no-install-recommends "${need_pkgs[@]}"

    local src="${KERNEL_DIR}/src"
    if [[ -d "${src}/.git" ]]; then
        log "Kernel source already cloned, pulling"
        git -C "$src" fetch --depth=1 origin "${KERNEL_SOURCE_BRANCH}"
        git -C "$src" reset --hard "origin/${KERNEL_SOURCE_BRANCH}"
    else
        log "Cloning kernel source (this may take a while)"
        git clone --depth=1 --branch "${KERNEL_SOURCE_BRANCH}" \
            "${KERNEL_SOURCE_REPO}" "$src"
    fi

    # Use the in-tree .config if one exists in our kernel/ dir.
    local config_src="${PROJECT_ROOT}/kernel/ps4_defconfig"
    if [[ -f "$config_src" ]]; then
        log "Using custom defconfig: ${config_src}"
        cp "$config_src" "${src}/.config"
        make -C "$src" olddefconfig
    else
        log "No custom defconfig found at ${config_src}; using repo defconfig"
        # Most ps4-linux forks ship a defconfig — try common names.
        local found_defconfig=0
        for dc in arch/x86/configs/ps4_defconfig arch/x86/configs/x86_64_defconfig; do
            if [[ -f "${src}/${dc}" ]]; then
                make -C "$src" "$(basename "$dc")"
                found_defconfig=1
                break
            fi
        done
        (( found_defconfig )) || {
            warn "No defconfig found; falling back to make defconfig"
            make -C "$src" defconfig
        }
    fi

    local jobs
    jobs=$(nproc)
    log "Building kernel with ${jobs} jobs (ARCH=x86_64)"
    make -C "$src" -j"$jobs" ARCH=x86_64 bzImage

    cp "${src}/arch/x86/boot/bzImage" "${KERNEL_DIR}/bzImage"
    log "Built kernel -> ${KERNEL_DIR}/bzImage"
    warn "No initramfs built in source mode. Supply ${KERNEL_DIR}/initramfs.cpio.gz manually or"
    warn "build a minimal one. Stage 05 will warn and skip if missing."
}

# ---- Dispatch ---------------------------------------------------------------
case "$KERNEL_MODE" in
    prebuilt) prebuilt ;;
    source)   source_build ;;
    *)        fail "Unknown KERNEL_MODE=${KERNEL_MODE}. Use 'prebuilt' or 'source'." ;;
esac

log "Stage 02 done. Kernel artifacts:"
ls -lh "${KERNEL_DIR}/" 2>/dev/null || true
