#!/bin/sh

install()
{
    insmod /usr/modules/ak_vi.ko
    insmod /usr/modules/sensor_gc5603.ko
    insmod /usr/modules/ak_vicap.ko
    insmod /usr/modules/ak_isp.ko
    insmod /usr/modules/ak_pp.ko
}

uninstall()
{
    rmmod /usr/modules/ak_pp.ko
    rmmod /usr/modules/ak_isp.ko
    rmmod /usr/modules/ak_vicap.ko
    rmmod /usr/modules/ak_vi.ko
    rmmod /usr/modules/sensor_gc5603.ko
}

usage()
{
    echo "usage :" 
    echo "    ./gc5603.sh <install/uninstall>"
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

