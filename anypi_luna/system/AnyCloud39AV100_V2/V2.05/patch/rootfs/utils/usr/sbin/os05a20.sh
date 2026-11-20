#!/bin/sh

install()
{
    echo "install os05a20 driver"
    /sbin/insmod /usr/modules/ak_vi.ko
    /sbin/insmod /usr/modules/ak_vicap.ko
    /sbin/insmod /usr/modules/ak_isp.ko
    /sbin/insmod /usr/modules/ak_pp.ko
    /sbin/insmod /usr/modules/sensor_os05a20.ko SENSOR_I2C_ADDR=0x36 MIPI_LANES_SWAP=0x858d10 check_id=1
    # /sbin/insmod /mnt/sensor_os05a20.ko SENSOR_I2C_ADDR=0x36 MIPI_LANES_SWAP=0x858d10 check_id=1

    if test ! -f /etc/config/isp_os05a20_mipi_2lane_km01a.conf ; then
        rm /etc/config/isp_*.conf
        cp /etc/isp_os05a20_mipi_2lane_km01a.conf /etc/config/
    fi
}

uninstall()
{
    echo "uninstall os05a20 driver"
    rmmod /usr/modules/ak_pp.ko
    rmmod /usr/modules/ak_isp.ko
    rmmod /usr/modules/ak_vicap.ko
    rmmod /usr/modules/ak_vi.ko
    rmmod /usr/modules/sensor_os05a20.ko
#    v4l2_uninstall
}

usage()
{
    echo "usage :"
    echo "    ./sensor.sh <install/uninstall>"
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