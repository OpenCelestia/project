#! /bin/sh

cd /tmp/nfs/av200/sh/
./wifi_driver_av200_atbm6162.sh

cd /tmp/nfs/av200/bin/
rm -f /etc/config/wpa_p2p.conf
cp /tmp/nfs/av200/wifi_p2p/wpa_p2p.conf /etc/config
./wpa_supplicant -Dnl80211 -i p2p0 -c /etc/config/wpa_p2p.conf -B

ifconfig p2p0 192.168.100.1
./dnsmasq --interface=p2p0 --no-daemon --no-resolv --leasefile-ro --no-poll --dhcp-range=192.168.100.2,192.168.100.254,12  --user=root --group=root &

./wpa_cli -p /var/run/p2p_supplicant SET wifi_display 1
./wpa_cli -p /var/run/p2p_supplicant WFD_SUBELEM_SET 0 000600111c440032
./wpa_cli -p /var/run/p2p_supplicant P2P_FLUSH
./wpa_cli -p /var/run/p2p_supplicant P2P_SET listen_channel 11
./wpa_cli -p /var/run/p2p_supplicant P2P_LISTEN

sleep 20

# ./wpa_cli -p /var/run/p2p_supplicant p2p_peers

./wpa_cli -p /var/run/p2p_supplicant wps_pbc
./wpa_cli -p /var/run/p2p_supplicant p2p_connect 4e:37:de:f9:39:97 pbc go_intent=6
# 手机nova
./wpa_cli -p /var/run/p2p_supplicant p2p_connect 62:ae:8c:62:de:b5 pbc go_intent=6

# ./wpa_cli -p /var/run/p2p_supplicant stat
