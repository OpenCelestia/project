/usr/sbin/gc5603.sh
insmod /usr/modules/ak_venc_adapter.ko
insmod /usr/modules/ak_venc_bridge.ko
insmod /lib/modules/5.10.111/kernel/drivers/base/firmware_loader/firmware_class.ko path=/usr/model/
insmod /usr/modules/ak_pcm.ko
insmod /usr/modules/ak_npu.ko
echo nnn camera net start
uptime
#/etc/config/net.sh &
#/usr/sbin/wifi_driver.sh install &
#/usr/sbin/wifi_driver.sh sta &
#echo nnn camera net end   
#uptime
exit
