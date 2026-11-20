#!/bin/sh

install()
{
    echo "install gc4053 driver"
#    v4l2_install
    insmod /usr/modules/ak_vi.ko
    insmod /usr/modules/ak_vicap.ko
    insmod /usr/modules/ak_isp.ko
    insmod /usr/modules/ak_pp.ko
    insmod /usr/modules/sensor_gc4053.ko
    if test ! -f /etc/config/isp_gc4053_mipi_2lane_km01a.conf ; then
        rm /etc/config/isp_*.conf
        cp /etc/isp_gc4053_mipi_2lane_km01a.conf /etc/config/
    fi
}

uninstall()
{
    echo "uninstall gc4053 driver"
    rmmod /usr/modules/ak_pp.ko
    rmmod /usr/modules/ak_isp.ko
    rmmod /usr/modules/ak_vicap.ko
    rmmod /usr/modules/ak_vi.ko
    rmmod /usr/modules/sensor_gc4053.ko
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

