#!/bin/sh
# Mount SD (mmc1) at /mnt so /mnt/install/... is available; export tslib / LD_LIBRARY_PATH for ipc_main.
# Pair with usb_udc.sh: uninstall MSC first, then:
#   . /usr/sbin/mount_install.sh mount
#
# Must be sourced (.) from the shell that will run ipc_main so export takes effect:
#   . /usr/sbin/mount_install.sh mount

MNT_ROOT=/mnt
INSTALL_MOUNT=/mnt/install
INSTALL_SONAME_DIR=/tmp/install_soname

log()
{
	echo "[mount_install] $*"
}

is_mounted()
{
	mount | grep -q " on $1 "
}

# Rootfs fstab often does "tmpfs on /mnt" via mount -av before SD is ready.
# That empty tmpfs makes is_mounted(/mnt) true and blocks SD mount.
is_tmpfs_on_mnt()
{
	grep -q " $MNT_ROOT tmpfs " /proc/mounts 2>/dev/null && return 0
	mount 2>/dev/null | grep -q "tmpfs on $MNT_ROOT " && return 0
	return 1
}

# True when /mnt already shows install/ and is not the boot tmpfs placeholder.
is_sd_install_ready()
{
	is_mounted "$MNT_ROOT" || return 1
	is_tmpfs_on_mnt && return 1
	test -d "$INSTALL_MOUNT"
}

