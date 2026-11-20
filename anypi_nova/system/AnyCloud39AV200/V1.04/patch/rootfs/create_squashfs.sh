#!/bin/bash

pwd_dir=$(dirname $0)

if [ -d `pwd`/../../workspace ]; then
  source $pwd_dir/../../config.mk
else
  source $pwd_dir/../config.mk
fi

IPC_MAIN_NAME="${CONFIG_APP_MAIN_TARGET:-ipc_main}"
IPC_MAIN_PATH=
# Prefer CONFIG_APP_MAIN_TARGET (nova_main), then legacy ipc_main / ipc_home aliases.
for cand in \
	"./$IPC_MAIN_NAME" "./rootfs/$IPC_MAIN_NAME" \
	"./nova_main" "./rootfs/nova_main" \
	"./ipc_main" "./rootfs/ipc_main" \
	"./ipc_home" "./rootfs/ipc_home"
do
	if [ -f "$cand" ]; then
		IPC_MAIN_PATH=$cand
		IPC_MAIN_NAME=$(basename "$cand")
		break
	fi
done
if [ -z "$IPC_MAIN_PATH" ]; then
	echo "Error: main app ($IPC_MAIN_NAME / nova_main / ipc_main) not found in ./ or ./rootfs/. Build application first (e.g. -a)." >&2
	exit 1
fi
echo "create_squashfs: using main binary $IPC_MAIN_PATH (name=$IPC_MAIN_NAME)" >&2

# ipc_main on flash usr.sqsh4 (/usr/sbin). SD install/ holds other apps + model.
INSTALL_IPC_PACKED=0
if [ -f "./install/$IPC_MAIN_NAME" ] && [ ! -f "rootfs/usr/sbin/$IPC_MAIN_NAME" ]; then
	INSTALL_IPC_PACKED=1
	echo "ipc_main packed in install/ only (legacy), skip flash usr.sqsh4 copy" >&2
fi

mkdir -p tmp_data
if [ -d rootfs/data ] && [ "$(ls -A rootfs/data 2>/dev/null)" ]; then
	cp -af rootfs/data/. tmp_data/
fi
if [ "$INSTALL_IPC_PACKED" = 0 ]; then
	cp -af "$IPC_MAIN_PATH" tmp_data/"$IPC_MAIN_NAME"
fi
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

# External libs pack (application/framework/hardware/third_party .so on SD install/):
# - build_rootfs.sh prepares ./install/ and ./install.exclude
# - Do NOT squash install/; keep as directory tree for MSC copy
# - Exclude those libs from usr.sqsh4 via -ef
INSTALL_STAGE_DIR=install
INSTALL_EXCLUDE_FILE=install.exclude
if [ -d "$INSTALL_STAGE_DIR" ] && [ "$(ls -A "$INSTALL_STAGE_DIR" 2>/dev/null)" ]; then
    echo "install pack ready under ./$INSTALL_STAGE_DIR (directory, not squashfs)" >&2
fi

# USB gadget (UVC / U-disk MSC): kernel modules live under rootfs/lib/modules, copy into usr/modules for insmod
copy_usb_gadget_modules()
{
    local dest="$1"
    local kdir=rootfs/lib/modules/5.10.111/kernel

    [ -d "$dest" ] || mkdir -p "$dest"
    if [ ! -d "$kdir" ]; then
        echo "warn: $kdir missing, skip USB gadget modules" >&2
        return 1
    fi

    echo "copy USB gadget modules -> $dest" >&2
    cp -f "$kdir"/drivers/usb/gadget/legacy/g_ak_aw.ko "$dest/" 2>/dev/null || true
    cp -f "$kdir"/drivers/media/common/videobuf2/videobuf2-vmalloc.ko "$dest/" 2>/dev/null || true
    cp -f "$kdir"/drivers/usb/gadget/legacy/g_mass_storage.ko "$dest/" 2>/dev/null || true
    cp -f rootfs/lib/modules/5.10.111/kernel/fs/configfs/configfs.ko "$dest/" 2>/dev/null || true
    cp -f rootfs/usr/modules/ak_udc.ko "$dest/" 2>/dev/null || true
    cp -f "$kdir"/drivers/usb/common/usb-common.ko "$dest/" 2>/dev/null || true
    cp -f "$kdir"/drivers/usb/gadget/udc/udc-core.ko "$dest/" 2>/dev/null || true
    cp -f "$kdir"/drivers/usb/gadget/libcomposite.ko "$dest/" 2>/dev/null || true
    cp -f "$kdir"/drivers/usb/gadget/function/usb_f_mass_storage.ko "$dest/" 2>/dev/null || true
    cp -f "$kdir"/drivers/usb/gadget/function/usb_f_uvc.ko "$dest/" 2>/dev/null || true
    cp -f "$kdir"/drivers/usb/gadget/function/usb_f_ak_uac1.ko "$dest/" 2>/dev/null || true
}

