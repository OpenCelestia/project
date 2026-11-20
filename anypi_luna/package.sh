#!/bin/bash
# SPDX-License-Identifier: Apache-2.0

set -e

BUILD_SRC_DIR=${1:-${BUILD_DIR}}
REL_SOC_PLATFORM_DIR=${2:-${REL_SOC_PLATFORM_DIR}}
RESOURCE_INSTALL_DIR=${3:-${RESOURCE_INSTALL_DIR}}
SOC_PLATFORM_INSTALL_DIR=${4:-${SOC_PLATFORM_INSTALL_DIR}}

# Deploy main app (CONFIG_APP_MAIN_TARGET in project config.mk).
#
# Flow (package.sh cwd = platform dir):
#   1. rootfs/utils/usr/sbin/<target>  — board utils overlay staging
#   2. rootfs/rootfs/usr/sbin/<target> — nested tree for create_squashfs (packs rootfs/usr -> usr.sqsh4)
#   On device: process_utils merges utils/* -> rootfs/ ; runtime path /usr/sbin/<target> (settings.json)
read_app_main_target() {
    grep -E '^CONFIG_APP_MAIN_TARGET\s*(\?)?=' "$1" 2>/dev/null | tail -1 \
        | sed -E 's/^CONFIG_APP_MAIN_TARGET\s*(\?)?=\s*//' | tr -d ' \r'
}

runtime_config_dir_from_proj() {
    local proj_cfg="$1"
    local proj_dir board soc sdk
    proj_dir=$(cd "$(dirname "$proj_cfg")" && pwd)
    board=$(grep -E '^CONFIG_BOARD([[:space:]]+\?)?[[:space:]]*=' "$proj_cfg" 2>/dev/null | tail -1 \
        | sed -E 's/^CONFIG_BOARD([[:space:]]+\?)?[[:space:]]*=[[:space:]]*//' | tr -d '\r' | sed 's/[[:space:]]*#.*$//' | xargs)
    soc=$(grep -E '^CONFIG_SOC_PLATFORM([[:space:]]+\?)?[[:space:]]*=' "$proj_cfg" 2>/dev/null | tail -1 \
        | sed -E 's/^CONFIG_SOC_PLATFORM([[:space:]]+\?)?[[:space:]]*=[[:space:]]*//' | tr -d '\r' | sed 's/[[:space:]]*#.*$//' | xargs)
    sdk=$(grep -E '^CONFIG_SOC_SDK_VERSION([[:space:]]+\?)?[[:space:]]*=' "$proj_cfg" 2>/dev/null | tail -1 \
        | sed -E 's/^CONFIG_SOC_SDK_VERSION([[:space:]]+\?)?[[:space:]]*=[[:space:]]*//' | tr -d '\r' | sed 's/[[:space:]]*#.*$//' | xargs)
    if [ -n "$board" ] && [ -n "$soc" ] && [ -n "$sdk" ] && \
       [ -d "$proj_dir/system/$soc/$sdk/board/$board/rootfs/utils/etc/config" ]; then
        echo "$proj_dir/system/$soc/$sdk/board/$board/rootfs/utils/etc/config"
    else
        echo "$proj_dir/config"
    fi
}

mirror_app_main_for_squashfs() {
    local target="$1"
    [ -z "$target" ] && return 0
    [ ! -f "rootfs/utils/usr/sbin/$target" ] && return 0
    if [ -d "rootfs/rootfs" ]; then
        mkdir -p "rootfs/rootfs/usr/sbin"
        cp -f "rootfs/utils/usr/sbin/$target" "rootfs/rootfs/usr/sbin/$target"
        echo "Mirrored $target -> rootfs/rootfs/usr/sbin/ (squashfs pack)"
    fi
}

install_celestia_app_main() {
    local proj_cfg="$1"
    local build_src="$2"
    local entry target bin rt_src cfg_dir

    entry=$(grep -E '^CONFIG_APP_MAIN_ENTRY\s*=' "$proj_cfg" 2>/dev/null | tail -1 | sed 's/.*= *//' | tr -d ' \r')
    [ "$entry" = "y" ] || return 0

    target=$(grep -E '^CONFIG_APP_MAIN_TARGET\s*(\?)?=' "$proj_cfg" 2>/dev/null | tail -1 \
        | sed -E 's/^CONFIG_APP_MAIN_TARGET\s*(\?)?=\s*//' | tr -d ' \r')
    if [ -z "$target" ]; then
        echo "ERROR: CONFIG_APP_MAIN_TARGET not set in $proj_cfg" >&2
        exit 1
    fi

    bin="$build_src/application/app_main/$target"
    if [ ! -f "$bin" ]; then
        echo "ERROR: $bin not found. Build application first (-a)." >&2
        exit 1
    fi

    mkdir -p rootfs/utils/usr/sbin rootfs/utils/etc/config rootfs/etc/config
    cp -f "$bin" "rootfs/utils/usr/sbin/$target"
    echo "Installed $target -> rootfs/utils/usr/sbin/ (CONFIG_APP_MAIN_TARGET)"

    cfg_dir=$(runtime_config_dir_from_proj "$proj_cfg")
    rt_src="$cfg_dir/settings.json"
    if [ -f "$rt_src" ]; then
        sed -E 's|"program"[[:space:]]*:[[:space:]]*"[^"]*"|"program": "/usr/sbin/'"$target"'"|' \
            "$rt_src" > rootfs/utils/etc/config/settings.json
        cp -f rootfs/utils/etc/config/settings.json rootfs/etc/config/settings.json
        echo "Installed settings.json (program=/usr/sbin/$target)"
    fi

    mirror_app_main_for_squashfs "$target"
}

