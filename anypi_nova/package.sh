#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
pwd_dir=$(dirname $0)

BUILD_SRC_DIR=$1
REL_SOC_PLATFORM_DIR=$2
RESOURCE_INSTALL_DIR=$3
SOC_PLATFORM_INSTALL_DIR=$4


image_md5_write() {

    if [[ "$CONFIG_CELESTIA_FASTSYS" = "y" ]]; then
        if [[ -n "$CONFIG_KERN_DTB_NAME" && "$CONFIG_KERN_DTB_NAME" == *ACTION_FASTSYS* ]]; then
            CONFIG_SOC_DTB=${CONFIG_KERN_DTB_NAME}.dtb
        elif [[ "$CONFIG_BOARD_SUPPORT_LCD" = "y" ]]; then
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
        if [[ -n "$CONFIG_KERN_DTB_NAME" && "$CONFIG_KERN_DTB_NAME" == *ACTION_FASTSYS* ]]; then
            # Same name as patch_fastsys/tools/burntool + spl_fastsys burntool config
            md5_output_file="env_av200_256MB_action_camera_spinor_spl_fastsys.img"
        else
            md5_output_file="env_av200_256MB_fastsys.img"
        fi
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


cd $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR

source ./config.mk

# build_rootfs stage_tslib_to_install() needs third-party install path from top-level build.sh
export THIRD_PARTY_INSTALL_DIR

#cp -rf $(RESOURCE_INSTALL_DIR)/* rootfs/rootfs/usr/


# 将驱动KO安装到文件系统中
mkdir -p rootfs/ko
cp -rf os/driver/* rootfs/ko/

# 制作文件系统（tslib 在 build_rootfs.sh prepare_install_pack 内打入 install/）
./scripts/build_rootfs.sh all

if [[ "$CONFIG_CELESTIA_FASTSYS" = "y" ]]; then
    cp $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/os/ubd/spl/u-boot-spl_spi_boot.bin image/
fi

# 添加md5校验信息
cd image
md5sum * > burnfile.md5
cd -

# 安装镜像：install/ 必须整目录替换，否则 cp -rf 合并会留下旧 weather/icon 等文件
if [ -d tools/burntool/install ]; then
    rm -rf tools/burntool/install
    echo "[package] removed stale tools/burntool/install before copy"
fi
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
    # Same replace semantics for out/burntool/install
    if [ -d "$OUT_TOP/burntool/install" ]; then
        rm -rf "$OUT_TOP/burntool/install"
        echo "[package] removed stale $OUT_TOP/burntool/install before copy"
    fi
    cp -rf "$PLATFORM_DIR/tools/burntool/"* "$OUT_TOP/burntool/"
    echo "Copied burntool to $OUT_TOP/burntool"
else
    echo "Warning: $PLATFORM_DIR/tools/burntool not found, skip copy to out"
fi

cd ${ROOT:-$OUT_TOP/..}