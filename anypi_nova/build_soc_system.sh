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
# 创建平台目录（如 out/build/system/AnyCloud39AV200/V1.04）。在 Windows 上可能同时出现 8.3 短名（如 APXK3R~Q），为同一目录的别名，可忽略。
if test ! -d $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR ; then
   mkdir -p $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR
fi



##
cd $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR


if [[ "$CONFIG_BOARD_SUPPORT_2LANCAM" = "y" ]]; then
    sed -i "1i insmod /usr/modules/sensor_gc5603.ko SENSOR_I2C_ADDR=0x31 addr0=0x31 addr1=0x10 MIPI_LANES_SWAP=0x435A1 MIPI_LANES=2" "$OUT_PRO_BOARD_DIR/rootfs/utils/etc/config/app_02_load.sh"
fi

cp -rf $SRC_DIR/$REL_PROJECT_DIR/$REL_SOC_PLATFORM_DIR/board/$CONFIG_BOARD/config.mk $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/
#souce config
source ./config.mk
echo "uboot dtb: $CONFIG_DTB_NAME"
if test -n "$CONFIG_KERN_DTB_NAME" ; then
	echo "kernel dtb (flash): $CONFIG_KERN_DTB_NAME"
fi

#decompress and copy file to build src dir
tar_gz_dir $SRC_DIR/$REL_SOC_PLATFORM_DIR/os/linux.tar.gz $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/os

tar_gz_dir $SRC_DIR/$REL_SOC_PLATFORM_DIR/os/uboot.tar.gz $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/os

#opensbi need config.mk
if test "$CONFIG_CHIP_SERIES" = "AK3918AV200" ; then
    tar_gz_dir $SRC_DIR/$REL_SOC_PLATFORM_DIR/os/opensbi.tar.gz $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/os
fi

#copy source code to build src
copy_dir $SRC_DIR/$REL_SOC_PLATFORM_DIR/rootfs $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/rootfs
copy_dir $SRC_DIR/$REL_SOC_PLATFORM_DIR/scripts $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/scripts

copy_dir $SRC_DIR/$REL_SOC_PLATFORM_DIR/tools $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/tools
copy_dir $SRC_DIR/$REL_SOC_PLATFORM_DIR/os/driver $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/os/driver
cp -rf $SRC_DIR/$REL_SOC_PLATFORM_DIR/rules.mk $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR
mkdir -p $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/image
copy_dir $SRC_DIR/$REL_SOC_PLATFORM_DIR/platform $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/platform

#Board patch
cp -rf $SRC_DIR/$REL_PROJECT_DIR/$REL_SOC_PLATFORM_DIR/board/$CONFIG_BOARD/* $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/

if test -n "${CONFIG_KCONFIG:-}" && test "$CONFIG_KCONFIG" != "ak3918av200_fastsys_mini_defconfig"; then
    echo "cp kconfigs: " $CONFIG_KCONFIG
    cp $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/os/kernel/arch/riscv/configs/$CONFIG_KCONFIG    $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/os/kernel/arch/riscv/configs/ak3918av200_fastsys_mini_defconfig
fi

#chip patch
#$BUILD_SRC_DIR/$REL_PROJECT_DIR/$REL_SOC_PLATFORM_DIR/kernel_patch.sh $BUILD_SRC_DIR $REL_SOC_PLATFORM_DIR $REL_PROJECT_DIR $CONFIG_BOARD
cp -rf $SRC_DIR/$REL_PROJECT_DIR/$REL_SOC_PLATFORM_DIR/patch/* $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/


if test "$CONFIG_CELESTIA_FASTSYS" = "y"; then
cp -rf $SRC_DIR/$REL_PROJECT_DIR/$REL_SOC_PLATFORM_DIR/patch_fastsys/* $BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR/
fi

# Restore execute bits that may be lost by git core.autocrlf or Windows checkout.
chmod +x ./scripts/*.sh 2>/dev/null || true

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



