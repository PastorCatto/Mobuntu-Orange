#!/usr/bin/env bash
# =============================================================================
# 02-fetch-l4t-debs.sh
# Pulls theofficialgman's prebuilt L4T .debs into ${DEBS_DIR}.
#
# Strategy: clone the l4t-debs repo (it ships .debs directly in-tree) rather
# than rebuild the kernel from source. Catto's call: keep Mobuntu-L4T focused
# on the rootfs/overlay layer; defer kernel compilation to a later branch.
#
# If the repo is already cloned, fast-forward instead of re-cloning.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../build.env
source "${SCRIPT_DIR}/../build.env"

log()  { printf '[02 %s] %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '[02 WARN] %s\n' "$*" >&2; }
fail() { printf '[02 FAIL] %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null 2>&1 || { apt-get update -qq && apt-get install -y --no-install-recommends git; }

REPO_DIR="${DEBS_DIR}/l4t-debs"

if [[ -d "${REPO_DIR}/.git" ]]; then
    log "l4t-debs already cloned, fetching latest"
    git -C "${REPO_DIR}" fetch --depth=1 origin "${L4T_DEBS_BRANCH}"
    git -C "${REPO_DIR}" reset --hard "origin/${L4T_DEBS_BRANCH}"
else
    log "Cloning ${L4T_DEBS_REPO} (branch: ${L4T_DEBS_BRANCH})"
    git clone --depth=1 --branch "${L4T_DEBS_BRANCH}" "${L4T_DEBS_REPO}" "${REPO_DIR}"
fi

# ---- Inventory --------------------------------------------------------------
DEB_COUNT=$(find "${REPO_DIR}" -name '*.deb' -type f | wc -l)
log "Found ${DEB_COUNT} .deb packages in repo"

if (( DEB_COUNT == 0 )); then
    warn "No .debs found at ${REPO_DIR}. The l4t-debs repo layout may have changed."
    warn "Inspect ${REPO_DIR} manually and update this script's discovery logic."
    # catch-and-warn pattern: don't hard fail, let the user iterate
fi

# ---- Stage debs into chroot-accessible location -----------------------------
STAGE_DIR="${ROOTFS_DIR}/var/cache/mobuntu-l4t-debs"
mkdir -p "${STAGE_DIR}"
find "${REPO_DIR}" -name '*.deb' -type f -exec cp -u {} "${STAGE_DIR}/" \;

STAGED=$(find "${STAGE_DIR}" -name '*.deb' | wc -l)
log "Staged ${STAGED} .deb(s) at ${STAGE_DIR} (chroot: /var/cache/mobuntu-l4t-debs)"

log "Stage 02 done."
