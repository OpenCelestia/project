#!/bin/sh
# P2P 自动连接脚本
# 参数: $1=接口名, $2=事件类型
 
IFNAME=$1
CMD=$2
 
# 配置参数
TARGET_DEVICE_NAME="DIRECT-AIC-IoT-P2P"  # 目标设备名称
LOG_FILE="/var/log/p2p_auto_connect.log"
LOCK_FILE="/tmp/p2p_connect.lock"
WPA_CLI_PATH="/mnt/test/p2p_test/wpa_cli" # wpa_cli工具的绝对路径
 
# 日志函数
log() {
    #echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $LOG_FILE
    echo $1
}
 
# 防止脚本重入
if [ -f $LOCK_FILE ]; then
    log "Script already running, exiting"
    exit 0
fi
touch $LOCK_FILE
 
# 主事件处理
case "$CMD" in
    "P2P-DEVICE-FOUND")
        # 提取设备信息
        DEV_INFO="$3"
        DEV_MAC=$(echo "$DEV_INFO" | grep -oE '^[0-9a-fA-F:]{17}')
        DEV_NAME_STR="$6"
        DEV_NAME=$(echo "$DEV_NAME_STR" | sed -n "s/.*name=['\"]\([^'\"]*\)['\"].*/\1/p")
 
        log "Found device: $DEV_NAME ($DEV_MAC)"
         
        # 检查是否为目标设备
        if [ "$DEV_NAME" = "$TARGET_DEVICE_NAME" ]; then
            log "Target device detected! Attempting connection..."
             
            # 停止当前扫描
            $WPA_CLI_PATH -i $IFNAME p2p_stop_find >> $LOG_FILE 2>&1
             
            # 发起P2P连接
            CONNECT_RESULT=$($WPA_CLI_PATH -i $IFNAME p2p_connect $DEV_MAC pbc join)
             
            if echo "$CONNECT_RESULT" | grep -q "OK"; then
                log "Connection initiated successfully"
            else
                log "Connection failed: $CONNECT_RESULT"
            fi
        fi
        ;;
         
    "P2P-GROUP-STARTED")
        # $3=组接口名, $4=角色, $5=SSID
        log "P2P group started: $3, Role: $4"
        
        if [ "$4" = "client" ]; then
            # 作为客户端获取IP
            log "Obtaining IP address..."
            if test ! -e /fast/usr/sbin/udhcpc ; then
                ln -s /bin/busybox /fast/usr/sbin/udhcpc
            fi
            /fast/usr/sbin/udhcpc -t 30 -T 1 -i $3 >> $LOG_FILE 2>&1
        fi
        if [ "$4" = "GO" ]; then
        log "Device: GO, udhcpd started"
        ifconfig p2p0 192.168.100.1
        #ifconfig mon.p2p0 192.168.100.10
        
        #/usr/sbin/wpa_cli -p /var/run/p2p_supplicant wps_pbc
        
        # /usr/sbin/dnsmasq --interface=p2p0 --no-daemon --no-resolv --leasefile-ro --no-poll --dhcp-range=192.168.100.2,192.168.100.254,12  --user=root --group=root &
        
        mkdir -p /var/lib/misc/
        touch /var/lib/misc/udhcpd.leases
        if test ! -e /fast/usr/sbin/udhcpd ; then
            ln -s /bin/busybox /fast/usr/sbin/udhcpd
        fi
        #/fast/usr/sbin/udhcpd -S /etc/config/udhcpd_p2p.conf &
        /fast/usr/sbin/static_udhcpd p2p0 &

        fi
        ;;
         
    "P2P-GROUP-FORMATION-FAILURE")
        log "Group formation failed! Reason: $3"
        ;;
         
    "AP-STA-CONNECTED")
        log "STA connected to our soft AP: $3"
        log "Turn ON the led"
        echo 1 > /sys/devices/platform/leds/leds/state_led/brightness
        ;;
    "AP-STA-DISCONNECTED")
        log "STA disconnected from our soft AP: $3"
        log "Turn OFF the led"   
		echo "on 200 200" > /sys/devices/platform/leds/leds/state_led/flash        
        ;;
        
    "P2P-PROV-DISC-SHOW-PIN")
        log "Method: WPS_PIN"
        /fast/usr/sbin/wpa_cli -p /var/run/p2p_supplicant wps_pin any 1234
        ;;

    "P2P-PROV-DISC-PBC-REQ")
        log "Method: WPS_PBC"
        /fast/usr/sbin/wpa_cli -p /var/run/p2p_supplicant wps_pbc
        ;;
    "CONNECTED")
        log "Connected to infrastructure network"
        ;;
         
    "DISCONNECTED")
        log "Disconnected from network"
        ;;
esac
 
# 清理锁文件
rm -f $LOCK_FILE
exit 0
