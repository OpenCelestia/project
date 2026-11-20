#!/bin/sh
# Core runtime on /usr; SD install holds other apps + model.
export TSLIB_CONFFILE=/etc/config/ts.rgb.conf
export TSLIB_CALIBFILE=/etc/config/ts_calibrate.rgb.conf
export TSLIB_PLUGINDIR=/usr/lib/ts
# GT911 由内建 goodix 驱动接管（中断式）；节点号会漂移，仅兜底 event0
[ -n "$TSLIB_TSDEVICE" ] || export TSLIB_TSDEVICE=/dev/input/event0
export TSLIB_CONSOLEDEVICE=none
# POSIX: CST-8 = China Standard Time (UTC+8). Used by log_info / OSD / UI localtime.
export TZ="${TZ:-CST-8}"

rm -f /etc/config/ak_font_16.bin

export LD_LIBRARY_PATH=/usr/lib:/lib:/mnt/install/apps/volc_engine/lib:/mnt/install/lib:/mnt/install:$LD_LIBRARY_PATH
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/mnt/install:$PATH

# 调试通道：尽早启动 telnetd（root 空密码，仅开发调试用，量产固件需移除）
pidof telnetd >/dev/null 2>&1 || telnetd

insmod /lib/modules/5.10.111/kernel/drivers/base/firmware_loader/firmware_class.ko path=/mnt/install/model/

modprobe mmc_core 2>/dev/null
modprobe mmc_block 2>/dev/null
if ! lsmod | grep -q ak_mci; then
	insmod /usr/modules/ak_mci.ko
fi

if [ -x /usr/sbin/wifi_driver.sh ]; then
	/usr/sbin/wifi_driver.sh sta &
else
	/usr/sbin/tf_card.sh
fi

/usr/sbin/lcd.sh

echo 3 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio3/direction
echo 1 > /sys/class/gpio/gpio3/value

/usr/sbin/ov8856.sh
insmod /usr/modules/ak_venc_adapter.ko
insmod /usr/modules/ak_venc_bridge.ko

insmod /usr/modules/ak_ipu.ko
# 触摸为内核内建 goodix 驱动（中断式），无需 insmod
insmod /usr/modules/ak_pcm.ko
insmod /usr/modules/ak_npu.ko

if [ -x /usr/sbin/storage_mode_switch.sh ]; then
	/usr/sbin/storage_mode_switch.sh boot
elif [ -x /usr/sbin/usb_udc.sh ]; then
	/usr/sbin/usb_udc.sh uninstall
	if [ -f /usr/sbin/mount_install.sh ]; then
		. /usr/sbin/mount_install.sh mount
	fi
fi

if [ -d /sys/module/firmware_class/parameters/path ]; then
	echo -n "/mnt/install/model/" > /sys/module/firmware_class/parameters/path
fi

uptime
echo "finish to init"
# ---- GT911 唤醒 + 触摸节点解析（NOR 自足版，空 SD NAND 板也能正常触摸）----
# GT911 上电因 INT 高复位进入睡眠态：配置区可读（probe 日志正常）但永不扫描、
# 永不发中断，必须在桌面启动前用 INT(GPIO10) 高脉冲 200ms 唤醒。
# 该逻辑必须在 NOR 内的 app_01_start.sh 自带，不能只放在 SD 卡脚本里。
G911_GPIO=10
[ -e /sys/class/gpio/gpio$G911_GPIO ] || echo $G911_GPIO > /sys/class/gpio/export 2>/dev/null
echo out > /sys/class/gpio/gpio$G911_GPIO/direction 2>/dev/null
echo 1 > /sys/class/gpio/gpio$G911_GPIO/value 2>/dev/null
usleep 200000 2>/dev/null || sleep 0.2
echo in > /sys/class/gpio/gpio$G911_GPIO/direction 2>/dev/null
usleep 300000 2>/dev/null || sleep 0.3
echo $G911_GPIO > /sys/class/gpio/unexport 2>/dev/null
# 等内核 goodix 驱动注册 input 设备，动态解析节点（节点号会漂移，勿写死）
n=0
while ! grep -q "Goodix Capacitive TouchScreen" /proc/bus/input/devices 2>/dev/null && [ $n -lt 50 ]; do
    usleep 100000 2>/dev/null || sleep 1
    n=$((n+1))
done
node=$(awk '/Goodix Capacitive TouchScreen/{f=1;next} f && /Handlers/{match($0,/event[0-9]+/); print substr($0,RSTART,RLENGTH); exit}' /proc/bus/input/devices 2>/dev/null)
if [ -n "$node" ]; then
    export TSLIB_TSDEVICE="/dev/input/$node"
else
    export TSLIB_TSDEVICE=/dev/input/event0
fi
exec /usr/sbin/start_ipc_main.sh
