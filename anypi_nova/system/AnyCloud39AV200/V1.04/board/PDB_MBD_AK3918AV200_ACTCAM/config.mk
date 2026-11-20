#@help: AnyCloud39AV200 ActionCam (anypi_nova_dev), KM02X ACTION board
################################################################################
#  (1)核心配置区
#  硬件基准: km02x_action_camera_yd (SDK1.04, 已验证可下载并开机)
#    Sensor=OV8856(I2C 0x10,4lane) / LCD=ST7262 800x480 RGB / Touch=GT911 / 单MIC
#  关键: U-Boot 仍用 SDK 原版 DTB(EVB_CBDM_KM02X_V1.0.0, 已在 uboot dts Makefile 注册);
#        内核额外编译并由 burntool 烧写 EVB_CBDM_KM02X_ACTION_V1.0.1.dtb。
################################################################################

# 芯片系列定义 (AK37E, AK37D, AK39EV33X, AK3918AV100, AK3918EV300L, AK3918AV200)
CONFIG_CHIP_SERIES=AK3918AV200

# 芯片类型 (KM02X, KM02D, AK3918AV200D)
CONFIG_CHIP_TYPE=KM02X

###############################################################################
# 外设硬件清单（与 DTS / patch/rootfs/utils/usr/modules 一致，脚本通过本区变量引用）
#
#  外设      | 硬件型号              | CONFIG 变量           | 驱动 ko / 启动
#  ----------|----------------------|----------------------|---------------------------
#  Sensor    | OV8856 MIPI 4lane    | CONFIG_SENSOR_TYPE   | sensor_ov8856.ko, ov8856.sh
#  VCM/AF    | FP5510 I2C 0x0c      | (随 ov8856.sh)       | vcm_fp5510.ko (DTS fp5510@0x0c + vi vcm-ep)
#  LCD       | ST7262 800x480 RGB   | (固定 lcd.sh)        | ak_lcd.ko
#  Touch     | GT911 (I2C 0x14)     | CONFIG_SCREEN_TYPE   | 内核 goodix 中断驱动（非 ts_gt9xx.ko）
#  WiFi      | ATBM6162 SDIO (mmc2) | CONFIG_WIFI_TYPE     | ATBM6162_wifi_sdio.ko + cfg80211.ko
#  IMU       | 无 (DTS IMU=0)       | CONFIG_IMU_TYPE      | 无
#  Ethernet  | 无 (DTS eth disable) | CONFIG_ETHERNET      | 无 (不用 ak_eth.ko)
#
###############################################################################

CONFIG_SENSOR_TYPE=ov8856
CONFIG_SCREEN_TYPE=gt9xx
CONFIG_WIFI_TYPE=atbm6162
CONFIG_IMU_TYPE=NO_IMU
CONFIG_ETHERNET=NO

# Flash类型配置(NOR, NAND)
CONFIG_FLASH_TYPE=NOR

# U-Boot 编译用 DTB（SDK uboot arch/riscv/dts/Makefile 已注册；与 km02x config.mk 一致）
CONFIG_DTB_NAME=EVB_CBDM_KM02X_V1.0.0

# Linux 内核 DTB（常启 / 快启由 CONFIG_CELESTIA_FASTSYS 选择）
if [[ "$CONFIG_CELESTIA_FASTSYS" = "y" ]]; then
	CONFIG_KERN_DTB_NAME=EVB_CBDM_KM02X_ACTION_FASTSYS_V1.0.0
else
	CONFIG_KERN_DTB_NAME=EVB_CBDM_KM02X_ACTION_V1.0.1
fi

###############################################################################
# 全局路径配置
###############################################################################
# Kernel defconfig — must match a file under arch/riscv/configs/; build_soc_system.sh copies
# it to ak3918av200_fastsys_mini_defconfig before invoking build_kernel.sh.  Setting this to
# the target name itself makes the copy a no-op (correct when the SDK ships with this name).
CONFIG_KCONFIG=ak3918av200_fastsys_mini_defconfig

# Toolchain Top Path (riscv64-anyka-linux-musl-, riscv64-anyka-linux-gnu-)
CONFIG_CROSS_COMPILE=riscv64-anyka-linux-musl-

# Kernel/Driver/Uboot Source Top Path
CONFIG_OS_DIR=`pwd`//os

# Platform Source Top Path
CONFIG_PLATFORM_DIR=`pwd`//platform

# Installing Path
CONFIG_TOP_DIR=`pwd`/

# Image output path
CONFIG_IMAGE_OUTPUT_DIR=`pwd`//image

# 启动模式配置(NORMAL, FAST), 由产品级 CONFIG_CELESTIA_FASTSYS 推导
if [[ "$CONFIG_CELESTIA_FASTSYS" = "y" ]]; then
	CONFIG_SYS_BOOT_MODE=FAST
else
	CONFIG_SYS_BOOT_MODE=NORMAL
fi
