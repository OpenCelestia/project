#!/bin/sh
# Fastsys + 16MB flash: core runtime on /usr; SD install holds other apps + model.
export TSLIB_CONFFILE=/etc/config/ts.rgb.conf
export TSLIB_CALIBFILE=/etc/config/ts_calibrate.rgb.conf
export TSLIB_PLUGINDIR=/usr/lib/ts
# GT911 由内建 goodix 驱动接管（中断式）；节点号会漂移，仅兜底 event0
[ -n "$TSLIB_TSDEVICE" ] || export TSLIB_TSDEVICE=/dev/input/event0
export TSLIB_CONSOLEDEVICE=none
# POSIX: CST-8 = China Standard Time (UTC+8). Used by log_info / OSD / UI localtime.
export TZ="${TZ:-CST-8}"

export LD_LIBRARY_PATH=/usr/lib:/lib:/mnt/install/apps/volc_engine/lib:/mnt/install/lib:/mnt/install:$LD_LIBRARY_PATH
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/mnt/install:$PATH

# 调试通道：尽早启动 telnetd（root 空密码，仅开发调试用，量产固件需移除）
pidof telnetd >/dev/null 2>&1 || telnetd

# 须先于 wifi：wifi_driver 内 modprobe firmware_class path=/usr/sbin 会改 path 参数
insmod /lib/modules/5.10.111/kernel/drivers/base/firmware_loader/firmware_class.ko path=/mnt/install/model/

# mmc1(SD) 与 mmc2(WiFi) 共用 ak_mci.ko。SD 不依赖 WiFi，先同步加载 ak_mci 出 mmcblk1。
modprobe mmc_core 2>/dev/null
modprobe mmc_block 2>/dev/null
if ! lsmod | grep -q ak_mci; then
	insmod /usr/modules/ak_mci.ko
fi

# Celestia: tablet auto-association (settings.json wifi.auto_connect) starts
# wpa_supplicant right after ipc_main; without the ATBM driver up by then its
# first attempt fails with "nl80211 not found" (modules otherwise wait for the
# post-Home wifi_driver.sh sta pass). Background load overlaps LCD/camera init.
(
	insmod /usr/modules/cfg80211.ko 2>/dev/null
	insmod /usr/modules/ATBM6162_wifi_sdio.ko 2>/dev/null
) &

# km02x app.sh order: lcd -> GPIO3 -> ipu -> touch -> mount_sd -> app
/usr/sbin/lcd.sh

echo 3 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio3/direction
echo 1 > /sys/class/gpio/gpio3/value

# Celestia: GPU (ak_ipu) needed by LVGL before app starts
insmod /usr/modules/ak_ipu.ko
# 触摸为内核内建 goodix 驱动（中断式），无需 insmod；桌面统一读 evdev 节点

# Camera VI must exist before ipc_main opens Camera/QR.
# Do NOT defer behind WiFi — that caused open /dev/vicap-0-0-0 ENOENT.
# Load in background so LCD/touch/SD path stays fast; apps should still see
# the node by the time the user enters Camera (~1–2s after boot).
(
	/usr/sbin/ov8856.sh
	insmod /usr/modules/ak_venc_adapter.ko 2>/dev/null
	insmod /usr/modules/ak_venc_bridge.ko 2>/dev/null
	# Wait briefly for async sensor/VCM bind to register the node
	i=0
	while [ "$i" -lt 50 ]; do
		if [ -e /dev/vicap-0-0-0 ]; then
			echo "camera: /dev/vicap-0-0-0 ready"
			break
		fi
		usleep 100000 2>/dev/null || sleep 0.1
		i=$((i + 1))
	done
	if [ ! -e /dev/vicap-0-0-0 ]; then
		echo "camera: WARN /dev/vicap-0-0-0 missing after ov8856.sh" >&2
		lsmod | grep -E 'ak_vi|ov8856|vicap|fp5510|ak_isp|ak_pp' >&2 || true
	fi
) &

# Local SD mount and USB MSC both use mmcblk1p1.
if [ -x /usr/sbin/storage_mode_switch.sh ]; then
	/usr/sbin/storage_mode_switch.sh boot
elif [ -x /usr/sbin/usb_udc.sh ]; then
	/usr/sbin/usb_udc.sh uninstall
	if [ -f /usr/sbin/mount_install.sh ]; then
		. /usr/sbin/mount_install.sh mount
	fi
fi

# wifi install 里 modprobe firmware_class path=/usr/sbin，挂载 install 后改回模型目录
if [ -d /sys/module/firmware_class/parameters/path ]; then
	echo -n "/mnt/install/model/" > /sys/module/firmware_class/parameters/path
fi

# Backend (WiFi / audio / NPU) after Home first frame — camera already started above.
(
	i=0
	while [ "$i" -lt 30 ]; do
		if [ -f /tmp/ipc_gui_ready ]; then
			break
		fi
		sleep 1
		i=$((i + 1))
	done
	# Brief settle so GuiThread finishes first refr before SDIO/WiFi DMA
	sleep 1
	if [ -x /usr/sbin/wifi_driver.sh ]; then
		/usr/sbin/wifi_driver.sh sta
	else
		/usr/sbin/tf_card.sh
	fi
	# Idempotent if early load already ran
	/usr/sbin/ov8856.sh
	insmod /usr/modules/ak_venc_adapter.ko 2>/dev/null
	insmod /usr/modules/ak_venc_bridge.ko 2>/dev/null
	insmod /usr/modules/ak_pcm.ko
	insmod /usr/modules/ak_npu.ko
) &

uptime

# ---- 触摸三件套（NOR 自足，空 SD NAND 板也必须正常）----
# 1) 删除 vendor 底包遗留的 ts.rgb.conf：HAL 检测到 tslib 会走其非阻塞
#    ts_read 空转分支（input_poll 烧 50% CPU，touch.c 的 tslib 分支缺 select
#    等待）；文件缺失时 HAL 回退 raw evdev（select 阻塞式，已验证路径）。
rm -f /etc/config/ts.rgb.conf
# 2) GT911 唤醒：上电 INT 高复位会进睡眠态——配置区可读（probe 日志正常）
#    但永不扫描、永不发中断，必须 INT(GPIO10) 高脉冲 200ms 唤醒。
G911_GPIO=10
[ -e /sys/class/gpio/gpio$G911_GPIO ] || echo $G911_GPIO > /sys/class/gpio/export 2>/dev/null
echo out > /sys/class/gpio/gpio$G911_GPIO/direction 2>/dev/null
echo 1 > /sys/class/gpio/gpio$G911_GPIO/value 2>/dev/null
usleep 200000 2>/dev/null || sleep 0.2
echo in > /sys/class/gpio/gpio$G911_GPIO/direction 2>/dev/null
usleep 300000 2>/dev/null || sleep 0.3
echo $G911_GPIO > /sys/class/gpio/unexport 2>/dev/null
# 3) 动态解析 goodix 的 event 节点（节点号会漂移，勿写死）并导出给桌面 HAL
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
