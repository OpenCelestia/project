#!/bin/bash
# Link user.strip.elf, pack root.romfs + config.lfs, refresh burntool.
# Flashable binaries stay under $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/image/ only.
# Product out root keeps: build/, install/, burntool/ (no loose uImage/dtb/elf copies).
set -e

PROJ_DIR="$(cd "$(dirname "$0")" && pwd)"
if test -f "$PROJ_DIR/setup_toolchain.sh" ; then
    # shellcheck source=setup_toolchain.sh
    . "$PROJ_DIR/setup_toolchain.sh"
    _repo="${SRC_DIR:-$(cd "$PROJ_DIR/../.." && pwd)}"
    mira_setup_toolchain "$_repo" || exit 1
fi

BUILD_SRC_DIR=${1:-${BUILD_DIR}}
REL_SOC_PLATFORM_DIR=${2:-system/Sky39AV130/V1.01}
RESOURCE_INSTALL_DIR=${3:-}
SOC_PLATFORM_INSTALL_DIR=${4:-${SOC_PLATFORM_INSTALL_DIR}}

SDK_BUILD="$BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR"
IMAGE_DIR="$SDK_BUILD/image"
OUT_DIR="${OUT_ROOT:-$(dirname "$BUILD_SRC_DIR")}"

# Drop flat copies from older package.sh runs; do not touch build/, install/, burntool/.
mira_prune_flat_product_out() {
    local root="$1"
    local f
    for f in uImage zImage u-boot.bin u-boot.img u-boot-spl.bin root.romfs config.lfs user.strip.elf; do
        rm -f "$root/$f"
    done
    find "$root" -maxdepth 1 -name '*.dtb' -type f -delete 2>/dev/null || true
    rm -rf "$root/config" "$root/release" 2>/dev/null || true
}

_make_cross=()
if test -n "${MIRA_TOOLCHAIN_ROOT:-}" ; then
    _make_cross=(CROSS_PATH="$MIRA_TOOLCHAIN_ROOT")
fi

mkdir -p "$IMAGE_DIR"

make -C "$PROJ_DIR" user.strip.elf \
    "${_make_cross[@]}" \
    BUILD_DIR="$BUILD_SRC_DIR" \
    IMAGE_DIR="$IMAGE_DIR" \
    SOC_PLATFORM_DIR="${SOC_PLATFORM_DIR:-$SRC_DIR/$REL_SOC_PLATFORM_DIR}" \
    APPLICATION_INSTALL_DIR="${APPLICATION_INSTALL_DIR}" \
    HARDWARE_INSTALL_DIR="${HARDWARE_INSTALL_DIR}" \
    SYSTEM_CORE_INSTALL_DIR="${SYSTEM_CORE_INSTALL_DIR}" \
    FRAMEWORK_INSTALL_DIR="${FRAMEWORK_INSTALL_DIR}" \
    THIRD_PARTY_INSTALL_DIR="${THIRD_PARTY_INSTALL_DIR}" \
    COMPILATION_RULES="${COMPILATION_RULES:-$PROJ_DIR/system/Sky39AV130/V1.01/rules.mk}" \
    PROJECT_CONFIG_FILE="${PROJECT_CONFIG_FILE:-$PROJ_DIR/config.mk}"

if test ! -f "$IMAGE_DIR/user.strip.elf" ; then
    echo "ERROR: user.strip.elf was not produced"
    exit 1
fi