# Strip ELF before squashfs so usr.sqsh4 fits APP/mtd8 (~0x8AC000).
# Unstripped .so/.ko (esp. after zxing-cpp 3.x / jpeg) otherwise overrun burn size.
# Never use host /usr/bin/strip: when CROSS_COMPILE is unset, bare "strip" exists but
# cannot parse RISC-V ELF, and with stderr discarded every .so stays unstripped.
strip_usr_tree()
{
    local root="$1"
    local strip_bin=""
    if [ -n "${CROSS_COMPILE:-}" ] && command -v "${CROSS_COMPILE}strip" >/dev/null 2>&1; then
        strip_bin="${CROSS_COMPILE}strip"
    elif command -v riscv64-anyka-linux-musl-strip >/dev/null 2>&1; then
        strip_bin=riscv64-anyka-linux-musl-strip
    elif command -v arm-anycloud-linux-uclibcgnueabi-strip >/dev/null 2>&1; then
        strip_bin=arm-anycloud-linux-uclibcgnueabi-strip
    else
        echo "warn: cross strip not found, usr.sqsh4 may exceed APP partition" >&2
        return 0
    fi
    echo "strip usr tree with $strip_bin ..." >&2
    # Only real ELF candidates; skip scripts matched by -perm -111.
    find "$root" -type f \( -name '*.so*' -o -name '*.ko' -o -name 'nova_main' -o -name 'ipc_main' -o -name 'ipc_home' \) \
        -exec "$strip_bin" --strip-unneeded {} \; 2>/dev/null || true
    local sample
    sample=$(find "$root/lib" -type f -name 'libzxing.so*' 2>/dev/null | head -1)
    if [ -n "$sample" ] && command -v file >/dev/null 2>&1; then
        echo "strip check: $(file -b "$sample")" >&2
    fi
}

echo "fs image..." >&2
if [ "$CONFIG_CELESTIA_FASTSYS" = "y" ]; then
    if [ "$INSTALL_IPC_PACKED" = 0 ]; then
        cp "$IPC_MAIN_PATH" rootfs/usr/sbin/"$IPC_MAIN_NAME"
        chmod +x rootfs/usr/sbin/"$IPC_MAIN_NAME" 2>/dev/null || true
        # Drop the old ipc_home alias so the process name stays nova_main.
        rm -f rootfs/usr/sbin/ipc_home 2>/dev/null || true
    else
        rm -f rootfs/usr/sbin/"$IPC_MAIN_NAME" 2>/dev/null || true
        rm -f rootfs/usr/sbin/ipc_home 2>/dev/null || true
    fi
    strip_usr_tree rootfs/usr
    if [ -d "$INSTALL_STAGE_DIR" ] && [ -f "$INSTALL_EXCLUDE_FILE" ]; then
        echo "build usr.sqsh4 with exclude file: $INSTALL_EXCLUDE_FILE" >&2
        ./mksquashfs rootfs/usr usr.sqsh4 -noappend -comp xz -ef "$INSTALL_EXCLUDE_FILE"
    else
        ./mksquashfs rootfs/usr usr.sqsh4 -noappend -comp xz
    fi
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

    copy_usb_gadget_modules tmpfs_usr/modules

    strip_usr_tree tmpfs_usr
    if [ -d "$INSTALL_STAGE_DIR" ] && [ -f "$INSTALL_EXCLUDE_FILE" ]; then
        echo "build usr.sqsh4 with exclude file: $INSTALL_EXCLUDE_FILE" >&2
        ./mksquashfs tmpfs_usr usr.sqsh4 -noappend -comp xz -ef "$INSTALL_EXCLUDE_FILE"
    else
        ./mksquashfs tmpfs_usr usr.sqsh4 -noappend -comp xz
    fi
    rm -rf tmpfs_usr
else
    # NORMAL boot: previously only platform ko in usr/modules; add USB MSC/UVC gadget stack
    copy_usb_gadget_modules rootfs/usr/modules

    strip_usr_tree rootfs/usr
    if [ -d "$INSTALL_STAGE_DIR" ] && [ -f "$INSTALL_EXCLUDE_FILE" ]; then
        echo "build usr.sqsh4 with exclude file: $INSTALL_EXCLUDE_FILE" >&2
        ./mksquashfs rootfs/usr usr.sqsh4 -noappend -comp xz -ef "$INSTALL_EXCLUDE_FILE"
    else
        ./mksquashfs rootfs/usr usr.sqsh4 -noappend -comp xz
    fi
fi

rm -rf tmpfs
