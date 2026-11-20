#!/bin/sh
# Switch between local SD(/mnt/install) mount and USB mass-storage (PC access).
# Pair with mount_install.sh and usb_udc.sh.
#
# USB MSC session: ipc_main keeps running (code in RAM); only valid while user stays
# on the Settings > Storage page. Leaving that page or choosing Local Storage runs
# apply local_restart (remount /mnt and restart ipc_main).
#
# Usage:
#   storage_mode_switch.sh status
#   storage_mode_switch.sh get
#   storage_mode_switch.sh set <local|usb_msc>
#   storage_mode_switch.sh apply usb_msc          # session USB (no kill ipc_main)
#   storage_mode_switch.sh apply local_restart    # remount + restart ipc_main
#   storage_mode_switch.sh boot

CFG=/etc/config/settings.json
CFG_LEGACY=/etc/config/storage_mode.ini
SESSION_FLAG=/tmp/storage_usb_session
RESTART_PENDING=/tmp/storage_restart_pending
RESTART_LOG=/tmp/storage_restart.log
MOUNT_SCRIPT=/usr/sbin/mount_install.sh
USB_SCRIPT=/usr/sbin/usb_udc.sh
RESTART_SCRIPT=/usr/sbin/storage_mode_restart_ipc.sh

log()
{
	echo "[storage_mode] $*"
}

is_mounted()
{
	mount | grep -q " on $1 "
}

# Map CLI / legacy names to numeric mode: 0=local, 1=usb_msc
mode_to_idx()
{
	case "$1" in
	1|usb|usb_msc|udisk|u_disk) echo 1 ;;
	*) echo 0 ;;
	esac
}

idx_to_name()
{
	if [ "$1" = 1 ]; then
		echo usb_msc
	else
		echo local
	fi
}

read_saved_mode()
{
	idx=0
	if [ -f "$CFG" ]; then
		# Prefer settings.json storage.mode (0/1); tolerate quoted numbers.
		line=`sed -n '/"storage"[[:space:]]*:/,/}/p' "$CFG" 2>/dev/null | grep -E '"mode"[[:space:]]*:' | tail -n 1`
		if [ -n "$line" ]; then
			val=`echo "$line" | sed 's/.*"mode"[[:space:]]*:[[:space:]]*//; s/[,"}].*//; s/[[:space:]]//g' | tr -d '"'`
			idx=`mode_to_idx "$val"`
			echo `idx_to_name "$idx"`
			return 0
		fi
	fi
	# Legacy storage_mode.ini fallback
	if [ -f "$CFG_LEGACY" ]; then
		line=`grep -E '^[[:space:]]*mode[[:space:]]*=' "$CFG_LEGACY" 2>/dev/null | tail -n 1`
		if [ -n "$line" ]; then
			val=`echo "$line" | sed 's/.*=[[:space:]]*//; s/[[:space:]]//g' | tr 'A-Z' 'a-z'`
			idx=`mode_to_idx "$val"`
		fi
	fi
	echo `idx_to_name "$idx"`
}

write_saved_mode()
{
	target=$1
	idx=`mode_to_idx "$target"`
	name=`idx_to_name "$idx"`

	mkdir -p /etc/config
	if [ -f "$CFG" ]; then
		tmp=`mktemp /tmp/settings.XXXXXX 2>/dev/null || echo /tmp/settings.$$`
		if grep -q '"storage"' "$CFG" 2>/dev/null; then
			awk -v mode="$idx" '
				BEGIN { in_st = 0 }
				/"storage"[[:space:]]*:/ { in_st = 1 }
				in_st && /"mode"[[:space:]]*:/ {
					sub(/"mode"[[:space:]]*:[^,}]*/, "\"mode\": " mode)
					in_st = 0
				}
				{ print }
			' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
		else
			# Insert storage object before the final top-level closing brace (last line).
			total=`wc -l < "$CFG" | tr -d ' '`
			awk -v mode="$idx" -v total="$total" '
				NR == total && $0 ~ /^[[:space:]]*}[[:space:]]*$/ {
					print "  ,"
					print "  \"storage\": {"
					print "    \"mode\": " mode
					print "  }"
				}
				{ print }
			' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
		fi
		rm -f "$tmp" 2>/dev/null
		rm -f "$CFG_LEGACY" 2>/dev/null
		sync
		log "saved storage.mode=$idx ($name) -> $CFG"
		return 0
	fi

	# No settings.json yet — create minimal file
	cat > "$CFG" <<EOF
{
  "storage": {
    "mode": $idx
  }
}
EOF
	rm -f "$CFG_LEGACY" 2>/dev/null
	sync
	log "saved storage.mode=$idx ($name) -> $CFG"
	return 0
}

runtime_status()
{
	if [ -f "$SESSION_FLAG" ]; then
		echo usb_msc
		return 0
	fi
	if lsmod 2>/dev/null | grep -q g_mass_storage; then
		echo usb_msc
		return 0
	fi
	if is_mounted /mnt && [ -d /mnt/install ]; then
		echo local
		return 0
	fi
	echo unknown
}

