#!/bin/sh

insmod_if_absent()
{
	ko="$1"
	shift
	if [ ! -f "$ko" ]; then
		echo "ov8856: missing $ko" >&2
		return 1
	fi
	base=`basename "$ko" .ko`
	if lsmod | grep -q "^${base} "; then
		return 0
	fi
	if ! insmod "$ko" "$@"; then
		echo "ov8856: insmod failed: $ko $*" >&2
		return 1
	fi
	return 0
}

install()
{
	# Fail loud on critical path so boot logs show why /dev/vicap-* is missing.
	insmod_if_absent /usr/modules/ak_vi.ko mp_logic_open_num=1 || return 1
	# Vega 4-lane: AF sensor_ov8856.ko (init table 0x3018=0x72 / 1440Mbps)
	# + isp_ov8856_7.100.25042408.conf. HAL stays interface_mode=2
	# (VI_INTF_MIPI_2); lane count is MIPI_LANES. This ko takes addr0_x,
	# not SENSOR_I2C_ADDR. Params match app_af.sh (no check_id).
	# Mux is vega's 0x58D10.
	insmod_if_absent /usr/modules/sensor_ov8856.ko addr0_x=0x10 MIPI_LANES_SWAP=0x58D10 MIPI_LANES=4 MAX_FPS=20 || return 1
	# AF VCM before vicap/isp/pp so v4l2_async can bind to VI vcm-ep
	insmod_if_absent /usr/modules/vcm_fp5510.ko || echo "ov8856: WARN vcm_fp5510 not loaded" >&2
	insmod_if_absent /usr/modules/ak_vicap.ko || return 1
	insmod_if_absent /usr/modules/ak_isp.ko || return 1
	insmod_if_absent /usr/modules/ak_pp.ko || return 1

	rm -f /etc/config/isp_ov8856_mipi_2lane_av200.conf
	if test ! -f /etc/config/isp_ov8856_mipi_4lane_av200.conf ; then
		rm -f /etc/config/isp_ov8856_mipi_*.conf
		cp /etc/isp_ov8856_mipi_4lane_av200.conf /etc/config/
	fi
	return 0
}

uninstall()
{
	rmmod /usr/modules/vcm_fp5510.ko 2>/dev/null || true
	rmmod /usr/modules/ak_pp.ko
	rmmod /usr/modules/ak_isp.ko
	rmmod /usr/modules/ak_vicap.ko
	rmmod /usr/modules/ak_vi.ko
	rmmod /usr/modules/sensor_ov8856.ko
}

usage()
{
	echo "usage :"
	echo "    ./ov8856.sh <install/uninstall>"
	echo "    default : install"
}

if test $# -gt 1 ; then
	usage
elif test $# -eq 0 ; then
	install
elif test $# -eq 1 ; then
	if test $1 = "install" ; then
		install
	elif test $1 = "uninstall" ; then
		uninstall
	else
		usage
	fi
fi