if [ -z "$BUILD_SRC_DIR" ] || [ -z "$REL_SOC_PLATFORM_DIR" ] || [ -z "$RESOURCE_INSTALL_DIR" ] || [ -z "$SOC_PLATFORM_INSTALL_DIR" ]; then
    echo "Usage: $0 <BUILD_SRC_DIR> <REL_SOC_PLATFORM_DIR> <RESOURCE_INSTALL_DIR> <SOC_PLATFORM_INSTALL_DIR>"
    echo "Received: BUILD_SRC_DIR=${BUILD_SRC_DIR:-<empty>} REL_SOC_PLATFORM_DIR=${REL_SOC_PLATFORM_DIR:-<empty>} RESOURCE_INSTALL_DIR=${RESOURCE_INSTALL_DIR:-<empty>} SOC_PLATFORM_INSTALL_DIR=${SOC_PLATFORM_INSTALL_DIR:-<empty>}"
    exit 1
fi

image_md5_write() {
    if [ "$CONFIG_CHIP_TYPE" = "KM02D" ]; then
        md5_output_file="env_av200_128MB_fastsys.img"
        md5_files=("env_md5.img"
                "dss_anyka_av200_fastsys_sc450ai.bin"
                "fastsys_uImage"
                "fw_jump_header.bin"
                "uImage"
                "initfs.img"
                "EVB_CBDM_KM02D_FASTSYS_V1.0.0.dtb")
    fi

    if [ "$CONFIG_CHIP_TYPE" = "KM02X" ]; then
        md5_output_file="env_av200_256MB_fastsys.img"
        md5_files=("env_md5.img"
                "dss_anyka_av200_fastsys_sc450ai.bin"
                "fastsys_uImage"
                "fw_jump_header.bin"
                "uImage"
                "initfs.img"
                "EVB_CBDM_KM02X_FASTSYS_V1.0.0.dtb")
    fi

    offset=0xe00
    structure_size=40
    total_size=$((structure_size * ${#md5_files[@]}))
    cd "$CONFIG_TOP_DIR/tools/burntool"

    dd if="${md5_output_file}" of=env_md5.img bs=1 count="$offset" 2>/dev/null
    dd if=/dev/zero of="${md5_output_file}" bs=1 seek="$offset" count="$total_size" 2>/dev/null

    for file in "${md5_files[@]}"; do
        file_size=$(stat -c%s "$file")
        if [ "$file" = "fastsys_uImage" ] || [ "$file" = "fw_jump_header.bin" ]; then
            file_size=$((file_size - 64))
            dd if="$file" of=temp_output.bin bs=1 skip=64 count="$file_size" conv=notrunc 2>/dev/null
            md5_value=$(md5sum temp_output.bin | awk '{print $1}')
            rm -f temp_output.bin
        else
            md5_value=$(md5sum "$file" | awk '{print $1}')
        fi
        file_size_hex=$(printf "%08x" "$file_size")
        md5_value_hex=$(echo -n "$md5_value")
        echo -n "$file_size_hex$md5_value_hex" | dd of="$md5_output_file" bs=1 seek="$offset" conv=notrunc 2>/dev/null
        offset=$((offset + structure_size))
    done

    rm -f env_md5.img
    cd - >/dev/null
}

mkdir -p "$BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR"
cd "$BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR"

# config.mk is normally copied here by build_soc_system.sh (build.sh -k). If only -p is run or the
# tree was cleaned, seed board config.mk the same way as build_soc_system.sh (project board first).
if [ ! -f ./config.mk ]; then
	SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
	SRC_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
	_top=$(grep -E '^CONFIG_BOARD([[:space:]]+\?)?[[:space:]]*=' "$SCRIPT_DIR/config.mk" 2>/dev/null | head -1 | tr -d '\r')
	CONFIG_BOARD=$(echo "$_top" | sed -E 's/^CONFIG_BOARD([[:space:]]+\?)?[[:space:]]*=[[:space:]]*//' | sed 's/[[:space:]]*#.*$//' | sed 's/[[:space:]]*$//')
	PROJ_CFG="$SCRIPT_DIR/$REL_SOC_PLATFORM_DIR/board/$CONFIG_BOARD/config.mk"
	SDK_CFG="$SRC_ROOT/$REL_SOC_PLATFORM_DIR/board/$CONFIG_BOARD/config.mk"
	if [ -f "$PROJ_CFG" ]; then
		echo "package.sh: copied board config.mk -> $(pwd)/config.mk from $PROJ_CFG"
		cp -f "$PROJ_CFG" ./config.mk
	elif [ -f "$SDK_CFG" ]; then
		echo "package.sh: copied board config.mk -> $(pwd)/config.mk from $SDK_CFG"
		cp -f "$SDK_CFG" ./config.mk
	else
		echo "ERROR: $(pwd)/config.mk missing and no board config found at"
		echo "  $PROJ_CFG"
		echo "  $SDK_CFG"
		echo "Hint: run SoC prep first: ./build.sh --product-name anypi_luna -k"
		exit 1
	fi
fi

if [ -f ./config.mk ]; then
	tr -d '\r' < ./config.mk > ./config.mk.__lf$$ && mv -f ./config.mk.__lf$$ ./config.mk
fi
source ./config.mk

mkdir -p rootfs/ko
cp -rf os/driver/* rootfs/ko/

PACKAGE_SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PATCH_JFFS2="$PACKAGE_SCRIPT_DIR/system/AnyCloud39AV100_V2/$CONFIG_SOC_SDK_VERSION/patch/rootfs/create_jffs2fs.sh"
if [ -f "$PATCH_JFFS2" ] && [ -d rootfs ]; then
	cp -f "$PATCH_JFFS2" rootfs/create_jffs2fs.sh
	chmod +x rootfs/create_jffs2fs.sh
	echo "Installed Celestia create_jffs2fs.sh from patch"
fi

./scripts/build_rootfs.sh all

# Luna SDK build_rootfs has no Celestia hook: install after rootfs prep, then re-pack FS images.
install_celestia_app_main "$PACKAGE_SCRIPT_DIR/config.mk" "$BUILD_SRC_DIR"
APP_MAIN_TARGET=$(read_app_main_target "$PACKAGE_SCRIPT_DIR/config.mk")
# Board overlay scripts are often 644 in tree; ensure +x before packing usr.jffs2.
for _shdir in rootfs/utils/etc/config rootfs/utils/usr/sbin; do
    [ -d "$_shdir" ] && find "$_shdir" -name '*.sh' -exec chmod +x {} +
done
if [ -f rootfs/create_jffs2fs.sh ]; then
    (cd rootfs && ./create_jffs2fs.sh)
fi
if [ -f rootfs/create_squashfs.sh ]; then
    (cd rootfs && APP_MAIN_TARGET="$APP_MAIN_TARGET" ./create_squashfs.sh)
fi
for _img in usr.sqsh4 root.sqsh4 data.sqsh4 usr.jffs2; do
    if [ -f "rootfs/$_img" ]; then
        cp -f "rootfs/$_img" image/
        cp -f "rootfs/$_img" tools/burntool/
        echo "Refreshed image/$_img after main app install"
    fi
done

if [[ "$CONFIG_CELESTIA_FASTSYS" = "y" ]]; then
    cp "$BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/os/ubd/spl/u-boot-spl_spi_boot.bin" image/ 2>/dev/null || true
fi

# Copy tslib runtime (compatible with both old/new install layouts)
if [[ "$CONFIG_THIRD_PARTY_TSLIB" = "y" ]]; then
    TSLIB_INSTALL_DIR=${THIRD_PARTY_INSTALL_DIR}/tslib
    if [ -d "$TSLIB_INSTALL_DIR" ]; then
        mkdir -p rootfs/rootfs/usr/bin/tslib/lib/ts
        if [ -d "$TSLIB_INSTALL_DIR/usr/lib/ts" ]; then
            cp -rf "$TSLIB_INSTALL_DIR"/usr/lib/*.so* rootfs/rootfs/usr/bin/tslib/lib/ 2>/dev/null || true
            cp -rf "$TSLIB_INSTALL_DIR"/usr/lib/ts/*.so rootfs/rootfs/usr/bin/tslib/lib/ts/ 2>/dev/null || true
        elif [ -d "$TSLIB_INSTALL_DIR/lib/ts" ]; then
            cp -rf "$TSLIB_INSTALL_DIR"/lib/*.so* rootfs/rootfs/usr/bin/tslib/lib/ 2>/dev/null || true
            cp -rf "$TSLIB_INSTALL_DIR"/lib/ts/*.so rootfs/rootfs/usr/bin/tslib/lib/ts/ 2>/dev/null || true
        fi
    fi
fi

cd image
md5sum * > burnfile.md5
cd - >/dev/null

cp -rf image/* tools/burntool

cd tools/burntool
md5sum env* >> burnfile.md5 2>/dev/null || true

if [ "$CONFIG_CHIP_SERIES" = "AK3918AV200" ] && [ "$CONFIG_SYS_BOOT_MODE" = "FAST" ]; then
    image_md5_write
fi

cd "$BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR"
PLATFORM_DIR=$(pwd)
OUT_TOP=$(cd "$(dirname "$BUILD_SRC_DIR")" && pwd)
mkdir -p "$OUT_TOP/burntool"
if [ -d "$PLATFORM_DIR/tools/burntool" ]; then
    cp -rf "$PLATFORM_DIR/tools/burntool/"* "$OUT_TOP/burntool/"
fi

cd "${ROOT:-$OUT_TOP/..}"
