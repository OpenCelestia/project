#!/bin/sh
# KM01W action cam may have no eth0; skip wired DHCP when /proc/eth0 is absent.
if [ -f /proc/eth0 ]; then
	phy_onboard=`cat /proc/eth0 2>/dev/null | grep phy_onboard | awk -F" " '{print $2}'`
	if [ "$phy_onboard" = "mounted" ]; then
		udhcpc&
	fi
fi

run_config_sh()
{
	if [ ! -f "$1" ]; then
		return 1
	fi
	if [ -x "$1" ]; then
		"$1"
	else
		sh "$1"
	fi
}

if [ -f "/data/app.sh" ]; then
	echo "/data/app.sh"
	run_config_sh /data/app.sh
elif [ -f "/etc/config/app.sh" ]; then
	echo "/etc/config/app.sh"
	run_config_sh /etc/config/app.sh
fi
