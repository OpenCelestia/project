#!/bin/sh
# Mount SD (mmc1) and loop-mount afht.sqsh4; export tslib / LD_LIBRARY_PATH for ipc_main.
# Pair with usb_udc.sh: uninstall MSC first, then:
#   . /usr/sbin/mount_sd_afht.sh mount
#
# Must be sourced (.) from the shell that will run ipc_main so export takes effect:
#   . /usr/sbin/mount_sd_afht.sh mount

SD_MOUNT=/mnt/sd
AFHT_MOUNT=/mnt/afht
AFHT_IMAGE=afht.sqsh4
AFHT_SONAME_DIR=/tmp/afht_soname

log()
{
	echo "[mount_sd_afht] $*"
}

is_mounted()
{
	mount | grep -q " on $1 "
}

# USB MSC and local SD mount must not share mmcblk1p1 (unsafe dual open).
ensure_usb_msc_off()
{
	if ! lsmod | grep -q g_mass_storage; then
		return 0
	fi

	log "g_mass_storage loaded, uninstall USB MSC before SD mount"
	if [ -x /usr/sbin/usb_udc.sh ]; then
		if ! /usr/sbin/usb_udc.sh uninstall; then
			log "usb_udc uninstall failed"
			return 1
		fi
	else
		modprobe -r g_mass_storage 2>/dev/null
		modprobe -r usb_f_mass_storage 2>/dev/null
	fi

	if lsmod | grep -q g_mass_storage; then
		log "g_mass_storage still loaded (eject USB on PC, then retry)"
		return 1
	fi
	return 0
}

sd_block_dev()
{
	if test -e /dev/mmcblk1p1; then
		echo /dev/mmcblk1p1
	elif test -e /dev/mmcblk1; then
		echo /dev/mmcblk1
	else
		echo ""
	fi
}

# ACTION: SD on mmc1 shares ak_mci with WiFi SDIO. Poll faster when WiFi is deferred.
wait_sd_block_dev()
{
	max=50
	i=0
	while test $i -lt $max; do
		dev=`sd_block_dev`
		if test -n "$dev"; then
			if test $i -gt 0; then
				log "SD device ready after $((i * 2))00ms: $dev"
			fi
			return 0
		fi
		sleep 0.2
		i=$((i + 1))
	done
	return 1
}

# After USB MSC uninstall the block node may appear late; verify it is readable.
wait_sd_block_open()
{
	max=15
	i=0
	dev=""

	while test $i -lt $max; do
		dev=`sd_block_dev`
		if test -n "$dev" && test -b "$dev"; then
			if dd if="$dev" of=/dev/null bs=512 count=1 2>/dev/null; then
				if test $i -gt 0; then
					log "SD block open ready after ${i}s: $dev"
				fi
				return 0
			fi
		fi
		sleep 1
		i=$((i + 1))
	done

	log "SD block open failed: ${dev:-unknown}"
	return 1
}

