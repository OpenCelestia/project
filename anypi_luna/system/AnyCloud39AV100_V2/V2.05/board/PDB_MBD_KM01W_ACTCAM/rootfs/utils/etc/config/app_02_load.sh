#!/bin/sh
# Fast-boot phase-2: modules that can wait until luna_main starts (not in app.sh / app_01).
# Phase-1 (app.sh at boot): touch, NPU, WiFi — keep boot time short.
# Phase-2 (here, before LVGL): LCD power/backlight + display driver.

# LCD power + backlight (same as main.sh fast-boot path)
if [ -d /sys/class/gpio/gpio7 ]; then
	echo out > /sys/class/gpio/gpio7/direction 2>/dev/null
	echo 0 > /sys/class/gpio/gpio7/value 2>/dev/null
else
	echo 7 > /sys/class/gpio/export 2>/dev/null
	echo out > /sys/class/gpio/gpio7/direction 2>/dev/null
	echo 0 > /sys/class/gpio/gpio7/value 2>/dev/null
fi

if [ ! -c /dev/fb0 ]; then
	if [ -x /etc/config/tft_st7789.sh ]; then
		/etc/config/tft_st7789.sh
	elif [ -f /etc/config/tft_st7789.sh ]; then
		sh /etc/config/tft_st7789.sh
	fi
fi

# Clear residual SPI/fb garbage if UI has not painted yet.
if [ -c /dev/fb0 ]; then
	dd if=/dev/zero of=/dev/fb0 bs=115200 count=1 conv=fsync 2>/dev/null
	echo 0 > /sys/class/graphics/fb0/blank 2>/dev/null
fi

# Power hold GPIO2=1 when sysfs is free (hog may already own the line).
if [ ! -d /sys/class/gpio/gpio2 ]; then
	echo 2 > /sys/class/gpio/export 2>/dev/null
fi
if [ -d /sys/class/gpio/gpio2 ]; then
	echo out > /sys/class/gpio/gpio2/direction 2>/dev/null
	echo 1 > /sys/class/gpio/gpio2/value 2>/dev/null
fi

exit 0
