#!/bin/sh
###
# Luna flash boot script (/etc/config/app.sh, run by service.sh).
#
# Folds the former app.sh (platform + WiFi + TF) and app_run.sh (display +
# sensor + luna_main) into one file. Boot stages:
#   1. platform init  : printk/date, touch/NPU/su7i22 modules, pwr_daemon
#   2. WiFi + TF      : SDIO driver load + TF mount (background, non-blocking)
#   3. display         : tslib env + app_02_load.sh (LCD power/backlight/fb0)
#   4. luna_main       : start launcher immediately after display ready
#   5. sensor + venc   : os05a20 sensor + ak_venc modules (background)
#
# WiFi association is NOT done here: the launcher calls the framework
# (network station connect_from_config) which reads /etc/config/settings.json
# wifi.ssid/psk; the aic8800 firmware then associates + does DHCP. This
# script only loads the driver so the HAL has a device to ioctl.
#
# WiFi + TF card init runs in background so launcher displays without waiting
# for SDIO enumeration. The framework retries network_init_once() every second;
# the driver will be ready well before the first WiFi connect attempt.
#
# This is the FLASH runtime only -- no NFS logic. NFS dev mode is a separate
# tree deployed by `build.sh --nfs` (scripts/nfs/deploy.sh) and started by
# hand on the board: `killall luna_main; sh /mnt/nfs/app_run.sh`.
# app_02_load.sh stays a separate file: build_soc_system.sh patches a sensor
# insmod line into it for 2LANCAM boards.

# --- tunables --------------------------------------------------------------
WIFI_IF="${WIFI_IF:-vnet0}"
APP_BIN="${APP_BIN:-/usr/sbin/luna_main}"

# === 1. platform init ======================================================
echo 4 > /proc/sys/kernel/printk
date -s "2025-1-1 00:00:00"

insmod /usr/modules/cst816x.ko
insmod /usr/modules/ak_su7i22.ko
insmod /usr/modules/ak_npu.ko
pwr_daemon &
sleep 2

# Luna power-key daemon (long-press key 90 → gpio2 shutdown). Independent of luna_main.
if [ -x /usr/sbin/luna_power_keyd ]; then
	killall luna_power_keyd 2>/dev/null
	/usr/sbin/luna_power_keyd &
	echo "[app] luna_power_keyd started"
else
	echo "[app] warn: /usr/sbin/luna_power_keyd missing (long-press shutdown disabled)"
fi

# DNS fallback — set early so NTP/weather work as soon as WiFi connects
if [ ! -s /etc/resolv.conf ]; then
	echo "nameserver 223.5.5.5"   > /etc/resolv.conf
	echo "nameserver 114.114.114.114" >> /etc/resolv.conf
fi

