#! /bin/sh
### BEGIN INIT INFO
# File:                sh
# Provides:         driver install/uninstall, operate as station/ap 
# Required-Start:   $
# Required-Stop:
# Default-Start:     
# Default-Stop:
# Short-Description:  wifi script
# Author:            
# Email:             
# Date:                2020-02-28
### END INIT INFO

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin
MODE=$1
usage()
{
    echo "Usage: $0 MODE"
    echo "       MODE:    ap | sta | stop | install "
    echo "               ap         Start wifi as ap role"
    echo "               sta        Start wifi as station role"
    echo "               stop        Stop  wifi "
}

wifi_stop()
{
    killall wpa_supplicant
    killall udhcpc
    killall udhcpd
    killall hostapd
    sleep 2
    rmmod atbm6032.ko
    sleep 2
    rmmod ak_hcd
    rmmod usbcore
    rmmod usb-common
    rmmod cfg80211
}

driver_install()
{
    wifi_stop
    modprobe cfg80211
    modprobe usb-common
    modprobe nls_base
    modprobe usbcore
    insmod /usr/modules/ak_hcd.ko
    modprobe libarc4
    insmod /usr/modules/atbm6032.ko
    sleep 3
}

####### main
case "$MODE" in
    ap)
        driver_install
        ifconfig wlan0  172.14.10.1
        mkdir -p /var/lib/misc/
        touch /var/lib/misc/udhcpd.leases
	rm -f /dev/random
	ln -s  /dev/urandom  /dev/random
        udhcpd -S /etc/config/udhcpd.conf &
        hostapd -dd -S -B /etc/config/hostapd.conf
        ;;
    sta)
        driver_install
        WPA_CFG=/etc/config/wpa_supplicant.conf
        if [ ! -f "$WPA_CFG" ]; then
            # STA ssid/psk in settings.json; HAL rewrites conf on connect.
            mkdir -p /etc/config
            cat > "$WPA_CFG" <<'EOF'
ctrl_interface=/var/run/wpa_supplicant
update_config=1
EOF
        fi
        wpa_supplicant -Dnl80211 -i wlan0 -c "$WPA_CFG" -B
        sleep 1
        if [ -x /usr/sbin/udhcpc_wlan.sh ]; then
            udhcpc -i wlan0 -s /usr/sbin/udhcpc_wlan.sh
        else
            udhcpc -i wlan0
        fi
        ;;
    install)
        driver_install
        ;;
    stop)
        wifi_stop
        ;;
    *)
        usage
        ;;
esac
exit 0

