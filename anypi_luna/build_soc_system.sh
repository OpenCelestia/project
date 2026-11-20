#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
pwd_dir=$(dirname $0)
SRC_DIR=$1
BUILD_SRC_DIR=$2
REL_SOC_PLATFORM_DIR=$3
REL_PROJECT_DIR=$4
CONFIG_BOARD=$5
CONFIG_PLATFORM_INSTALL=$6

copy_dir()
{
    src_dir=$1
    dest_dir=$2

    echo $src_dir copy to $dest_dir

    if test -d $src_dir ; then
        if test ! -d $dest_dir ; then
            mkdir -p $dest_dir
            cp -rf $src_dir/* $dest_dir
        fi
    fi
}


tar_gz_dir()
{
    src_file=$1
    dest_dir=$2

    echo $src_file tar to $dest_dir

    rel_tar_dir=$(tar -tf "$src_file" | head -n 1 | xargs)

    if test -f $src_file ; then
        if test ! -e $dest_dir/$rel_tar_dir ; then
            mkdir -p $dest_dir
            tar xvfz $src_file -C $dest_dir
        fi
    fi
}


##pre build
# 创建平台目录（如 out/build/system/AnyCloud39AV200/V1.03）。在 Windows 上可能同时出现 8.3 短名（如 APXK3R~Q），为同一目录的别名，可忽略。
if test ! -d $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR ; then
   mkdir -p $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR
fi



##
cd $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR

PROJ_BOARD="$SRC_DIR/$REL_PROJECT_DIR/$REL_SOC_PLATFORM_DIR/board/$CONFIG_BOARD"
SDK_BOARD="$SRC_DIR/$REL_SOC_PLATFORM_DIR/board/$CONFIG_BOARD"
PROJ_CFG="$PROJ_BOARD/config.mk"
SDK_CFG="$SDK_BOARD/config.mk"

if [[ "$CONFIG_BOARD_SUPPORT_2LANCAM" = "y" ]] && [[ -n "${OUT_PRO_BOARD_DIR:-}" ]] && [[ -f "$OUT_PRO_BOARD_DIR/rootfs/utils/etc/config/app_02_load.sh" ]]; then
    sed -i "1i insmod /usr/modules/sensor_gc5603.ko SENSOR_I2C_ADDR=0x31 addr0=0x31 addr1=0x10 MIPI_LANES_SWAP=0x435A1 MIPI_LANES=2" "$OUT_PRO_BOARD_DIR/rootfs/utils/etc/config/app_02_load.sh"
fi

if test -f "$PROJ_CFG" ; then
    cp -rf "$PROJ_CFG" $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/
elif test -f "$SDK_CFG" ; then
    echo "Note: using SDK board config.mk (no project overlay): $SDK_CFG"
    cp -rf "$SDK_CFG" $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/
else
    echo "ERROR: board config.mk not found. Tried:"
    echo "  $PROJ_CFG"
    echo "  $SDK_CFG"
    exit 1
fi
if [ -f ./config.mk ]; then
	tr -d '\r' < ./config.mk > ./config.mk.__lf$$ && mv -f ./config.mk.__lf$$ ./config.mk
fi
#souce config
source ./config.mk
echo "dtb: $CONFIG_DTB_NAME"

#decompress and copy file to build src dir
tar_gz_dir $SRC_DIR/$REL_SOC_PLATFORM_DIR/os/linux.tar.gz $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/os

tar_gz_dir $SRC_DIR/$REL_SOC_PLATFORM_DIR/os/uboot.tar.gz $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/os

#opensbi need config.mk
if test "$CONFIG_CHIP_SERIES" = "AK3918AV200" ; then
    tar_gz_dir $SRC_DIR/$REL_SOC_PLATFORM_DIR/os/opensbi.tar.gz $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/os
fi

if test "$CONFIG_CHIP_SERIES" = "KM01A" ; then
    tar_gz_dir $SRC_DIR/$REL_SOC_PLATFORM_DIR/os/driver_normal.tar.gz $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/os
fi

#copy source code to build src
copy_dir $SRC_DIR/$REL_SOC_PLATFORM_DIR/rootfs $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/rootfs
copy_dir $SRC_DIR/$REL_SOC_PLATFORM_DIR/scripts $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/scripts

copy_dir $SRC_DIR/$REL_SOC_PLATFORM_DIR/tools $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/tools
copy_dir $SRC_DIR/$REL_SOC_PLATFORM_DIR/os/driver $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/os/driver
cp -rf $SRC_DIR/$REL_SOC_PLATFORM_DIR/rules.mk $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR
mkdir -p $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/image
copy_dir $SRC_DIR/$REL_SOC_PLATFORM_DIR/platform $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/platform

# Board overlay（project 优先；否则用 SDK board 目录；均无则跳过）
if test -d "$PROJ_BOARD" ; then
    cp -rf "$PROJ_BOARD"/* $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/
elif test -d "$SDK_BOARD" ; then
    echo "Note: overlay from SDK board dir: $SDK_BOARD"
    cp -rf "$SDK_BOARD"/* $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/
fi

if test -n "${CONFIG_KCONFIG:-}" && test "$CONFIG_KCONFIG" != "ak3918av200_fastsys_mini_defconfig" ; then
    KSRC="$BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/os/kernel/arch/riscv/configs/$CONFIG_KCONFIG"
    if test -f "$KSRC" ; then
        echo "cp kconfigs: " $CONFIG_KCONFIG
        cp "$KSRC" $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/os/kernel/arch/riscv/configs/ak3918av200_fastsys_mini_defconfig
    else
        echo "Warning: CONFIG_KCONFIG=$CONFIG_KCONFIG not found at $KSRC, skip defconfig alias"
    fi
fi

# chip patch（project 下无 patch 目录时不复制）
PROJ_PATCH="$SRC_DIR/$REL_PROJECT_DIR/$REL_SOC_PLATFORM_DIR/patch"
if test -d "$PROJ_PATCH" && ls "$PROJ_PATCH"/* >/dev/null 2>&1 ; then
    cp -rf "$PROJ_PATCH"/* $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/
fi

if test "$CONFIG_CELESTIA_FASTSYS" = "y"; then
    PROJ_FAST="$SRC_DIR/$REL_PROJECT_DIR/$REL_SOC_PLATFORM_DIR/patch_fastsys"
    if test -d "$PROJ_FAST" && ls "$PROJ_FAST"/* >/dev/null 2>&1 ; then
        cp -rf "$PROJ_FAST"/* $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/
    fi
fi

if [ -f ./config.mk ]; then
	tr -d '\r' < ./config.mk > ./config.mk.__lf$$ && mv -f ./config.mk.__lf$$ ./config.mk
fi

#copy the platform to install after patch
mkdir -p $SOC_PLATFORM_INSTALL_DIR
cp -rf  $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/platform/* $SOC_PLATFORM_INSTALL_DIR

#build kernel
./scripts/build_kernel.sh all

if test $? -ne 0 ; then
	echo "Kernel build failed!"
    exit 1
fi

#build uboot
if test "$CONFIG_FLASH_TYPE" = "NOR"; then
    ./scripts/build_uboot.sh normal
elif test "$CONFIG_FLASH_TYPE" = "NAND";then
    if test $CONFIG_CHIP_SERIES = AK3918AV200; then
        ./scripts/build_uboot.sh normal
    else
        ./scripts/build_uboot.sh spl
    fi
elif test "$CONFIG_FLASH_TYPE" = "MMC"; then
    if test $CONFIG_CHIP_SERIES = AK3918AV200; then
        ./scripts/build_uboot.sh normal
    fi
fi

# 检查是否存在编译错误
if test $? -ne 0 ; then
	echo "Uboot build failed!"
    exit 1
fi

#build opensbi
if test "$CONFIG_CHIP_SERIES" = "AK3918AV200" ; then
    ./scripts/build_opensbi.sh all
    if test $? -ne 0 ; then
        echo "opensbi build failed!"
        exit 1
    fi
fi


./scripts/build_samples.sh all


if test $? -ne 0 ; then
	echo "sample build failed!"
    exit 1
fi