export_afht_runtime_env()
{
	export TSLIB_CONFFILE=/etc/config/ts.rgb.conf
	export TSLIB_CALIBFILE=/etc/config/ts_calibrate.rgb.conf
	export TSLIB_PLUGINDIR="$AFHT_MOUNT/lib/ts"
	export TSLIB_TSDEVICE=/dev/input/event0
	export TSLIB_CONSOLEDEVICE=none

	if test -d "$AFHT_MOUNT/lib"; then
		if test ! -e "$AFHT_MOUNT/lib/libiconv.so.2"; then
			mkdir -p "$AFHT_SONAME_DIR"
			for f in "$AFHT_MOUNT"/lib/*.so.*; do
				if test -f "$f"; then
					bn=`basename "$f"`
					soname=`echo "$bn" | sed 's/\..*$//'` 
					if test ! -e "$AFHT_SONAME_DIR/$soname"; then
						ln -sf "$f" "$AFHT_SONAME_DIR/$soname"
					fi
				fi
			done
			if test -n "$LD_LIBRARY_PATH"; then
				export LD_LIBRARY_PATH="$AFHT_SONAME_DIR:$AFHT_MOUNT/lib:$AFHT_MOUNT:/lib:/usr/lib:$LD_LIBRARY_PATH"
			else
				export LD_LIBRARY_PATH="$AFHT_SONAME_DIR:$AFHT_MOUNT/lib:$AFHT_MOUNT:/lib:/usr/lib"
			fi
		else
			if test -n "$LD_LIBRARY_PATH"; then
				export LD_LIBRARY_PATH="$AFHT_MOUNT/lib:$AFHT_MOUNT:/lib:/usr/lib:$LD_LIBRARY_PATH"
			else
				export LD_LIBRARY_PATH="$AFHT_MOUNT/lib:$AFHT_MOUNT:/lib:/usr/lib"
			fi
		fi
	else
		if test -n "$LD_LIBRARY_PATH"; then
			export LD_LIBRARY_PATH="$AFHT_MOUNT:/lib:/usr/lib:$LD_LIBRARY_PATH"
		else
			export LD_LIBRARY_PATH="$AFHT_MOUNT:/lib:/usr/lib"
		fi
	fi
	export PATH="$AFHT_MOUNT:/bin:/usr/bin:/sbin:/usr/sbin${PATH:+:$PATH}"
}

# Called by start_ipc_main when app_01 already mounted SD/afht (no filesystem work).
export_afht_env_if_mounted()
{
	if ! is_mounted "$AFHT_MOUNT"; then
		log "export_env: $AFHT_MOUNT not mounted"
		return 1
	fi
	export_afht_runtime_env
	return 0
}

show_mount_busy_hint()
{
	mp="$1"
	log "umount $mp failed (Resource busy)"
	if pidof nova_main ipc_main ipc_home >/dev/null 2>&1; then
		log "ipc_main is running: use storage_mode_switch apply usb_msc for U-disk mode"
		log "  (uses umount_usb lazy detach; ipc_main keeps running from RAM)"
		log "  do NOT run $0 umount while ipc_main is alive"
	else
		log "hint: cd / ; stop processes using $mp"
	fi
	if command -v fuser >/dev/null 2>&1; then
		fuser -m "$mp" 2>/dev/null || true
	fi
}

mount_sd_afht()
{
	if ! ensure_usb_msc_off; then
		return 1
	fi

	if ! wait_sd_block_dev; then
		log "no SD block device mmcblk1 (waited 10s; check SD card / ak_mci driver)"
		return 1
	fi
	dev=`sd_block_dev`

	mkdir -p "$SD_MOUNT" "$AFHT_MOUNT"

	if is_mounted "$SD_MOUNT"; then
		log "$SD_MOUNT already mounted"
	else
		if mount "$dev" "$SD_MOUNT"; then
			log "mounted $dev on $SD_MOUNT"
		else
			log "mount $dev -> $SD_MOUNT failed"
			return 1
		fi
	fi

	if test ! -f "$SD_MOUNT/$AFHT_IMAGE"; then
		log "missing $SD_MOUNT/$AFHT_IMAGE"
		return 1
	fi

	if is_mounted "$AFHT_MOUNT"; then
		if [ -f /tmp/storage_usb_session ] || lsmod | grep -q g_mass_storage; then
			log "remount $AFHT_MOUNT (drop stale squashfs after USB session)"
			if ! umount "$AFHT_MOUNT" 2>/dev/null; then
				umount -l "$AFHT_MOUNT" 2>/dev/null
				sleep 1
			fi
		else
			export_afht_runtime_env
			return 0
		fi
	fi

	if mount -t squashfs -o ro,loop "$SD_MOUNT/$AFHT_IMAGE" "$AFHT_MOUNT"; then
		log "mounted $SD_MOUNT/$AFHT_IMAGE on $AFHT_MOUNT"
	else
		log "loop mount $SD_MOUNT/$AFHT_IMAGE failed"
		return 1
	fi

	export_afht_runtime_env
	log "runtime env ready LD_LIBRARY_PATH PATH tslib"
	return 0
}

try_umount_strict()
{
	mp="$1"

	if ! is_mounted "$mp"; then
		return 0
	fi
	if umount "$mp" 2>/dev/null; then
		log "umounted $mp"
		return 0
	fi
	show_mount_busy_hint "$mp"
	return 1
}

# Full umount: ipc_main must be stopped. WiFi does not use /mnt/afht/lib.
umount_sd_afht()
{
	if pidof nova_main ipc_main ipc_home >/dev/null 2>&1; then
		log "refuse umount: ipc_main running (pid $(pidof nova_main ipc_main ipc_home))"
		log "  U-disk mode: storage_mode_switch.sh apply usb_msc"
		return 1
	fi

	sync
	try_umount_strict "$AFHT_MOUNT" || return 1
	sync
	try_umount_strict "$SD_MOUNT" || return 1
	return 0
}

# Lazy umount for USB MSC session: detach /mnt/afht and /mnt/sd from namespace while
# ipc_main keeps running (mapped libs stay in RAM). Required before g_mass_storage.
umount_sd_afht_for_usb()
{
	sync
	if is_mounted "$AFHT_MOUNT"; then
		log "lazy umount $AFHT_MOUNT (ipc_main may keep mapped libs in RAM)"
		if ! umount -l "$AFHT_MOUNT" 2>/dev/null; then
			log "lazy umount $AFHT_MOUNT failed"
			return 1
		fi
		sleep 1
	fi

	if is_mounted "$SD_MOUNT"; then
		sync
		log "lazy umount $SD_MOUNT"
		if ! umount -l "$SD_MOUNT" 2>/dev/null; then
			log "lazy umount $SD_MOUNT failed"
			return 1
		fi
		sleep 1
	fi

	if is_mounted "$AFHT_MOUNT" || is_mounted "$SD_MOUNT"; then
		log "mount table still shows SD/afht after lazy umount"
		return 1
	fi

	log "SD/afht detached for USB MSC (session)"
	return 0
}

# After USB session / ipc_main stopped: normal umount, lazy only if still busy.
umount_sd_afht_force()
{
	sync
	if is_mounted "$AFHT_MOUNT"; then
		if umount "$AFHT_MOUNT" 2>/dev/null; then
			log "umounted $AFHT_MOUNT"
		elif umount -l "$AFHT_MOUNT" 2>/dev/null; then
			log "lazy umounted $AFHT_MOUNT"
		else
			show_mount_busy_hint "$AFHT_MOUNT"
			return 1
		fi
	fi
	sync
	if is_mounted "$SD_MOUNT"; then
		if umount "$SD_MOUNT" 2>/dev/null; then
			log "umounted $SD_MOUNT"
		elif umount -l "$SD_MOUNT" 2>/dev/null; then
			log "lazy umounted $SD_MOUNT"
		else
			show_mount_busy_hint "$SD_MOUNT"
			return 1
		fi
	fi
	return 0
}

usage()
{
	echo "Usage: $0 <mount|umount|umount_usb|umount_force|export_env|wait_sd>"
	echo "       mount       Mount SD + afht.sqsh4, export env (alias: install)"
	echo "       export_env  Export env only when SD/afht already mounted (start_ipc_main)"
	echo "       umount      Umount afht+SD (ipc_main must be stopped)"
	echo "       umount_usb  Lazy umount for USB MSC (ipc_main may keep running)"
	echo "       umount_force Umount with lazy fallback (after USB session / cleanup)"
	echo "       wait_sd     Wait until mmc block device exists and is readable"
	echo ""
	echo "Source from current shell so export persists:"
	echo "  . $0 mount"
}

mount_sd_afht_main()
{
	MODE=$1
	if test -z "$MODE"; then
		MODE=mount
	fi

	if test "$MODE" = "mount" || test "$MODE" = "install"; then
		mount_sd_afht
	elif test "$MODE" = "export_env"; then
		export_afht_env_if_mounted
	elif test "$MODE" = "umount" || test "$MODE" = "uninstall"; then
		umount_sd_afht
	elif test "$MODE" = "umount_usb"; then
		umount_sd_afht_for_usb
	elif test "$MODE" = "umount_force"; then
		umount_sd_afht_force
	elif test "$MODE" = "wait_sd"; then
		wait_sd_block_dev && wait_sd_block_open
	else
		usage
		return 1
	fi
}

# Sourced from main.sh or executed directly.
mount_sd_afht_main "$@"
