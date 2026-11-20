#!/bin/bash

pwd_dir=$(dirname $0)

if [ -d `pwd`/../../workspace ]; then
  source $pwd_dir/../../config.mk
else
  source $pwd_dir/../config.mk
fi

# APP_MAIN_TARGET: export from package.sh (CONFIG_APP_MAIN_TARGET).
if [ -z "$APP_MAIN_TARGET" ]; then
	echo "Error: APP_MAIN_TARGET not set. Run package.sh with application built (-a)." >&2
	exit 1
fi
APP_MAIN_PATH="./utils/usr/sbin/$APP_MAIN_TARGET"
if [ ! -f "$APP_MAIN_PATH" ]; then
	echo "Error: $APP_MAIN_PATH not found. Deploy main app to utils/usr/sbin first." >&2
	exit 1
fi

mkdir -p tmp_data
if [ -d rootfs/data ] && [ "$(ls -A rootfs/data 2>/dev/null)" ]; then
	cp -af rootfs/data/. tmp_data/
fi
cp -af "$APP_MAIN_PATH" "tmp_data/$APP_MAIN_TARGET"
./mksquashfs tmp_data/ data.sqsh4 -noappend -comp xz
rm -rf tmp_data
if [ -d rootfs/data ]; then
	rm -rf rootfs/data/*
fi

mkdir -p tmpfs
cp -af rootfs/* tmpfs
rm -rf tmpfs/usr/* tmpfs/etc/config/*
rm -rf tmpfs/etc/isp_*.conf



./mksquashfs tmpfs/ root.sqsh4 -noappend -comp xz

#need change again
echo "fs image..." >&2
if [ "$CONFIG_CELESTIA_FASTSYS" = "y" ]; then
    cp "$APP_MAIN_PATH" "rootfs/usr/sbin/$APP_MAIN_TARGET"
    ./mksquashfs rootfs/usr usr.sqsh4 -noappend -comp xz
elif [ "$CONFIG_SYS_BOOT_MODE" = "FAST" ]; then
    mkdir -p tmpfs_usr
    cp -af rootfs/usr/* tmpfs_usr
    rm -rf tmpfs_usr/modules/*.ko
    rm -rf tmpfs_usr/bin/*_sample
    rm -rf tmpfs_usr/lib/*.so
    rm -rf tmpfs_usr/sbin/*.sh
    rm -rf tmpfs_usr/sbin/yolov5n_v1_640
    rm -rf tmpfs_usr/sbin/test_random_mobilenetsoftmaxcrydet_opt
    rm -rf tmpfs_usr/sbin/upperbody640_opt

    cp scripts/others/main.sh tmpfs_usr/sbin/
    cp rootfs/usr/sbin/service.sh tmpfs_usr/sbin/

    cp rootfs/usr/modules/ak_mci.ko tmpfs_usr/modules/
    cp rootfs/lib/modules/5.10.111/kernel/drivers/mmc/core/* tmpfs_usr/modules/
    cp rootfs/lib/modules/5.10.111/kernel/fs/exfat/* tmpfs_usr/modules/
    cp rootfs/usr/modules/ak_rtc.ko tmpfs_usr/modules/
    cp rootfs/usr/modules/ak_efuse.ko tmpfs_usr/modules/
    cp rootfs/usr/modules/ak_eth.ko tmpfs_usr/modules/
	
	#uvc
    echo "cp uvc driver"
	cp rootfs/lib/modules/5.10.111/kernel/drivers/usb/gadget/legacy/g_ak_aw.ko tmpfs_usr/modules/
    cp rootfs/lib/modules/5.10.111/kernel/drivers/media/common/videobuf2/videobuf2-vmalloc.ko tmpfs_usr/modules/
    cp rootfs/lib/modules/5.10.111/kernel/drivers/usb/gadget/legacy/g_mass_storage.ko tmpfs_usr/modules/
    cp rootfs/lib/modules/5.10.111/kernel/fs/configfs/configfs.ko tmpfs_usr/modules/
    cp rootfs/usr/modules/ak_udc.ko tmpfs_usr/modules/
	cp rootfs/lib/modules/5.10.111/kernel/drivers/usb/common/usb-common.ko tmpfs_usr/modules/
    cp rootfs/lib/modules/5.10.111/kernel/drivers/usb/gadget/udc/udc-core.ko tmpfs_usr/modules/
    cp rootfs/lib/modules/5.10.111/kernel/drivers/usb/gadget/libcomposite.ko tmpfs_usr/modules/
    cp rootfs/lib/modules/5.10.111/kernel/drivers/usb/gadget/function/usb_f_mass_storage.ko tmpfs_usr/modules/
    cp rootfs/lib/modules/5.10.111/kernel/drivers/usb/gadget/function/usb_f_uvc.ko tmpfs_usr/modules/
    cp rootfs/lib/modules/5.10.111/kernel/drivers/usb/gadget/function/usb_f_ak_uac1.ko tmpfs_usr/module
	
    ./mksquashfs tmpfs_usr usr.sqsh4 -noappend -comp xz
    rm -rf tmpfs_usr
else
    ./mksquashfs rootfs/usr usr.sqsh4 -noappend -comp xz
fi

rm -rf tmpfs