# === 2. WiFi + TF card SDIO init (background) ==============================
# Both share ak_mci (SDIO controller). Run entirely in background: display
# and luna_main do not need WiFi or TF to start. Framework waits for
# /dev/aic_cdev + vnet0 before connect_from_config.
#
# aic8800_netdrv probe needs the SDIO function already enumerated; a fixed
# "sleep 2" after ak_mci is often too short (ENODEV → no vnet0/aic_cdev).
(
	modprobe mmc_core 2>/dev/null
	modprobe mmc_block 2>/dev/null
	insmod /usr/modules/ak_mci.ko
	# Wait until SDIO bus sees at least one function (WiFi chip).
	_i=0
	while [ $_i -lt 15 ]; do
		if ls /sys/bus/sdio/devices/* >/dev/null 2>&1; then
			echo "[app] SDIO device(s): $(ls /sys/bus/sdio/devices 2>/dev/null | tr '\n' ' ')"
			break
		fi
		sleep 1
		_i=$((_i + 1))
	done
	if ! ls /sys/bus/sdio/devices/* >/dev/null 2>&1; then
		echo "[app] warn: no /sys/bus/sdio/devices after ${_i}s (check mmc2 / WiFi power)"
	fi
	# Retry insmod: probe can still race right after the device node appears.
	_i=0
	_aic_ok=0
	while [ $_i -lt 10 ]; do
		if lsmod 2>/dev/null | grep -q '^aic8800_netdrv'; then
			_aic_ok=1
			break
		fi
		if insmod /usr/modules/aic8800_netdrv.ko 2>/tmp/aic_insmod.err; then
			_aic_ok=1
			echo "[app] aic8800_netdrv loaded (try=$((_i + 1)))"
			break
		fi
		echo "[app] aic8800_netdrv not ready (try=$((_i + 1))): $(cat /tmp/aic_insmod.err 2>/dev/null)"
		sleep 1
		_i=$((_i + 1))
	done
	if [ "$_aic_ok" -eq 1 ]; then
		ifconfig "${WIFI_IF}" up 2>/dev/null
		_j=0
		while [ $_j -lt 10 ]; do
			if [ -e /dev/aic_cdev ] && ifconfig "${WIFI_IF}" >/dev/null 2>&1; then
				echo "[app] ${WIFI_IF} up, /dev/aic_cdev ready (assoc deferred to framework)"
				break
			fi
			sleep 1
			_j=$((_j + 1))
		done
		if ! ifconfig "${WIFI_IF}" >/dev/null 2>&1; then
			echo "[app] warn: ${WIFI_IF} still missing after aic8800 load"
		fi
		if [ ! -e /dev/aic_cdev ]; then
			echo "[app] warn: /dev/aic_cdev missing after aic8800 load"
		fi
	else
		echo "[app] ERROR: aic8800_netdrv failed after retries (check aic8800 / SDIO)"
	fi
	# TF card: mmcblk0p1 appears after mmc_block + ak_mci above; poll briefly
	_i=0
	while [ $_i -lt 5 ] && [ ! -b /dev/mmcblk0p1 ]; do
		sleep 1; _i=$((_i + 1))
	done
	if [ -b /dev/mmcblk0p1 ]; then
		grep -q ' /mnt/tfcard ' /proc/mounts 2>/dev/null || {
			mkdir -p /mnt/tfcard
			mount -t vfat /dev/mmcblk0p1 /mnt/tfcard \
				&& echo "[app] TF mounted /dev/mmcblk0p1 -> /mnt/tfcard" \
				|| echo "[app] warn: TF mount failed (/dev/mmcblk0p1)"
		}
	else
		echo "[app] no TF card (/dev/mmcblk0p1 absent)"
	fi
) &

# === 3. display (LCD power/backlight + fb0) ================================
export TSLIB_CONFFILE=/etc/config/ts.rgb.conf
export TSLIB_CALIBFILE=/etc/config/ts_calibrate.rgb.conf
export TSLIB_PLUGINDIR=/usr/bin/tslib/lib/ts
export TSLIB_TSDEVICE=/dev/input/event1
export TSLIB_CONSOLEDEVICE=none
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-/usr/lib:/usr/bin/tslib/lib:/lib}"
export APP_SETTINGS_CONFIG="${APP_SETTINGS_CONFIG:-${APP_RUNTIME_CONFIG:-/etc/config/settings.json}}"
export APP_RUNTIME_CONFIG="${APP_RUNTIME_CONFIG:-$APP_SETTINGS_CONFIG}"
export TZ="${TZ:-CST-8}"

if [ -x /etc/config/app_02_load.sh ]; then
	/etc/config/app_02_load.sh
elif [ -f /etc/config/app_02_load.sh ]; then
	sh /etc/config/app_02_load.sh
else
	echo "[app] warn: /etc/config/app_02_load.sh missing"
fi
if [ -c /dev/fb0 ]; then
	echo "[app] /dev/fb0 ready"
else
	echo "[app] warn: /dev/fb0 not found after app_02_load"
fi

# === 4. luna_main ==========================================================
# Start launcher immediately after display init — sensor+venc loads in
# background below. Camera auto-launch is off by default; sensor will be
# ready well before the user navigates to camera from the launcher.
if [ -n "${LUNA_BOOT_APP:-}" ]; then
	echo "[app] LUNA_BOOT_APP=$LUNA_BOOT_APP (auto-launch after home)"
	export LUNA_BOOT_APP
else
	echo "[app] no LUNA_BOOT_APP: stay on launcher (no camera auto-launch)"
	unset LUNA_BOOT_APP
fi

echo "[app] mode=flash LD_LIBRARY_PATH=$LD_LIBRARY_PATH luna_main=$APP_BIN"

if [ ! -x "$APP_BIN" ]; then
	echo "[app] ERROR: $APP_BIN missing or not executable"
	exit 1
fi

echo "[app] starting $APP_BIN ..."
"$APP_BIN" &
LM_PID=$!

# === 5. sensor + venc (background) =========================================
# Loads concurrently with luna_main init. Camera HAL will find sensor ready
# by the time the user taps camera from the launcher.
# Do NOT killall luna_main here — that races with the process started above.
(
	if [ -x /usr/sbin/os05a20.sh ]; then
		/usr/sbin/os05a20.sh
	elif [ -f /usr/sbin/os05a20.sh ]; then
		sh /usr/sbin/os05a20.sh
	fi
	insmod /usr/modules/ak_venc_adapter.ko 2>/dev/null
	insmod /usr/modules/ak_venc_bridge.ko 2>/dev/null
	echo "[app] sensor + venc ready"
) &

sleep 2
if kill -0 "$LM_PID" 2>/dev/null; then
	echo "[app] luna_main running (pid=$LM_PID)"
else
	wait "$LM_PID" 2>/dev/null
	echo "[app] luna_main died within 2s (exit=$?)"
fi
