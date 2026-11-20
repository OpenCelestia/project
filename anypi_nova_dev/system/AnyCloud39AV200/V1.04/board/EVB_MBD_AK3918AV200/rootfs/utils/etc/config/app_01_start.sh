export TSLIB_CONFFILE=/etc/config/ts.rgb.conf
export TSLIB_CALIBFILE=/etc/config/ts_calibrate.rgb.conf
export TSLIB_PLUGINDIR=/usr/bin/tslib/lib/ts
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/bin/tslib/lib:/lib:/usr/lib
export TSLIB_TSDEVICE=/dev/input/event1
export TSLIB_CONSOLEDEVICE=none
# POSIX: CST-8 = China Standard Time (UTC+8). Used by log_info / OSD / UI localtime.
export TZ="${TZ:-CST-8}"

# OSD font lives under /usr/gui/font only; drop legacy copy on config partition
rm -f /etc/config/ak_font_16.bin

insmod /usr/modules/ak_saradc.ko
insmod /usr/modules/ak_adc_key.ko
insmod /usr/modules/ts_ft5426g.ko

insmod /usr/modules/ak_ipu.ko
insmod /usr/modules/fb.ko
insmod /usr/modules/ak_lcd.ko

#/etc/config/app2.sh
# Main process: CONFIG_APP_MAIN_TARGET=nova_main → /usr/sbin/nova_main
/usr/sbin/nova_main &
#/etc/config/net.sh &
/usr/sbin/wifi_driver.sh sta &
uptime


/usr/sbin/gc5603.sh
insmod /usr/modules/ak_venc_adapter.ko
insmod /usr/modules/ak_venc_bridge.ko
insmod /lib/modules/5.10.111/kernel/drivers/base/firmware_loader/firmware_class.ko path=/usr/model/
insmod /usr/modules/ak_pcm.ko
insmod /usr/modules/ak_npu.ko
echo nnn camera net start
uptime