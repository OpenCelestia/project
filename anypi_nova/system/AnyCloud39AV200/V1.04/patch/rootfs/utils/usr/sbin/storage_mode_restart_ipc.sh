#!/bin/sh
# Restore local SD+install and exec ipc_main after leaving USB MSC session.
# Keep this script minimal: heavy /proc scans, kill-unknown, rmmod ak_ipu have
# hard-locked the SoC (serial dead). IPU leak is handled by CLOEXEC + killing
# wpa before IPU_Close in tablet_setting_storage.c.

LOG=/tmp/storage_restart.log
LOG_PERM=/etc/config/storage_restart.log
LOCKDIR=/tmp/storage_restart.lock.d
PENDING=/tmp/storage_restart_pending
UI_LOCK=/tmp/storage_restart_ui_lock
MOUNT_SCRIPT=/usr/sbin/mount_install.sh
USB_SCRIPT=/usr/sbin/usb_udc.sh
START_SCRIPT=/usr/sbin/start_ipc_main.sh

export PATH="/bin:/usr/bin:/sbin:/usr/sbin:${PATH:-}"

rlog()
{
	echo "[storage_restart] $*" >> "$LOG" 2>/dev/null
	echo "[storage_restart] $*" >> "$LOG_PERM" 2>/dev/null
	echo "[storage_restart] $*"
	sync
}

close_inherited_fds()
{
	fd=""

	for fd in /proc/self/fd/*; do
		[ -L "$fd" ] || continue
		num=${fd##*/}
		case "$num" in
		0|1|2) continue ;;
		esac
		eval "exec $num>&-" 2>/dev/null
	done
}

cleanup()
{
	rm -f "$PENDING"
	rm -f "$UI_LOCK"
	rm -rf "$LOCKDIR"
}

wait_ipc_gone()
{
	max=25
	i=0

	while test $i -lt $max; do
		if ! pidof nova_main ipc_main ipc_home >/dev/null 2>&1; then
			rlog "nova_main exited after ${i}s"
			return 0
		fi
		sleep 1
		i=$((i + 1))
	done

	rlog "WARN: nova_main still running, sending SIGTERM"
	killall nova_main ipc_main ipc_home 2>/dev/null
	sleep 2

	i=0
	while test $i -lt 10; do
		if ! pidof nova_main ipc_main ipc_home >/dev/null 2>&1; then
			rlog "nova_main gone after SIGTERM (+${i}s)"
			return 0
		fi
		killall -9 nova_main ipc_main ipc_home 2>/dev/null
		sleep 1
		i=$((i + 1))
	done

	if pidof nova_main ipc_main ipc_home >/dev/null 2>&1; then
		return 1
	fi
	return 0
}

acquire_lock()
{
	pid=""

	if mkdir "$LOCKDIR" 2>/dev/null; then
		echo $$ > "$LOCKDIR/pid"
		return 0
	fi

	if [ -f "$LOCKDIR/pid" ]; then
		pid=`cat "$LOCKDIR/pid" 2>/dev/null`
		case "$pid" in
		''|*[!0-9]*) ;;
		*)
			if kill -0 "$pid" 2>/dev/null; then
				return 1
			fi
			;;
		esac
	fi

	rm -rf "$LOCKDIR"
	if mkdir "$LOCKDIR" 2>/dev/null; then
		echo $$ > "$LOCKDIR/pid"
		return 0
	fi
	return 1
}

# Best-effort: drop leftover wifi procs that may still hold /dev/ipu.
drop_wifi_daemons()
{
	killall -9 wpa_supplicant 2>/dev/null || true
	killall -9 udhcpc 2>/dev/null || true
	killall -9 hostapd 2>/dev/null || true
}

# Run USB uninstall in background; if it wedges in gadget rmmod, do not block forever.
usb_uninstall_with_timeout()
{
	rcfile=/tmp/storage_usb_un.rc
	upid=""
	i=0
	max=12

	rm -f "$rcfile"
	(
		"$USB_SCRIPT" uninstall
		echo $? > "$rcfile"
	) >>"$LOG" 2>&1 &
	upid=$!

	while kill -0 "$upid" 2>/dev/null; do
		if [ "$i" -ge "$max" ]; then
			rlog "WARN: usb_udc uninstall hung ${max}s (PC may still hold MSC) — kill helper, continue"
			kill -9 "$upid" 2>/dev/null || true
			return 1
		fi
		sleep 1
		i=$((i + 1))
	done
	wait "$upid" 2>/dev/null
	if [ -f "$rcfile" ] && [ "$(cat "$rcfile" 2>/dev/null)" = "0" ]; then
		rlog "usb_udc uninstall ok (${i}s)"
		return 0
	fi
	rlog "WARN: usb_udc uninstall failed/incomplete"
	return 1
}

trap '' INT HUP TSTP

: > "$LOG" 2>/dev/null
rlog "script entry pid=$$ ppid=$PPID"
close_inherited_fds

if ! acquire_lock; then
	rlog "another restore already running, skip"
	exit 0
fi

echo $$ > "$PENDING"
trap cleanup EXIT

rlog "begin local restore"
drop_wifi_daemons

if ! wait_ipc_gone; then
	rlog "ERROR: ipc_main still running after wait"
	exit 1
fi

drop_wifi_daemons

if [ -x "$USB_SCRIPT" ]; then
	rlog "usb_udc uninstall begin"
	usb_uninstall_with_timeout || true
else
	rlog "WARN: missing $USB_SCRIPT"
fi

if [ ! -f "$MOUNT_SCRIPT" ]; then
	rlog "ERROR: missing $MOUNT_SCRIPT"
	exit 1
fi

rlog "wait_sd begin"
sh -c ". '$MOUNT_SCRIPT' wait_sd" >>"$LOG" 2>&1 || rlog "WARN: wait_sd timeout"
rlog "umount_force begin"
sh -c ". '$MOUNT_SCRIPT' umount_force" >>"$LOG" 2>&1 || rlog "WARN: umount_force issues"

sync

rlog "mount begin"
if ! . "$MOUNT_SCRIPT" mount >>"$LOG" 2>&1; then
	rlog "ERROR: mount_sd_install failed"
	exit 1
fi
rlog "mount done"

if [ ! -x "$START_SCRIPT" ]; then
	rlog "ERROR: missing $START_SCRIPT"
	exit 1
fi

rlog "local restore ready, exec ipc_main foreground"
rm -f "$PENDING"
rm -f "$UI_LOCK"
rm -rf "$LOCKDIR"
trap - EXIT

if [ -c /dev/console ]; then
	exec "$START_SCRIPT" </dev/console >/dev/console 2>&1
fi
exec "$START_SCRIPT"
