#!/bin/sh
#phy_onboard=`cat /proc/eth0 | grep phy_onboard | awk -F" " '{print $2}'`
#if [ "$phy_onboard" = "mounted" ]; then
#udhcpc&
#fi
if [ -f "/data/app_01_start.sh" ]
then
	echo "/data/app_01_start.sh"
	/data/app_01_start.sh
elif [ -f "/etc/config/app_01_start.sh" ]
then
	echo "/etc/config/app_01_start.sh"
	/etc/config/app_01_start.sh
fi