# config.lfs is 512KB. Drop unused sensor ISP blobs before mklfs.
_cfg="$SDK_BUILD/rootfs/resource/etc/config"
_isp_name="isp_sc1346_mipi_1lane_av130.conf"
_isp_board="$PROJ_DIR/system/Sky39AV130/V1.01/board/EVB_CBD_AK3918AV130/rootfs/resource/etc/config/$_isp_name"
if test -d "$_cfg" ; then
    # Celestia ipcamera: settings.json + fw_* / hal_* only (no vendor anyka_app.ini).
    rm -f "$_cfg"/anyka_app.ini
    rm -f "$_cfg"/isp_gc1084_*.conf "$_cfg"/isp_sc2331x_*.conf "$_cfg"/isp_sc2337x_*.conf \
        "$_cfg"/isp_sc2337p_*.conf "$_cfg"/isp_gc20c3_*.conf \
        "$_cfg"/isp_sc202cs_*.conf
    if test ! -f "$_cfg/$_isp_name" && test -f "$_isp_board" ; then
        cp -f "$_isp_board" "$_cfg/$_isp_name"
    fi
    if test ! -f "$_cfg/$_isp_name" ; then
        echo "ERROR: missing $_cfg/$_isp_name"
        exit 1
    fi
    sed -i \
        -e "s|isp_gc1084_mipi_1lane_av130.conf|${_isp_name}|g" \
        -e "s|isp_sc2331x_mipi_2lane_slave_av130.conf|${_isp_name}|g" \
        -e "s|isp_sc2337x_mipi_2lane_slave_max40fps_av130.conf|${_isp_name}|g" \
        -e "s|isp_sc2331x_mipi_2lane_slave_max30fps_av130.conf|${_isp_name}|g" \
        -e "s|isp_sc2331x_mipi_2lane_slave_max46fps_av130.conf|${_isp_name}|g" \
        -e "s|isp_sc2331x_mipi_2lane_slave_max46fps_quad_av130.conf|${_isp_name}|g" \
        -e "s|isp_gc20c3_mipi_2lane_av130_master_slave.conf|${_isp_name}|g" \
        -e "s|isp_sc2337p_mipi_2lane_slave_av130.conf|${_isp_name}|g" \
        "$_cfg"/*.ini
fi

# Romfs is read-only on AliOS: mount/log parents must exist in the image (mkdir on / fails).
_mira_rfmk="$SDK_BUILD/rootfs/Makefile"
if test -f "$_mira_rfmk" && ! grep -q MIRA_ROMFS_DIRS "$_mira_rfmk" ; then
    sed -i '/cp -r resource\/usr\/\* rootfs\/usr\//a\
\tmkdir -p rootfs/mnt/tfcard' "$_mira_rfmk"
    echo "# MIRA_ROMFS_DIRS" >> "$_mira_rfmk"
fi

rm -rf "$SDK_BUILD/rootfs/lfs_tmp"
if test -x "$SDK_BUILD/scripts/build_rootfs.sh" ; then
    ( cd "$SDK_BUILD" && ./scripts/build_rootfs.sh all )
fi
if test -f "$IMAGE_DIR/config.lfs" ; then
    if strings "$IMAGE_DIR/config.lfs" | grep -q 'isp_gc1084\|isp_sc2331\|isp_sc2337\|isp_gc20c3\|isp_sc202cs' ; then
        echo "ERROR: config.lfs still contains a non-sc1346 ISP file"
        exit 1
    fi
    if ! strings "$IMAGE_DIR/config.lfs" | grep -q "$_isp_name" ; then
        echo "ERROR: config.lfs missing $_isp_name"
        exit 1
    fi
fi

mira_prune_flat_product_out "$OUT_DIR"

mkdir -p "$OUT_DIR/burntool"
if test -d "$SDK_BUILD/tools/burntool" ; then
    cp -rf "$SDK_BUILD/tools/burntool"/* "$OUT_DIR/burntool/" || true
fi
# tools/burntool ships the vendor images. Overlay this build's flash files.
for f in uImage zImage u-boot.bin u-boot.img u-boot-spl.bin root.romfs config.lfs ; do
    if test -f "$IMAGE_DIR/$f" ; then
        cp -f "$IMAGE_DIR/$f" "$OUT_DIR/burntool/"
    fi
done
if ls "$IMAGE_DIR"/*.dtb >/dev/null 2>&1 ; then
    cp -f "$IMAGE_DIR"/*.dtb "$OUT_DIR/burntool/"
fi
# Board burn profile selects the kernel DTB. Applied after the SDK burntool copy.
_proj_bt="$PROJ_DIR/system/Sky39AV130/V1.01/board/EVB_CBD_AK3918AV130/tools/burntool"
if test -d "$_proj_bt" ; then
    cp -f "$_proj_bt"/* "$OUT_DIR/burntool/"
fi

echo "Mira product out: $OUT_DIR (build/, install/, burntool/ only)"
echo "Flash images: $IMAGE_DIR"
echo "  uImage zImage u-boot-spl.bin root.romfs config.lfs user.strip.elf + *.dtb"
echo "ISP config: /etc/config/$_isp_name"
