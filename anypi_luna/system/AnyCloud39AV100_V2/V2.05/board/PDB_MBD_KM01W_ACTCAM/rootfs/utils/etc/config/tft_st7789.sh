#!/bin/sh

KER_VER=`uname -r`

insmod /lib/modules/${KER_VER}/kernel/drivers/video/fbdev/core/fb.ko
insmod /lib/modules/${KER_VER}/kernel/drivers/video/backlight/backlight.ko

insmod /lib/modules/${KER_VER}/kernel/drivers/video/fbdev/core/fb_sys_fops.ko
insmod /lib/modules/${KER_VER}/kernel/drivers/video/fbdev/core/syscopyarea.ko
insmod /lib/modules/${KER_VER}/kernel/drivers/video/fbdev/core/sysfillrect.ko
insmod /lib/modules/${KER_VER}/kernel/drivers/video/fbdev/core/sysimgblt.ko
insmod /lib/modules/${KER_VER}/kernel/drivers/staging/fbtft/fbtft.ko
insmod /lib/modules/${KER_VER}/kernel/drivers/staging/fbtft/fb_st7789.ko
