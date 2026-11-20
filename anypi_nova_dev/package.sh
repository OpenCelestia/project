#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
pwd_dir=$(dirname $0)

BUILD_SRC_DIR=$1
REL_SOC_PLATFORM_DIR=$2
RESOURCE_INSTALL_DIR=$3
SOC_PLATFORM_INSTALL_DIR=$4

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

# settings.json SoT is the board rootfs config (system/$SOC/$SDK/board/$BOARD/rootfs/utils/etc/config);
# top-level project config/ is only a legacy fallback for boards that predate this layout.
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


image_md5_write() {

    if [[ "$CONFIG_CELESTIA_FASTSYS" = "y" ]]; then
        if [[ "$CONFIG_BOARD_SUPPORT_LCD" = "y" ]]; then
            if [[ "$CONFIG_BOARD_SUPPORT_DMIC" = "y" ]]; then
                CONFIG_SOC_DTB=EVB_CBDM_KM02X_FASTSYS_LCD_DMIC_V1.0.0.dtb
            else
                CONFIG_SOC_DTB=EVB_CBDM_KM02X_FASTSYS_LCD_V1.0.0.dtb
            fi
        fi
    else
        if [[ "$CONFIG_BOARD_SUPPORT_LCD" = "y" ]]; then
            if [[ "$CONFIG_BOARD_SUPPORT_DMIC" = "y" ]]; then
                CONFIG_SOC_DTB=EVB_CBDM_KM02X_LCD_DMIC_V1.0.0.dtb
            else
                CONFIG_SOC_DTB=EVB_CBDM_KM02X_LCD_V1.0.0.dtb
            fi
        else
            CONFIG_SOC_DTB=EVB_CBDM_KM02X_V1.0.0.dtb
        fi
    fi


    if [ $CONFIG_CHIP_TYPE = "KM02D" ]; then
        md5_output_file="env_av200_128MB_fastsys.img"
        md5_files=("env_md5.img"
                "dss_anyka_av200_fastsys_sc450ai.bin"
                "fastsys_uImage"
                "fw_jump_header.bin"
                "uImage"
                "initfs.img"
                $CONFIG_SOC_DTB)
    fi

    if [ $CONFIG_CHIP_TYPE = "KM02X" ]; then
        md5_output_file="env_av200_256MB_fastsys.img"
        md5_files=("env_md5.img"
                "dss_anyka_av200_fastsys_sc450ai.bin"
                "fastsys_uImage"
                "fw_jump_header.bin"
                "uImage"
                "initfs.img"
                $CONFIG_SOC_DTB)
    fi

    echo "******************************"
    echo $CONFIG_SOC_DTB

    offset=0xe00
    structure_size=40
    total_size=$((structure_size * ${#md5_files[@]}))
    cd $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/tools/burntool

    offset=$((${offset}))
    dd if=${md5_output_file} of=env_md5.img bs=1 count="$offset" 2>/dev/null
    dd if=/dev/zero of="$md5_output_file" bs=1 seek="$offset" count="$total_size" 2>/dev/null

    for file in "${md5_files[@]}"; do
        file_size=$(stat -c%s "$file")
        if [ $file = "fastsys_uImage" ] || [  $file = "fw_jump_header.bin" ]; then
            file_size=$((file_size - 64))
            dd if="$file" of=temp_output.bin bs=1 skip=64 count="$file_size" conv=notrunc 2>/dev/null
            md5_value=$(md5sum temp_output.bin | awk '{print $1}')
            rm temp_output.bin
        else
            md5_value=$(md5sum "$file" | awk '{print $1}')
        fi
        file_size_hex=$(printf "%08x" "$file_size")
        md5_value_hex=$(echo -n "$md5_value")

        echo -n "$file_size_hex$md5_value_hex" | dd of="$md5_output_file" bs=1 seek="$offset" conv=notrunc 2>/dev/null

        echo "File: $file"
        echo " Size $file_size bytes $file_size_hex"
        echo " MD5: $md5_value"
        echo " Written to offset: $offset"
        echo ""
        offset=$((offset + structure_size))
    done
    rm env_md5.img

    cd -
}


mkdir -p "$BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR"
cd "$BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR"

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
		echo "Hint: run SoC prep first: ./build.sh --product-name anypi_nova_dev -k"
		exit 1
	fi
fi

if [ -f ./config.mk ]; then
	tr -d '\r' < ./config.mk > ./config.mk.__lf$$ && mv -f ./config.mk.__lf$$ ./config.mk
fi

source ./config.mk

#cp -rf $(RESOURCE_INSTALL_DIR)/* rootfs/rootfs/usr/


# 将驱动KO安装到文件系统中
mkdir -p rootfs/ko
cp -rf os/driver/* rootfs/ko/

# 制作文件系统
export CELESTIA_BUILD_SRC="$BUILD_SRC_DIR"
export CELESTIA_PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
export APP_MAIN_TARGET=$(read_app_main_target "$CELESTIA_PROJECT_DIR/config.mk")
./scripts/build_rootfs.sh all

if [[ "$CONFIG_CELESTIA_FASTSYS" = "y" ]]; then
    cp $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/os/ubd/spl/u-boot-spl_spi_boot.bin image/
fi

# 复制 tslib 到文件系统
if [[ "$CONFIG_THIRD_PARTY_TSLIB" = "y" ]]; then
    TSLIB_INSTALL_DIR=${THIRD_PARTY_INSTALL_DIR}/tslib
    if [ -d "$TSLIB_INSTALL_DIR" ]; then
        mkdir -p rootfs/rootfs/usr/bin/tslib/lib/ts
        # 尝试两种可能的目录结构
        if [ -d "$TSLIB_INSTALL_DIR/usr/lib/ts" ]; then
            # 新结构: tslib/usr/lib/ts/
            cp -rf $TSLIB_INSTALL_DIR/usr/lib/*.so* rootfs/rootfs/usr/bin/tslib/lib/ 2>/dev/null || true
            cp -rf $TSLIB_INSTALL_DIR/usr/lib/ts/*.so rootfs/rootfs/usr/bin/tslib/lib/ts/ 2>/dev/null || true
            echo "tslib plugins copied from $TSLIB_INSTALL_DIR/usr/lib/ts to rootfs"
        elif [ -d "$TSLIB_INSTALL_DIR/lib/ts" ]; then
            # 旧结构: tslib/lib/ts/
            cp -rf $TSLIB_INSTALL_DIR/lib/*.so* rootfs/rootfs/usr/bin/tslib/lib/ 2>/dev/null || true
            cp -rf $TSLIB_INSTALL_DIR/lib/ts/*.so rootfs/rootfs/usr/bin/tslib/lib/ts/ 2>/dev/null || true
            echo "tslib plugins copied from $TSLIB_INSTALL_DIR/lib/ts to rootfs"
        else
            echo "Warning: tslib plugins dir not found in $TSLIB_INSTALL_DIR"
            ls -la $TSLIB_INSTALL_DIR 2>/dev/null || true
        fi
    else
        echo "Warning: tslib install dir not found: $TSLIB_INSTALL_DIR"
    fi
fi

# 添加md5校验信息
cd image
md5sum * > burnfile.md5
cd -

# 安装镜像
cp -rf image/* tools/burntool

# 添加env*文件的md5校验信息
cd tools/burntool
md5sum env* >> burnfile.md5

if test "$CONFIG_CHIP_SERIES" = "AK3918AV200" ; then
  if test "$CONFIG_SYS_BOOT_MODE" = "FAST" ; then
    image_md5_write
  fi
fi

# 将 burntool（烧录工具+镜像）复制一份到 out 目录，便于直接使用或发布
cd $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR
PLATFORM_DIR=$(pwd)
# OUT_TOP 使用绝对路径，避免相对路径导致复制到错误位置
OUT_TOP=$(cd "$(dirname "$BUILD_SRC_DIR")" && pwd)
mkdir -p "$OUT_TOP/burntool"
if [ -d "$PLATFORM_DIR/tools/burntool" ]; then
    cp -rf "$PLATFORM_DIR/tools/burntool/"* "$OUT_TOP/burntool/"
    echo "Copied burntool to $OUT_TOP/burntool"
else
    echo "Warning: $PLATFORM_DIR/tools/burntool not found, skip copy to out"
fi

cd ${ROOT:-$OUT_TOP/..}