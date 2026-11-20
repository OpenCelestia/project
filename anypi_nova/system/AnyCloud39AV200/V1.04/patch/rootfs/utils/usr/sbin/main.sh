#!/bin/sh

function get_partition_dev()
{
	mtdblockid=`cat /proc/mtd| grep "$1"| grep -E -o "mtd[0-9]+" | grep -E -o "[0-9]+"`
	if [ "$mtdblockid" != "" ];then
		echo "/dev/mtdblock$mtdblockid"
	else
		echo ""
	fi
}

#start syslogd & klogd, log rotated 3 files(200KB) to /var/log/messages
syslogd -D -n -O /var/log/messages -s 200 -b 3 & # -l prio
klogd -n & # -c prio

ifconfig lo 127.0.0.1

dmesg > /tmp/start_message

echo 2048 > /proc/sys/vm/min_free_kbytes
echo "/tmp/core_%e_%p_%t" > /proc/sys/kernel/core_pattern

# SARADC: Nova battery SoC via AIN0 / in_voltage0_raw
if test -e "/usr/modules/ak_saradc.ko" ; then
	insmod /usr/modules/ak_saradc.ko
fi
insmod /usr/modules/ak_i2c.ko
if test -e "/usr/modules/ak_efuse.ko" ; then
	insmod /usr/modules/ak_efuse.ko
fi
if test -e "/usr/modules/ak_uio.ko" ; then
	insmod /usr/modules/ak_uio.ko
fi

/usr/sbin/service.sh start &
