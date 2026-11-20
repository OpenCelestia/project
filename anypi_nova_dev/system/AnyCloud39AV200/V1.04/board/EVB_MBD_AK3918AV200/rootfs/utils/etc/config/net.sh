echo nnn net start   
uptime
insmod /usr/modules/ak_eth.ko
udhcpc
route add default eth0
route add default gw 172.16.10.1
echo nnn net end   
uptime

