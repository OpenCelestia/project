# Sky39AV130 V1.01 board overlay. Replaces the extracted SDK config.mk.
# Wi-Fi module: SDK driver libdrv_wifi_atbm6012bx.a
CONFIG_OS_NAME=alios
CONFIG_DEBUG_OPTION=y
CONFIG_FAST_LAUNCH=y
CONFIG_KERNEL_POST_LOAD=y
CONFIG_SECURE_BOOT=n
CONFIG_ROMFS_COMPRESS=y
CONFIG_USE_LZ4=y
CONFIG_USE_LZMA=n
CONFIG_USER_ELF=user.strip.elf

CONFIG_CHIP_SERIES=AK3918AV130
CONFIG_WIFI_TYPE=atbm6012bx
CONFIG_CIS_TYPE=sc1346
CONFIG_DRIVER_FILE=anyka_ak3918av130_driver_all_defconfig
CONFIG_KERNEL_FILE=anyka_ak3918av130_defconfig
CONFIG_FLASH_TYPE=NOR
# U-Boot DEVICE_TREE only: must exist under os/uboot/arch/arm/dts/ (not os/dtc).
# Kernel DTB flashed at boot: burntool uses EVB_CBDM_AK3918AV130N_V1.0.0.dtb from image/.
CONFIG_DTB_NAME=EVB_CBD_AK3918AV130_V1.0.0

CONFIG_TOOLCHAIN_PATH=/opt/arm-alios-eabi
CONFIG_KERNEL_DIR=`pwd`//os/kernel
CONFIG_UBOOT_DIR=`pwd`//os/uboot
CONFIG_TOP_DIR=`pwd`/
CONFIG_KERNEL_INC=`pwd`//platform/include/alios
CONFIG_IMAGE_OUTPUT_DIR=`pwd`//image
