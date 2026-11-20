#! /bin/sh

DEVICE_NAME="$1"
LOCK_FILE="/tmp/mci_shared.lock"

wait_for_p2p0_original_style() {
    local timeout=${1:-10}  # 超时时间(秒)
    local start_time=$(date +%s)
    
    # echo "Waiting for p2p0..."
    
    while true; do
        # 检查超时
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -ge $timeout ]; then
            echo "Timeout: p2p0 not found within ${timeout} seconds"
            return 1
        fi
        
        # 原始检查逻辑
        if ip link show p2p0 &> /dev/null; then
            echo "p2p0 found"
            break
        else
            sleep 0.02
        fi
    done
    
    return 0
}

p2p_go()
{
    echo "in app_go_group.sh"

    rm -f /dev/random
    ln -s  /dev/urandom  /dev/random

    while true; do
        if [ ! -f $LOCK_FILE ]; then
            echo "mci2 bind"
            echo d2130000.mmc2 > /sys/bus/platform/drivers/akmci/bind
            break
        else
            sleep 0.02
        fi
    done

    #ACB_MBD_T6_KM02G_V1.0.0 P2P LED
    echo 72 > /sys/class/gpio/export
    echo "out" > /sys/class/gpio/gpio72/direction

    # ln -s /usr/lib/libc.so /lib/ld-musl-riscv64.so.1
    echo "wifi ko insmod"
    insmod /fast/usr/modules/firmware_class.ko path=/usr/sbin
    insmod /fast/usr/modules/cfg80211.ko
    insmod /fast/usr/modules/aic8800_bsp.ko aic_fw_path=/fast/usr/lib/firmware
    insmod /fast/usr/modules/aic8800_fdrv.ko
    echo "insmod done"

    if test ! -e /lib/ld-musl-riscv64.so.1 ; then
        ln -s /fast/usr/lib/libc.so /lib/ld-musl-riscv64.so.1
    fi

    # wait device node
    wait_for_p2p0_original_style 3

    /fast/usr/sbin/iwpriv p2p0 common bus_awake,0
    # killall wpa_supplicant
    # cd /usr/sbin/
    cd /mnt/
    # rm -f /etc/config/wpa_p2p_group.conf
    # cp /tmp/nfs/av200/wifi_p2p/wpa_p2p_group.conf /etc/config
    echo "start wpa"
    /fast/usr/sbin/wpa_supplicant -Dnl80211 -i p2p0 -c /etc/config/wpa_p2p_group.conf -B 
    /fast/usr/sbin/wpa_cli -p /var/run/p2p_supplicant set device_name "$DEVICE_NAME"
    echo "########### SET P2P0 device name $DEVICE_NAME ################"
    # 查看本机p2p mac地址
    # ifconfig -a

    /fast/usr/sbin/wpa_cli -p /var/run/p2p_supplicant -a /fast/usr/sbin/p2p_auto_config.sh -B

    # 查看/etc/config/wpa_p2p_group.conf, 若没有network节点，需要跑persistent自动生成节点，当第一次连接成功，会生成p2p_client_list
    # 重跑时，选择有p2p_client_list的network节点，persistent=0指定该节点，实现快速连接
    # echo "########### wpa_cli p2p_group_add ################"
    # 查看/etc/config/wpa_p2p_group.conf, 若没有network节点，需要跑persistent自动生成节点，当第一次连接成功，会生成p2p_client_list
    # 重跑时，选择有p2p_client_list的network节点，persistent=0指定该节点，实现快速连接
    if grep -q "^network=" /etc/config/wpa_p2p_group.conf 2>/dev/null; then
        /fast/usr/sbin/wpa_cli -p /var/run/p2p_supplicant p2p_group_add persistent=0
        echo "/usr/sbin/wpa_cli -p /var/run/p2p_supplicant p2p_group_add persistent=0"
    else
        /fast/usr/sbin/wpa_cli -p /var/run/p2p_supplicant p2p_group_add persistent
        echo "/usr/sbin/wpa_cli -p /var/run/p2p_supplicant p2p_group_add persistent"
    fi
    echo "wpa done"
    /fast/usr/sbin/iwpriv p2p0 common ap_alive_time,50
    echo "on 200 200" > /sys/devices/platform/leds/leds/state_led/flash
    # echo "########### wpa_cli status ################"
    # /usr/sbin/wpa_cli -p /var/run/p2p_supplicant status
    # echo "########### wpa_cli wps_pbc ################"
    # /usr/sbin/wpa_cli -p /var/run/p2p_supplicant wps_pbc
    # /usr/sbin/dnsmasq --interface=p2p0 --no-daemon --no-resolv --leasefile-ro --no-poll --dhcp-range=192.168.100.2,192.168.100.254,12  --user=root --group=root &

    # /usr/sbin/wpa_cli -p /var/run/p2p_supplicant p2p_peers

    # /usr/sbin/wpa_cli -p /var/run/p2p_supplicant stat
}

p2p_go
