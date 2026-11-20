/usr/sbin/ov8856.sh
insmod /usr/modules/ak_venc_adapter.ko
insmod /usr/modules/ak_venc_bridge.ko
insmod /lib/modules/5.10.111/kernel/drivers/base/firmware_loader/firmware_class.ko path=/mnt/install/model/
insmod /usr/modules/ak_pcm.ko
insmod /usr/modules/ak_npu.ko
echo nnn camera net start
uptime
# Station: settings.json wifi{} (ssid/psk); wpa_supplicant.conf is runtime-generated
#if [ -x /usr/sbin/wifi_driver.sh ]; then
#    /usr/sbin/wifi_driver.sh sta &
#fi
echo nnn camera net end
uptime
exit
