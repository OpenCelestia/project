#@help: AnyCloud39AV100项目的版本配置，支持AK3918AV100N/P/X
################################################################################
#  (1)核心配置区
################################################################################
# 芯片系列定义 (AK37E, AK37D, AK39EV33X, AK3918AV100, AK3918EV300L, KM01A)
CONFIG_CHIP_SERIES=KM01A

# WIFI类型配置(NO_WIFI, atbm6031, atbm6032, atbm6031x, atbm6012bx, atbm6062u, atbm6062s, rtl8188ftv, rtl8189ftv, ssv6x5x, aic8800)
CONFIG_WIFI_TYPE=aic8800

# SENSOR类型配置
CONFIG_SENSOR_TYPE=0

# Flash类型配置(NOR, NAND)
CONFIG_FLASH_TYPE=NOR

# U-boot板级配置选择
#EVB_CBD_AK3918AV100N_V1.0.0
#EVB_CBD_AK3918AV100P_V1.0.0
#EVB_CBD_AK3918AV100X_V1.0.0
#EVB_CBD_AK3918AV100_svt_V1.0.0
#EVB_CBD_AK3918EV300L_V1.0.0
#EVB_CBD_KM01D_V1.0.0
#EVB_CBD_KM01N_V1.0.0
#SA100_EVB_MBD_KM01A_V1.0.0
#EVB_CBDM_KM01A_V1.0.0
# U-Boot (build_uboot.sh DEVICE_TREE=): only DTS under os/uboot/arch/arm/dts/ (SDK tar has EVB_CBDM_* , not ACTCAM)
CONFIG_DTB_NAME=EVB_CBDM_KM01A_V1.0.0
# Linux 运行时 DTB（build_kernel.sh install -> cloudOS.dtb）；源文件在 board/os/kernel/.../CA100V2_*_ACTCAM_*.dts
CONFIG_KERN_DTB_NAME=CA100V2_EVB_MBD_KM01W_ACTCAM_V1.0.0

###############################################################################
# 全局路径配置
###############################################################################
# Toolchain Top Path
CONFIG_CROSS_COMPILE=arm-anycloud-linux-uclibcgnueabi-

# Kernel/Driver/Uboot Source Top Path
CONFIG_OS_DIR=`pwd`//os

# Kernel/Driver/Uboot Source Top Path
CONFIG_PLATFORM_DIR=`pwd`//platform

# Installing Path, usually is 
CONFIG_TOP_DIR=`pwd`/

# Image output path
CONFIG_IMAGE_OUTPUT_DIR=`pwd`//image

###############################################################################
# 快启模式配置 no_fast;  fast_aov: fast+aov  aov: aov fast_uvc: fast+uvc
###############################################################################
CONFIG_FAST_MODE=no_fast

#快启sensor数量，1：单目， 2：双目 3: 三目 4:四目
CONFIG_FAST_SENSOR_NUM=1

#快启sensor名称(sc200ai, sc2337p, sc2337x, cv2005, os05a20, …) — 须与 hal_camera_config.ini isp_config_path 一致
CONFIG_SENSOR_NAME=os05a20

#三目下，PWM是否共用，1表示有共用，0表示独立
CONFIG_MUTIL_SENSOR_SHARE_PWM=1

#三目的共用PWM模式下拼接顺序，1表示MIPI1的SENSOR在拼接第一位，0表示MIPI0的SENSOR0在拼接第一位
CONFIG_MUTIL_SENSOR_SHARE_PWM_STITCH=0

#快启文件系统：ramfs, romfs
CONFIG_FAST_FS=romfs

#快启debug
CONFIG_FAST_DEBUG=0

#配置为all的时候表示release 的sdk支持常电和快启，配置为single的时候表示只支持其中一种。
CONFIG_RELEASE_MODE=all
