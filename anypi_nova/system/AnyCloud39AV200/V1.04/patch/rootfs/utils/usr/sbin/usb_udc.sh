#!/bin/sh
# USB gadget mass-storage (export SD to PC). Mutually exclusive with local /mnt mount.
# Pair with mount_install.sh:
#   usb_udc.sh uninstall  ->  mount_install.sh mount
#   mount_install.sh umount  ->  usb_udc.sh install

SD_MOUNT=/mnt
INSTALL_MOUNT=/mnt/install

log()
{
	echo "[usb_udc] $*"
}

is_mounted()
{
	mount | grep -q " on $1 "
}

is_sd_mounted_local()
{
	is_mounted "$SD_MOUNT" || is_mounted "$INSTALL_MOUNT"
}

install()
{
	if is_sd_mounted_local; then
		log "ERROR: $SD_MOUNT or $INSTALL_MOUNT is mounted"
		log "       umount SD first: . /usr/sbin/mount_install.sh umount_usb"
		return 1
	fi

	if lsmod | grep -q g_mass_storage; then
		log "g_mass_storage already loaded"
		return 0
	fi

	modprobe usb-common
	modprobe udc-core
	insmod /usr/modules/ak_udc.ko
	modprobe libcomposite
	modprobe usb_f_mass_storage

	# ACTION board: SD is mmcblk1; keep fallbacks for other layouts.
	if [ -e /dev/mmcblk1p1 ]; then
		modprobe g_mass_storage file=/dev/mmcblk1p1 stall=0 removable=1
	elif [ -e /dev/mmcblk1 ]; then
		modprobe g_mass_storage file=/dev/mmcblk1 stall=0 removable=1
	elif [ -e /dev/mmcblk0p1 ]; then
		modprobe g_mass_storage file=/dev/mmcblk0p1 stall=0 removable=1
	elif [ -e /dev/mmcblk0 ]; then
		modprobe g_mass_storage file=/dev/mmcblk0 stall=0 removable=1
	else
		log "ERROR: no mmc block device for USB MSC"
		uninstall
		return 1
	fi

	if ! lsmod | grep -q g_mass_storage; then
		log "ERROR: g_mass_storage load failed"
		return 1
	fi

	log "USB mass-storage installed"
	return 0
}

uninstall()
{
	if ! lsmod | grep -q g_mass_storage; then
		return 0
	fi

	# Soft-release lun file before rmmod — host still mounting the volume
	# makes modprobe -r / rmmod hang the whole SoC (serial dies).
	if [ -e /sys/module/g_mass_storage/parameters/file ]; then
		echo "" > /sys/module/g_mass_storage/parameters/file 2>/dev/null || true
		sleep 1
	fi

	if lsmod | grep -q g_mass_storage; then
		modprobe -r g_mass_storage 2>/dev/null || true
	fi
	if lsmod | grep -q usb_f_mass_storage; then
		modprobe -r usb_f_mass_storage 2>/dev/null || true
	fi
	if lsmod | grep -q libcomposite; then
		modprobe -r libcomposite 2>/dev/null || true
	fi

	# Only rmmod UDC after gadget functions are gone; otherwise can hard-lock.
	if ! lsmod | grep -q g_mass_storage && ! lsmod | grep -q usb_f_mass_storage; then
		if lsmod | grep -q ak_udc; then
			rmmod ak_udc 2>/dev/null || true
		fi
		modprobe -r udc-core 2>/dev/null || true
		modprobe -r usb-common 2>/dev/null || true
	fi

	if lsmod | grep -q g_mass_storage; then
		log "WARN: g_mass_storage still loaded (eject USB on PC and retry)"
		return 1
	fi

	# mmcblk1 may not be openable immediately after gadget teardown.
	sleep 1

	log "USB mass-storage uninstalled"
	return 0
}

usage()
{
	echo "Usage: $0 <install|uninstall>"
	echo "       install    Export SD via USB (requires /mnt umounted)"
	echo "       uninstall  Stop USB MSC (required before mount_install.sh mount)"
	echo "       default: install"
}

main()
{
	MODE=$1
	if [ -z "$MODE" ]; then
		MODE=install
	fi

	case "$MODE" in
	install)
		install
		;;
	uninstall)
		uninstall
		;;
	*)
		usage
		return 1
		;;
	esac
}

main "$@"
