#@help: AnyCloud39AV200项目的版本配置，支持AK3918AV200N
################################################################################
#  (1)核心配置区
################################################################################


# 芯片系列定义 (AK37E, AK37D, AK39EV33X, AK3918AV100, AK3918EV300L, AK3918AV200)
CONFIG_CHIP_SERIES=AK3918AV200

#芯片类型 (KM02X, KM02D, AK3918AV200D)
CONFIG_CHIP_TYPE=KM02X

# WIFI类型配置(NO_WIFI, atbm6031, atbm6032, atbm6012b, atbm6132, atbm6031x, atbm6012bx, atbm6062u, atbm6062s, rtl8188ftv, rtl8189ftv, ssv6x5x)
CONFIG_WIFI_TYPE=atbm6032

# SENSOR类型配置
CONFIG_SENSOR_TYPE=gc5603

# gt911 FT5426G
CONFIG_SCREEN_TYPE=ft5426g

# Flash类型配置(NOR, NAND)
CONFIG_FLASH_TYPE=NOR

# U-boot板级配置选择
#EVB_CBDM_KM02X_V1.0.0
#EVB_CBDM_KM02D_V1.0.0
#EVB_CBDM_KM02X_LCD_V1.0.0
#EVB_CBDM_KM02D_LCD_V1.0.0
#EVB_CBDM_AK3918AV200D_V1.0.0
#EVB_CBDM_AK3918AV200D_V1.0.2
#SQ38_MBM_AK3918AV200D_GC5603_V1.0.0
#CA200_YTJ_AK3918AV200D_GC5603_V1.0.0
CONFIG_BOARD_SUPPORT_LCD=`grep "^CONFIG_BOARD_SUPPORT_LCD\ *[?:]\{0,1\}=\ *" $PROJECT_CONFIG_FILE | cut -d '=' -f2 | tr -d ' ' | tail -1`
CONFIG_BOARD_SUPPORT_DMIC=`grep "^CONFIG_BOARD_SUPPORT_DMIC\ *[?:]\{0,1\}=\ *" $PROJECT_CONFIG_FILE | cut -d '=' -f2 | tr -d ' ' | tail -1`

if [[ "$CONFIG_CELESTIA_FASTSYS" = "y" ]]; then
	if [[ "$CONFIG_BOARD_SUPPORT_LCD" = "y" ]]; then
		if [[ "$CONFIG_BOARD_SUPPORT_DMIC" = "y" ]]; then
			CONFIG_DTB_NAME=EVB_CBDM_KM02X_FASTSYS_LCD_DMIC_V1.0.0
		else
			CONFIG_DTB_NAME=EVB_CBDM_KM02X_FASTSYS_LCD_V1.0.0
		fi
	fi
else
	if [[ "$CONFIG_BOARD_SUPPORT_LCD" = "y" ]]; then
		if [[ "$CONFIG_BOARD_SUPPORT_DMIC" = "y" ]]; then
			CONFIG_DTB_NAME=EVB_CBDM_KM02X_LCD_DMIC_V1.0.0
		else
			CONFIG_DTB_NAME=EVB_CBDM_KM02X_LCD_V1.0.0
		fi
	else
		CONFIG_DTB_NAME=EVB_CBDM_KM02X_V1.0.0
	fi
fi


CONFIG_DTB_NAME=EVB_CBDM_KM02X_LCD_V1.0.0


###############################################################################
# 全局路径配置
###############################################################################
# Toolchain Top Path (riscv64-anyka-linux-musl-, riscv64-anyka-linux-gnu-)
CONFIG_CROSS_COMPILE=riscv64-anyka-linux-musl-

# Kernel/Driver/Uboot Source Top Path
CONFIG_OS_DIR=`pwd`//os

# Kernel/Driver/Uboot Source Top Path
CONFIG_PLATFORM_DIR=`pwd`//platform

# Installing Path, usually is 
CONFIG_TOP_DIR=`pwd`/

# Image output path
CONFIG_IMAGE_OUTPUT_DIR=`pwd`//image

# 启动模式配置(NORMAL, FAST)
if [[ "$CONFIG_CELESTIA_FASTSYS" = "y" ]]; then
	CONFIG_SYS_BOOT_MODE=FAST
else
	CONFIG_SYS_BOOT_MODE=NORMAL
fi
