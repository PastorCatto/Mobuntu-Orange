#!/bin/bash
# Mobuntu RC15 — stage-dsp-firmware.sh
# Stages the DSP binaries and fastrpc support into the Mobuntu tree.
#
# Run this ONCE after build-fastrpc-arm64.sh completes.
# It prepares:
#   1. firmware/xiaomi-beryllium/dsp.tar.gz  — DSP binaries from MIUI dsp.img
#   2. firmware/xiaomi-beryllium/rfsa.tar.gz — rfsa/adsp skel libs from vendor partition
#   3. packages/fastrpc/                     — arm64 .deb files for fastrpc
#
# Usage:
#   ./stage-dsp-firmware.sh \
#       --dsp    /path/to/dsp.img \
#       --rfsa   /path/to/rfsa-adsp-dir \
#       --debs   /path/to/output/*.deb \
#       --tree   /path/to/mobuntu/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()   { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }

# ── Argument parsing ───────────────────────────────────────────────────────────
DSP_IMG=""
RFSA_DIR=""
DEBS_DIR=""
MOBUNTU_TREE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dsp)   DSP_IMG="$2";      shift 2 ;;
        --rfsa)  RFSA_DIR="$2";     shift 2 ;;
        --debs)  DEBS_DIR="$2";     shift 2 ;;
        --tree)  MOBUNTU_TREE="$2"; shift 2 ;;
        *) die "Unknown argument: $1" ;;
    esac
done

[ -n "${MOBUNTU_TREE}" ] || die "--tree /path/to/mobuntu is required"
[ -d "${MOBUNTU_TREE}" ] || die "Mobuntu tree not found: ${MOBUNTU_TREE}"

FW_DIR="${MOBUNTU_TREE}/firmware/xiaomi-beryllium"
PKG_DIR="${MOBUNTU_TREE}/packages/fastrpc"

mkdir -p "${FW_DIR}" "${PKG_DIR}"

# ── Stage DSP binaries from dsp.img ───────────────────────────────────────────

if [ -n "${DSP_IMG}" ]; then
    [ -f "${DSP_IMG}" ] || die "dsp.img not found: ${DSP_IMG}"
    info "Extracting DSP binaries from $(basename ${DSP_IMG})..."

    DSP_EXTRACT=$(mktemp -d)
    debugfs -R "rdump / ${DSP_EXTRACT}" "${DSP_IMG}" 2>/dev/null

    # Package into fastrpc path convention
    DSP_ROOTFS=$(mktemp -d)
    mkdir -p "${DSP_ROOTFS}/usr/share/qcom/sdm845/Xiaomi/beryllium"
    cp -r "${DSP_EXTRACT}/adsp" "${DSP_ROOTFS}/usr/share/qcom/sdm845/Xiaomi/beryllium/"
    cp -r "${DSP_EXTRACT}/cdsp" "${DSP_ROOTFS}/usr/share/qcom/sdm845/Xiaomi/beryllium/"
    cp -r "${DSP_EXTRACT}/sdsp" "${DSP_ROOTFS}/usr/share/qcom/sdm845/Xiaomi/beryllium/"

    tar -czf "${FW_DIR}/dsp.tar.gz" -C "${DSP_ROOTFS}" .
    rm -rf "${DSP_EXTRACT}" "${DSP_ROOTFS}"

    FILE_COUNT=$(tar -tzf "${FW_DIR}/dsp.tar.gz" | grep -v '/$' | wc -l)
    ok "DSP bundle: ${FW_DIR}/dsp.tar.gz (${FILE_COUNT} files)"
else
    warn "--dsp not provided, skipping DSP bundle"
    if [ -f "${FW_DIR}/dsp.tar.gz" ]; then
        ok "Existing DSP bundle found: ${FW_DIR}/dsp.tar.gz"
    fi
fi

# ── Stage rfsa/adsp skel libs ──────────────────────────────────────────────────

if [ -n "${RFSA_DIR}" ]; then
    [ -d "${RFSA_DIR}" ] || die "rfsa directory not found: ${RFSA_DIR}"
    info "Staging rfsa/adsp skel libs from ${RFSA_DIR}..."

    RFSA_ROOTFS=$(mktemp -d)
    mkdir -p "${RFSA_ROOTFS}/usr/lib/rfsa/adsp"
    cp "${RFSA_DIR}"/*.so "${RFSA_ROOTFS}/usr/lib/rfsa/adsp/" 2>/dev/null || true
    cp "${RFSA_DIR}"/*.dar "${RFSA_ROOTFS}/usr/lib/rfsa/adsp/" 2>/dev/null || true

    FILE_COUNT=$(find "${RFSA_ROOTFS}" -type f | wc -l)
    if [ "${FILE_COUNT}" -gt 0 ]; then
        tar -czf "${FW_DIR}/rfsa.tar.gz" -C "${RFSA_ROOTFS}" .
        ok "rfsa bundle: ${FW_DIR}/rfsa.tar.gz (${FILE_COUNT} files)"
    else
        warn "No files found in rfsa directory"
    fi
    rm -rf "${RFSA_ROOTFS}"
else
    warn "--rfsa not provided, skipping rfsa bundle"
fi

# ── Stage fastrpc .deb packages ───────────────────────────────────────────────

if [ -n "${DEBS_DIR}" ]; then
    [ -d "${DEBS_DIR}" ] || die "debs directory not found: ${DEBS_DIR}"
    DEB_COUNT=$(ls "${DEBS_DIR}"/*.deb 2>/dev/null | wc -l)
    [ "${DEB_COUNT}" -gt 0 ] || die "No .deb files found in ${DEBS_DIR}"

    info "Staging fastrpc .deb packages..."
    cp "${DEBS_DIR}"/*.deb "${PKG_DIR}/"
    ok "Staged ${DEB_COUNT} .deb files to ${PKG_DIR}/"
    ls -lh "${PKG_DIR}"/*.deb
else
    warn "--debs not provided, skipping fastrpc .deb staging"
fi

# ── Summary ────────────────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ok "Staging complete. Mobuntu tree updated:"
echo ""
echo "  Firmware:"
ls -lh "${FW_DIR}"/*.tar.gz 2>/dev/null | awk '{print "    "$NF, $5}' || true
echo ""
echo "  Packages:"
ls -lh "${PKG_DIR}"/*.deb 2>/dev/null | awk '{print "    "$NF, $5}' || true
echo ""
echo "Next step: update qcom.yaml to extract dsp.tar.gz and install"
echo "fastrpc-support_*.deb during the debos device build."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