kill_ipc_apps()
{
	killall -9 nova_main ipc_main ipc_home 2>/dev/null
	sleep 1
	if pidof nova_main ipc_main ipc_home >/dev/null 2>&1; then
		killall -9 nova_main ipc_main ipc_home 2>/dev/null
		sleep 1
	fi
}

restart_already_running()
{
	pid=""

	if [ -f "$RESTART_PENDING" ]; then
		pid=`cat "$RESTART_PENDING" 2>/dev/null`
		case "$pid" in
		starting)
			log "local_restart already in progress (pending)"
			return 0
			;;
		''|*[!0-9]*)
			;;
		*)
			if kill -0 "$pid" 2>/dev/null; then
				log "local_restart already in progress (pid $pid)"
				return 0
			fi
			;;
		esac
		rm -f "$RESTART_PENDING"
	fi
	return 1
}

fix_firmware_path()
{
	if [ -d /sys/module/firmware_class/parameters/path ]; then
		echo -n "/mnt/install/model/" > /sys/module/firmware_class/parameters/path
	fi
}

apply_local()
{
	rm -f "$SESSION_FLAG"
	write_saved_mode local || return 1

	if [ -x "$USB_SCRIPT" ]; then
		"$USB_SCRIPT" uninstall || return 1
	fi

	if [ -f "$MOUNT_SCRIPT" ]; then
		# shellcheck disable=SC1090
		. "$MOUNT_SCRIPT" umount
		# shellcheck disable=SC1090
		. "$MOUNT_SCRIPT" mount || return 1
	else
		log "missing $MOUNT_SCRIPT"
		return 1
	fi

	fix_firmware_path
	log "local mode ready (/mnt/install mounted)"
	return 0
}

# Session USB: export SD to PC; ipc_main keeps running from RAM.
apply_usb_msc_session()
{
	if [ -f "$MOUNT_SCRIPT" ]; then
		# shellcheck disable=SC1090
		. "$MOUNT_SCRIPT" umount_usb || return 1
	fi

	if [ -x "$USB_SCRIPT" ]; then
		"$USB_SCRIPT" install || return 1
	else
		log "missing $USB_SCRIPT"
		return 1
	fi

	touch "$SESSION_FLAG"
	log "usb_msc session ready (ipc_main keeps running, SD exported)"
	return 0
}

apply_local_restart_ipc()
{
	bgpid=""

	if restart_already_running; then
		return 0
	fi

	rm -f "$SESSION_FLAG"
	write_saved_mode local || return 1
	sync

	if [ ! -x "$RESTART_SCRIPT" ]; then
		log "missing $RESTART_SCRIPT, fallback reboot"
		reboot -f
	fi

	echo starting > "$RESTART_PENDING"
	sync

	# Wait for ipc_main graceful teardown before remount/restart.
	(
		sleep 3
		exec "$RESTART_SCRIPT"
	) </dev/null >>"$RESTART_LOG" 2>&1 &
	bgpid=$!
	echo "$bgpid" > "$RESTART_PENDING"
	sync
	log "spawned detached restart pid=$bgpid (log $RESTART_LOG)"
	return 0
}

apply_boot()
{
	rm -f "$SESSION_FLAG"
	log "boot apply local mode"

	# Cold boot: mount only if needed; skip usb_udc uninstall / umount when MSC was never active.
	if is_mounted /mnt && [ -d /mnt/install ]; then
		fix_firmware_path
		log "local mode ready (/mnt/install already mounted)"
		return 0
	fi

	if [ -f "$MOUNT_SCRIPT" ]; then
		# shellcheck disable=SC1090
		. "$MOUNT_SCRIPT" mount || return 1
	else
		log "missing $MOUNT_SCRIPT"
		return 1
	fi

	fix_firmware_path
	log "local mode ready (/mnt/install mounted)"
	return 0
}

usage()
{
	echo "Usage: $0 <status|get|set|apply|boot> [0|1|local|usb_msc|local_restart]"
	echo "  storage.mode in settings.json: 0=local, 1=usb_msc"
}

main()
{
	cmd=$1
	arg=$2

	case "$cmd" in
	status)
		runtime_status
		;;
	get)
		runtime_status
		;;
	set)
		if [ -z "$arg" ]; then
			usage
			return 1
		fi
		case "$arg" in
		0|1|local|usb_msc|usb|udisk|u_disk|sd|device)
			write_saved_mode "$arg"
			;;
		*)
			log "invalid mode: $arg (use 0/local or 1/usb_msc)"
			return 1
			;;
		esac
		;;
	apply)
		if [ -z "$arg" ]; then
			usage
			return 1
		fi
		case "$arg" in
		usb_msc)
			apply_usb_msc_session
			;;
		local_restart)
			apply_local_restart_ipc
			;;
		local)
			apply_local_restart_ipc
			;;
		*)
			log "unknown mode: $arg"
			return 1
			;;
		esac
		;;
	boot)
		apply_boot
		;;
	*)
		usage
		return 1
		;;
	esac
}

main "$@"
