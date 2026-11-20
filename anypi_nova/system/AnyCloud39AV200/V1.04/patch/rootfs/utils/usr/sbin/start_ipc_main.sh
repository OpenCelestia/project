#!/bin/sh
# Start nova_main from flash /usr (libs/gui/setting on usr; model/other apps on SD).
INSTALL_MOUNT=/mnt/install
MOUNT_SCRIPT=/usr/sbin/mount_install.sh
IPC=
BG=0

if [ "$1" = "--bg" ]; then
	BG=1
fi

if [ -f "$MOUNT_SCRIPT" ]; then
	. "$MOUNT_SCRIPT" mount || true
fi

export TSLIB_CONFFILE=/etc/config/ts.rgb.conf
export TSLIB_CALIBFILE=/etc/config/ts_calibrate.rgb.conf
export TSLIB_PLUGINDIR=/usr/lib/ts
# 节点号会漂移：仅当上游未探测到 goodix 节点时才兜底 event0，不要覆盖已设值
[ -n "$TSLIB_TSDEVICE" ] || export TSLIB_TSDEVICE=/dev/input/event0
export TSLIB_CONSOLEDEVICE=none

if [ -n "$LD_LIBRARY_PATH" ]; then
	export LD_LIBRARY_PATH="/usr/lib:/lib:$INSTALL_MOUNT/apps/volc_engine/lib:$INSTALL_MOUNT/lib:$INSTALL_MOUNT:$LD_LIBRARY_PATH"
else
	export LD_LIBRARY_PATH="/usr/lib:/lib:$INSTALL_MOUNT/apps/volc_engine/lib:$INSTALL_MOUNT/lib:$INSTALL_MOUNT"
fi

if [ -n "$PATH" ]; then
	export PATH="/usr/sbin:/usr/bin:/sbin:/bin:$INSTALL_MOUNT:$PATH"
else
	export PATH="/usr/sbin:/usr/bin:/sbin:/bin:$INSTALL_MOUNT"
fi

# nova_main is the process name. Older images may still have ipc_main / ipc_home.
for cand in /usr/sbin/nova_main "$INSTALL_MOUNT/nova_main" \
	/usr/sbin/ipc_main /usr/sbin/ipc_home \
	"$INSTALL_MOUNT/ipc_main" "$INSTALL_MOUNT/ipc_home"; do
	if [ -x "$cand" ]; then
		IPC=$cand
		break
	fi
done

if [ -z "$IPC" ]; then
	echo "[start_ipc_main] ERROR: cannot find nova_main under /usr/sbin or $INSTALL_MOUNT"
	exit 1
fi

if [ -d /sys/module/firmware_class/parameters/path ]; then
	echo -n "$INSTALL_MOUNT/model/" > /sys/module/firmware_class/parameters/path
fi

cd /usr || exit 1

if [ "$BG" -eq 1 ]; then
	if command -v setsid >/dev/null 2>&1; then
		setsid "$IPC" >>/tmp/nova_main.log 2>&1 </dev/null &
	elif command -v nohup >/dev/null 2>&1; then
		nohup "$IPC" >>/tmp/nova_main.log 2>&1 </dev/null &
	else
		echo "[start_ipc_main] ERROR: --bg needs setsid or nohup"
		exit 1
	fi
	echo "[start_ipc_main] started $IPC pid=$!"
	exit 0
fi

exec "$IPC"
