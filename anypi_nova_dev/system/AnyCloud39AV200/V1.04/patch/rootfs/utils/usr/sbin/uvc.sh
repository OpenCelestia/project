
#!/bin/sh

USB_CONFIG_PATH=/sys/kernel/config/usb_gadget
VFORMAT=$1
VNAME=$2
VW=$3
VH=$4
VFPS=$5

enable_usb_configfs()
{
       echo 8 > /proc/sys/kernel/printk
       mount -t debugfs none /sys/kernel/debug/
  #      modprobe usb-common
   #     modprobe udc-core
  #      insmod /usr/modules/ak_udc.ko
  #      modprobe libcomposite
insmod /lib/modules/5.10.111/kernel/drivers/usb/common/usb-common.ko
insmod /lib/modules/5.10.111/kernel/drivers/usb/gadget/udc/udc-core.ko
insmod /lib/modules/5.10.111/kernel/fs/configfs/configfs.ko
insmod /lib/modules/5.10.111/kernel/drivers/usb/gadget/libcomposite.ko
insmod /lib/modules/5.10.111/kernel/drivers/media/common/videobuf2/videobuf2-vmalloc.ko
insmod /lib/modules/5.10.111/kernel/drivers/usb/gadget/function/usb_f_uvc.ko uvc_use_bulk=0 max_payload_size_bulk=10240
#insmod /usr/modules/usb-common.ko
#insmod /usr/modules/udc-core.ko
insmod /usr/modules/ak_udc.ko
#insmod /usr/modules/configfs.ko
#insmod /usr/modules/libcomposite.ko

#insmod /usr/modules/videobuf2-vmalloc.ko
#insmod /usr/modules/usb_f_uvc.ko uvc_use_bulk=0 max_payload_size_bulk=10240

 #       echo -n 'file composite.c +p'  > /sys/kernel/debug/dynamic_debug/control 
        #echo -n 'file ak_udc.c +p'  > /sys/kernel/debug/dynamic_debug/control 
	#	echo -n 'file usb_f_uvc.c +p'  > /sys/kernel/debug/dynamic_debug/control 
		echo -n 'file configfs.c +p'  > /sys/kernel/debug/dynamic_debug/control 
		echo -n 'file uvc_configfs.c +p'  > /sys/kernel/debug/dynamic_debug/control
        mount -t configfs none /sys/kernel/config/
}

create_uvc_format_frame()
{
	format=$3
	name=$4
	width=$5
	height=$6
	fps=$7
	index=$8
	local dir=$USB_CONFIG_PATH/$1/functions/uvc.$2/streaming/$format/$name
	framedir=$dir/${width}x${height}
	mkdir -p $framedir

	echo $width > $framedir/wWidth
	echo $height > $framedir/wHeight
	interval=$((10000000/$fps))
	echo $interval > $framedir/dwFrameInterval
	echo $interval > $framedir/dwDefaultFrameInterval
	# echo $(($width * $height * 2 * $fps * 8)) > $framedir/dwMinBitRate
	# echo $(($width * $height * 2 * $fps * 8)) > $framedir/dwMaxBitRate
	echo $(($width * $height)) > $framedir/dwMinBitRate
	echo $(($width * $height)) > $framedir/dwMaxBitRate
	echo $index > $framedir/bFrameIndex
	
	case "${format}" in
		"uncompressed")
			;;
		"mjpeg")
			# echo $(($width * $height * 2)) > $framedir/dwMaxVideoFrameBufferSize
			echo $(($width * $height)) > $framedir/dwMaxVideoFrameBufferSize
			;;
		"framebased")
			echo 0 > $framedir/dwBytesPerLine
			common_suffix="\x00\x00\x10\x00\x80\x00\x00\xaa\x00\x38\x9b\x71"
			if   [ "${name}" = "h264" ]; then
				hex_data="H264${common_suffix}"
			elif [ "${name}" = "h265" ]; then
				hex_data="H265${common_suffix}"
			else
				echo "Unsupported frambased format: ${name}" >&2
				exit 1
			fi
			echo -ne "$hex_data" > "$dir/guidFormat"
			;;
		*)
			echo "Unsupported format: ${format}" >&2
			exit 1
			;;
	esac
}

create_uvc()
{
	echo abcd $VFORMAT $VNAME $VW $VH $VFPS
        dir=$USB_CONFIG_PATH/$1/functions/uvc.$2
        mkdir $dir
        echo $3 > $dir/streaming_maxpacket
        mkdir $dir/control/header/h
        ln -s $dir/control/header/h $dir/control/class/fs


    if [ "${VFORMAT}" = "framebased" ]; then
        create_uvc_format_frame $1 $2 $VFORMAT $VNAME 1280 960 30 1
        create_uvc_format_frame $1 $2 $VFORMAT $VNAME 1920 1080 30 2
    elif [ "${VFORMAT}" = "mjpeg" ]; then
        create_uvc_format_frame $1 $2 mjpeg m 1280 960 30 1
        create_uvc_format_frame $1 $2 mjpeg m 1920 1080 30 2
    fi

    #   create_uvc_format_frame $1 $2 mjpeg m 3840 2880 30 1
	#create_uvc_format_frame $1 $2 $VFORMAT $VNAME $VW $VH $VFPS 1
	# create_uvc_format_frame $1 $2 framebased h264 2080 1536 30 1
	#create_uvc_format_frame $1 $2 $VFORMAT h264 1280 960 30 1
	#create_uvc_format_frame $1 $2 $VFORMAT h264 1920 1080 30 2
	#create_uvc_format_frame $1 $2 $VFORMAT h264 2560 1440 30 3

        mkdir $dir/streaming/header/h
		if [ -d "$dir/streaming/mjpeg/m" ]; then
			ln -s $dir/streaming/mjpeg/m/  $dir/streaming/header/h
		fi
        
		if [ -d "$dir/streaming/framebased/h264" ]; then
			ln -s $dir/streaming/framebased/h264 $dir/streaming/header/h
		fi

		if [ -d "$dir/streaming/framebased/h265" ]; then
			ln -s $dir/streaming/framebased/h265/  $dir/streaming/header/h
		fi

        ln -s $dir/streaming/header/h/ $dir/streaming/class/fs
        ln -s $dir/streaming/header/h/ $dir/streaming/class/hs

        dir=$USB_CONFIG_PATH/$1
        ln -s $dir/functions/uvc.$2 $dir/configs/c.1
}

create_usb_device()
{
        dir=$USB_CONFIG_PATH/$1
        mkdir $dir
        echo 0x0200 > $dir/bcdUSB
        echo 0xef > $dir/bDeviceClass
        echo 2 > $dir/bDeviceSubClass
        echo 1 > $dir/bDeviceProtocol
        echo 64 > $dir/bMaxPacketSize0
  #      echo 0x1d6d > $dir/idVendor
   #     echo 0x0101 > $dir/idProduct
  #      echo 0x0404 > $dir/bcdDevice
		echo 0x1d6f > $dir/idVendor
        echo 0x0108 > $dir/idProduct
        echo 0x0405 > $dir/bcdDevice
        mkdir $dir/configs/c.1
        echo 0xc0 > $dir/configs/c.1/bmAttributes
        echo 500 > $dir/configs/c.1/MaxPower

        bulk_mode=0
        if [ $bulk_mode = 1 ];then
	        create_uvc $1 1 512
	else
		create_uvc $1 1 1024
	fi

        echo "c0a50000.usb" > $dir/UDC
}

enable_usb_configfs

create_usb_device g1
