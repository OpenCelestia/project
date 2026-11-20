#!/bin/sh
###
# anypi_luna_dev / EVB_MBD_KM01A — /etc/config/app.sh
#
# Sensor: gc4053 ; WiFi: atbm6032 (packaged as /usr/sbin/wifi_driver.sh)
# Celestia: APP_SETTINGS_CONFIG (+ legacy APP_RUNTIME_CONFIG) + luna_dev_main (ipcamera / libipc_cam_app.so)
# No LCD / touch / tslib path.

APP_BIN="${APP_BIN:-/usr/sbin/luna_dev_main}"
SENSOR_SH="${SENSOR_SH:-gc4053.sh}"
# build_rootfs process_wifi_scripts installs scripts/wifi/atbm6032.sh as wifi_driver.sh
WIFI_SH="${WIFI_SH:-wifi_driver.sh}"

echo 4 > /proc/sys/kernel/printk
date -s "2025-1-1 00:00:00"

export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-/usr/lib:/lib}"
export APP_SETTINGS_CONFIG="${APP_SETTINGS_CONFIG:-${APP_RUNTIME_CONFIG:-/etc/config/settings.json}}"
export APP_RUNTIME_CONFIG="${APP_RUNTIME_CONFIG:-$APP_SETTINGS_CONFIG}"
export TZ="${TZ:-CST-8}"

if [ ! -s /etc/resolv.conf ]; then
	echo "nameserver 223.5.5.5" > /etc/resolv.conf
	echo "nameserver 114.114.114.114" >> /etc/resolv.conf
fi

# --- TF card --------------------------------------------------------------
if [ -x /usr/sbin/tf_card.sh ]; then
	/usr/sbin/tf_card.sh
elif [ -f /usr/sbin/tf_card.sh ]; then
	sh /usr/sbin/tf_card.sh
fi
mkdir -p /mnt/tfcard /tmp/sd
if [ -b /dev/mmcblk0p1 ]; then
	mount -t vfat /dev/mmcblk0p1 /mnt/tfcard 2>/dev/null \
		|| mount -t vfat /dev/mmcblk0p1 /tmp/sd 2>/dev/null \
		|| echo "[app] warn: TF mount failed"
elif [ -b /dev/mmcblk0 ]; then
	mount -t vfat /dev/mmcblk0 /mnt/tfcard 2>/dev/null \
		|| echo "[app] warn: TF mount failed"
fi

# --- WiFi (atbm6032 USB) -------------------------------------------------
# Only the driver is loaded here. Association is done by the framework
# (network station connect_from_config -> /etc/config/settings.json
# wifi.ssid/psk), which rewrites wpa_supplicant.conf and starts
# wpa_supplicant itself — same flow as luna / nova.
#
# The vendor wifi script (scripts/wifi/atbm6032.sh, packaged as
# wifi_driver.sh) does not implement every verb on every SDK: an unknown
# verb just prints usage and exits 0. So gate on wlan0 actually appearing,
# never on the script's exit status.
wifi_load_driver()
{
	modprobe cfg80211 2>/dev/null
	modprobe usb-common 2>/dev/null
	modprobe usbcore 2>/dev/null
	insmod /usr/modules/ak_hcd.ko 2>/dev/null
	if [ ! -f /usr/modules/atbm6032.ko ]; then
		echo "[app] ERROR: /usr/modules/atbm6032.ko missing"
		return 1
	fi
	insmod /usr/modules/atbm6032.ko 2>/dev/null
	sleep 3
	ifconfig wlan0 up 2>/dev/null
	return 0
}

wlan0_wait()
{
	_w=0
	while [ "$_w" -lt "$1" ]; do
		if [ -d /sys/class/net/wlan0 ]; then
			ifconfig wlan0 up 2>/dev/null
			return 0
		fi
		sleep 1
		_w=$((_w + 1))
	done
	return 1
}

wifi_bring_up()
{
	if [ -x "/usr/sbin/${WIFI_SH}" ]; then
		"/usr/sbin/${WIFI_SH}" install >/dev/null 2>&1
		if wlan0_wait 5; then
			echo "[app] wlan0 up via ${WIFI_SH} install"
			return 0
		fi
		# "sta" also loads the driver; it may associate from the shipped
		# conf, but that conf is now a credential-free stub and HAL
		# restarts wpa_supplicant on connect_from_config anyway.
		"/usr/sbin/${WIFI_SH}" sta &
		if wlan0_wait 10; then
			echo "[app] wlan0 up via ${WIFI_SH} sta"
			return 0
		fi
	fi

	wifi_load_driver
	if wlan0_wait 5; then
		echo "[app] wlan0 up via local atbm6032 insmod"
		return 0
	fi
	echo "[app] ERROR: wlan0 missing (check atbm6032 / USB host)"
	return 1
}

wifi_bring_up

# --- Sensor (vendor / patch: /usr/sbin/gc4053.sh) -------------------------
if [ -x "/usr/sbin/${SENSOR_SH}" ]; then
	"/usr/sbin/${SENSOR_SH}"
elif [ -f "/usr/sbin/${SENSOR_SH}" ]; then
	sh "/usr/sbin/${SENSOR_SH}"
else
	echo "[app] warn: sensor script /usr/sbin/${SENSOR_SH} missing"
fi

insmod /usr/modules/ak_venc_adapter.ko 2>/dev/null
insmod /usr/modules/ak_venc_bridge.ko 2>/dev/null

# --- Celestia ipcamera main -----------------------------------------------
echo "[app] starting ${APP_BIN} (launch_mode=ipcamera)"

if [ ! -x "$APP_BIN" ]; then
	echo "[app] ERROR: $APP_BIN missing or not executable"
	exit 1
fi

"$APP_BIN" &
APP_PID=$!
sleep 2
if kill -0 "$APP_PID" 2>/dev/null; then
	echo "[app] luna_dev_main running (pid=$APP_PID)"
else
	wait "$APP_PID" 2>/dev/null
	echo "[app] luna_dev_main died within 2s (exit=$?)"
fi