# Drop placeholder / stale mount so SD (mmcblk1p1) can occupy /mnt.
umount_mnt_if_not_install()
{
	if ! is_mounted "$MNT_ROOT"; then
		return 0
	fi
	if is_sd_install_ready; then
		return 0
	fi
	if is_tmpfs_on_mnt; then
		log "umount boot tmpfs on $MNT_ROOT before SD mount"
	else
		log "umount $MNT_ROOT (no install/) before remount SD"
	fi
	if umount "$MNT_ROOT" 2>/dev/null; then
		return 0
	fi
	if umount -l "$MNT_ROOT" 2>/dev/null; then
		sleep 1
		return 0
	fi
	log "umount stale $MNT_ROOT failed"
	return 1
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

export_install_runtime_env()
{
	# Prefer flash /usr for tslib + libs; keep SD install on LD path for extra apps.
	# Volc RTC Lite lives under apps/volc_engine/lib (ipc_main DT_NEEDED).
	VOLC_RTC_LIBDIR="$INSTALL_MOUNT/apps/volc_engine/lib"
	export TSLIB_CONFFILE=/etc/config/ts.rgb.conf
	export TSLIB_CALIBFILE=/etc/config/ts_calibrate.rgb.conf
	if test -d /usr/lib/ts; then
		export TSLIB_PLUGINDIR=/usr/lib/ts
	else
		export TSLIB_PLUGINDIR="$INSTALL_MOUNT/lib/ts"
	fi
	export TSLIB_TSDEVICE=/dev/input/event0
	export TSLIB_CONSOLEDEVICE=none

	if test -d "$INSTALL_MOUNT/lib"; then
		if test ! -e "$INSTALL_MOUNT/lib/libiconv.so.2" && test ! -e /usr/lib/libiconv.so.2; then
			mkdir -p "$INSTALL_SONAME_DIR"
			for f in "$INSTALL_MOUNT"/lib/*.so.*; do
				if test -f "$f"; then
					bn=`basename "$f"`
					soname=`echo "$bn" | sed 's/\..*$//'`
					if test ! -e "$INSTALL_SONAME_DIR/$soname"; then
						ln -sf "$f" "$INSTALL_SONAME_DIR/$soname"
					fi
				fi
			done
			if test -n "$LD_LIBRARY_PATH"; then
				export LD_LIBRARY_PATH="/usr/lib:/lib:$VOLC_RTC_LIBDIR:$INSTALL_SONAME_DIR:$INSTALL_MOUNT/lib:$INSTALL_MOUNT:$LD_LIBRARY_PATH"
			else
				export LD_LIBRARY_PATH="/usr/lib:/lib:$VOLC_RTC_LIBDIR:$INSTALL_SONAME_DIR:$INSTALL_MOUNT/lib:$INSTALL_MOUNT"
			fi
		else
			if test -n "$LD_LIBRARY_PATH"; then
				export LD_LIBRARY_PATH="/usr/lib:/lib:$VOLC_RTC_LIBDIR:$INSTALL_MOUNT/lib:$INSTALL_MOUNT:$LD_LIBRARY_PATH"
			else
				export LD_LIBRARY_PATH="/usr/lib:/lib:$VOLC_RTC_LIBDIR:$INSTALL_MOUNT/lib:$INSTALL_MOUNT"
			fi
		fi
	else
		if test -n "$LD_LIBRARY_PATH"; then
			export LD_LIBRARY_PATH="/usr/lib:/lib:$VOLC_RTC_LIBDIR:$INSTALL_MOUNT:$LD_LIBRARY_PATH"
		else
			export LD_LIBRARY_PATH="/usr/lib:/lib:$VOLC_RTC_LIBDIR:$INSTALL_MOUNT"
		fi
	fi
	export PATH="/usr/sbin:/usr/bin:/sbin:/bin:$INSTALL_MOUNT${PATH:+:$PATH}"
}

# Called by start_ipc_main when app_01 already mounted /mnt (no filesystem work).
export_install_env_if_mounted()
{
	if ! is_sd_install_ready; then
		log "export_env: $INSTALL_MOUNT not ready (need SD on $MNT_ROOT, not tmpfs)"
		return 1
	fi
	export_install_runtime_env
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

mount_install()
{
	if ! ensure_usb_msc_off; then
		return 1
	fi

	if ! wait_sd_block_dev; then
		log "no SD block device mmcblk1 (waited 10s; check SD card / ak_mci driver)"
		return 1
	fi
	dev=`sd_block_dev`

	mkdir -p "$MNT_ROOT"

	# Already a good SD install mount: nothing to do.
	if is_sd_install_ready; then
		export_install_runtime_env
		return 0
	fi

	# USB session / placeholder tmpfs / empty mount: must clear /mnt first.
	if is_mounted "$MNT_ROOT"; then
		if [ -f /tmp/storage_usb_session ] || lsmod | grep -q g_mass_storage; then
			log "remount $MNT_ROOT (drop stale mount after USB session)"
		fi
		if ! umount_mnt_if_not_install; then
			return 1
		fi
	fi

	if ! is_mounted "$MNT_ROOT"; then
	if mount -t vfat -o utf8 "$dev" "$MNT_ROOT" 2>/dev/null; then
		log "mount $dev -> $MNT_ROOT (vfat utf8)"
	elif mount "$dev" "$MNT_ROOT"; then
			log "mounted $dev on $MNT_ROOT"
		else
			log "mount $dev -> $MNT_ROOT failed"
			return 1
		fi
	fi

	if test ! -d "$INSTALL_MOUNT"; then
		log "missing $INSTALL_MOUNT (copy install/ to SD root)"
		return 1
	fi

	export_install_runtime_env
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

# Full umount: ipc_main must be stopped.
umount_install()
{
	if pidof nova_main ipc_main ipc_home >/dev/null 2>&1; then
		log "refuse umount: ipc_main running (pid $(pidof nova_main ipc_main ipc_home))"
		log "  U-disk mode: storage_mode_switch.sh apply usb_msc"
		return 1
	fi

	sync
	try_umount_strict "$MNT_ROOT" || return 1
	return 0
}

# Lazy umount for USB MSC session: detach /mnt while ipc_main may keep mapped libs in RAM.
umount_install_for_usb()
{
	sync
	if is_mounted "$MNT_ROOT"; then
		log "lazy umount $MNT_ROOT (ipc_main may keep mapped libs in RAM)"
		if ! umount -l "$MNT_ROOT" 2>/dev/null; then
			log "lazy umount $MNT_ROOT failed"
			return 1
		fi
		sleep 1
	fi

	if is_mounted "$MNT_ROOT"; then
		log "mount table still shows $MNT_ROOT after lazy umount"
		return 1
	fi

	log "SD detached for USB MSC (session)"
	return 0
}

# After USB session / ipc_main stopped: normal umount, lazy only if still busy.
umount_install_force()
{
	sync
	if is_mounted "$MNT_ROOT"; then
		if umount "$MNT_ROOT" 2>/dev/null; then
			log "umounted $MNT_ROOT"
		elif umount -l "$MNT_ROOT" 2>/dev/null; then
			log "lazy umounted $MNT_ROOT"
		else
			show_mount_busy_hint "$MNT_ROOT"
			return 1
		fi
	fi
	return 0
}

usage()
{
	echo "Usage: $0 <mount|umount|umount_usb|umount_force|export_env|wait_sd>"
	echo "       mount       Mount SD at /mnt, export env (alias: install)"
	echo "       export_env  Export env only when /mnt already mounted (start_ipc_main)"
	echo "       umount      Umount /mnt (ipc_main must be stopped)"
	echo "       umount_usb  Lazy umount for USB MSC (ipc_main may keep running)"
	echo "       umount_force Umount with lazy fallback (after USB session / cleanup)"
	echo "       wait_sd     Wait until mmc block device exists and is readable"
	echo ""
	echo "Source from current shell so export persists:"
	echo "  . $0 mount"
}

mount_install_main()
{
	MODE=$1
	if test -z "$MODE"; then
		MODE=mount
	fi

	if test "$MODE" = "mount" || test "$MODE" = "install"; then
		mount_install
	elif test "$MODE" = "export_env"; then
		export_install_env_if_mounted
	elif test "$MODE" = "umount" || test "$MODE" = "uninstall"; then
		umount_install
	elif test "$MODE" = "umount_usb"; then
		umount_install_for_usb
	elif test "$MODE" = "umount_force"; then
		umount_install_force
	elif test "$MODE" = "wait_sd"; then
		wait_sd_block_dev && wait_sd_block_open
	else
		usage
		return 1
	fi
}

# Sourced from main.sh or executed directly.
mount_install_main "$@"
