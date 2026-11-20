#!/bin/bash

# 包含编译配置选项
pwd_dir=$(dirname $0)
if [ -a $pwd_dir/../config.mk ] ; then
	source $pwd_dir/../config.mk
else
	echo "cannot found config.mk, aborting ... "
	exit 1
fi

get_config_info()
{
    CHIP_SERIES=$CONFIG_CHIP_SERIES
	CROSS_COMPILE=$CONFIG_CROSS_COMPILE
	chip_series=$(echo $CHIP_SERIES | tr '[A-Z]' '[a-z]')

	opensbi_dir=$CONFIG_OS_DIR/opensbi
    opensbi_install_dir=$CONFIG_TOP_DIR/image
	kernel_build_dir=$CONFIG_OS_DIR/kbd
    uboot_build_dir=$CONFIG_OS_DIR/ubd
	ko_install_dir=$CONFIG_TOP_DIR/rootfs/ko
	driver_install_dir=$CONFIG_TOP_DIR/os/driver/external

	echo "CHIP_SERIES: $CHIP_SERIES, chip_series:$chip_series"
	echo "CROSS_COMPILE : $CROSS_COMPILE"
	echo "opensbi : $opensbi_dir"
	echo "kernel_build_dir : $kernel_build_dir"
	echo "uboot_build_dir : $uboot_build_dir"
}

build_opensbi() {
    echo ">>> >>> Ready to build Opensbi source code....................................................."

    # 检查是否存在dtb
    uboot_dtb=$opensbi_dir/platform/generic/ak3918av200.dtb
    if test ! -e $uboot_dtb ; then
        echo "The Kernel dtb $uboot_dtb is not existed!\n"
        exit 1
    fi

	# 检查是否存在Uboot编译目录
	if test ! -d $uboot_build_dir ; then
	    echo "Please compile Uboot first!"
	    exit 1
	fi

	# 检查是否存在u-boot.bin
    uboot_bin=$uboot_build_dir/u-boot.bin
    if test ! -e $uboot_bin ; then
        echo "The  Uboot $uboot_bin is not existed!\n"
        exit 1
    fi


	# 检测源码目录是否已经导入
	if test ! -d $opensbi_dir ; then
	    echo "Build opensbi failed, can't find opensbi dir!"
		exit 1
	fi

	# 切换到驱动源码目录，准备编译
	cd $opensbi_dir
    make distclean
	# 开始编译驱动
	echo "uboot_dtb="$uboot_dtb
	echo "uboot_bin="$uboot_bin
	#make KSRC=$kernel_build_dir -j$num_of_cpu_cores CROSS_COMPILE=$CROSS_COMPILE INSTALL=$driver_install_dir/external CHIP_SERIES=$CHIP_SERIES
	if test "$CONFIG_SYS_BOOT_MODE" = "FAST" ; then
		make CROSS_COMPILE=$CROSS_COMPILE PLATFORM=generic FW_PAYLOAD_PATH=$uboot_bin FW_FDT_PATH=$uboot_dtb SYS_FAST_BOOT=0
	else
		make CROSS_COMPILE=$CROSS_COMPILE PLATFORM=generic FW_PAYLOAD_PATH=$uboot_bin FW_FDT_PATH=$uboot_dtb
	fi
    fw_payload_file=`find $opensbi_dir -name fw_payload.bin`
	if test "$CONFIG_FLASH_TYPE" = "NAND" ; then
		spi_boot=spi_nand_boot.bin
	elif test "$CONFIG_FLASH_TYPE" = "NOR" ; then
		spi_boot=spi_nor_boot.bin
	elif test "$CONFIG_FLASH_TYPE" = "MMC" ; then
		spi_boot=mmc_flash_boot.bin
	fi
    if test "$CONFIG_CHIP_TYPE" = "KM02X" ; then
		ddr_bin=DDR3_256MB_PHY0_PHY1_900MHZ_P.dat
    else
		ddr_bin=DDR3_128MB_PHY1_900MHZ_P.dat
    fi

    cat $spi_boot $ddr_bin $fw_payload_file > fw_payload_spi_boot.bin
	
	# opensbi jump方式固件生成
	fw_jump_file=`find $opensbi_dir -name fw_jump.bin`
	target_size=$((256*1024))
	current_size=$(stat -c%s "$fw_jump_file")
	diff_size=$((target_size-current_size))

    if test "$CONFIG_SYS_BOOT_MODE" != "FAST" ; then
        if [ $current_size -lt $target_size ]; then
            dd if=/dev/zero bs=1 count=$diff_size >> "$fw_jump_file"
            echo "fw_jump_file padded to 256kb"
        else
            echo "fw_jump_file >=256kb"
                    exit 1
        fi
    fi

	cat $spi_boot $ddr_bin $fw_jump_file $uboot_bin > fw_jump_spi_boot.bin  

    $CONFIG_TOP_DIR/tools/uboot_tools/mkimage -A riscv -T ramdisk -C none -O opensbi -a 0x40000000 -e 0x40000000 -n "AnyCloud39AV200 opensbi" -d $fw_jump_file $opensbi_dir/fw_jump_header.bin
	
	# cat $spi_boot $fw_jump_file $uboot_bin > fw_jump_spi_boot.bin  

	# 检查编译是否出错
	if test $? -ne 0 ; then
	    exit 1
	fi

	cd -
}

install_opensbi() {
    echo "Install opensbi image fw_payload_spi_boot.bin!"
    find $opensbi_dir -name fw_payload_spi_boot.bin | xargs -i cp {} $opensbi_install_dir
    echo "Install opensbi image fw_jump_spi_boot.bin!"
    find $opensbi_dir -name fw_jump_spi_boot.bin | xargs -i cp {} $opensbi_install_dir
    find $opensbi_dir -name fw_jump_header.bin | xargs -i cp {} $opensbi_install_dir
}

clean_opensbi() {
	cd $opensbi_dir
	# 先进行编译前的清理
	make clean CROSS_COMPILE=$CROSS_COMPILE

	cd -
}

get_config_info

case "$1" in
	all)
		build_opensbi
		install_opensbi
		;;
	clean)
		clean_opensbi
		;;
	*)
		echo "Usage:"
		echo " $0 all	: build opensbi"
		echo " $0 clean : clean opensbi"
		;;
esac
