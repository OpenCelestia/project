#! /bin/sh

cd /tmp/nfs/av200/wifi_p2p
# cd /tmp/nfs/av200/sh/
./wifi_driver_av200_atbm6162.sh

# cd /tmp/nfs/av200/bin/
# rm -f /etc/config/wpa_p2p_group.conf
# cp /tmp/nfs/av200/wifi_p2p/wpa_p2p_group.conf /etc/config
./wpa_supplicant -Dnl80211 -i p2p0 -c /etc/config/wpa_p2p_group.conf -B

# 查看本机p2p mac地址
ifconfig -a

# 查看/etc/config/wpa_p2p_group.conf, 若没有network节点，需要跑persistent自动生成节点，当第一次连接成功，会生成p2p_client_list
# 重跑时，选择有p2p_client_list的network节点，persistent=0指定该节点，实现快速连接
# ./wpa_cli -p /var/run/p2p_supplicant p2p_group_add persistent
./wpa_cli -p /var/run/p2p_supplicant p2p_group_add persistent=0
# ./wpa_cli -p /var/run/p2p_supplicant p2p_group_add persistent=1

ifconfig p2p0 192.168.100.1
ifconfig mon.p2p0 192.168.100.10
./dnsmasq --interface=p2p0 --no-daemon --no-resolv --leasefile-ro --no-poll --dhcp-range=192.168.100.2,192.168.100.254,12  --user=root --group=root &

# ./wpa_cli -p /var/run/p2p_supplicant wps_pin any 1234
./wpa_cli -p /var/run/p2p_supplicant wps_pbc


# ./wpa_cli -p /var/run/p2p_supplicant p2p_peers

# ./wpa_cli -p /var/run/p2p_supplicant stat
