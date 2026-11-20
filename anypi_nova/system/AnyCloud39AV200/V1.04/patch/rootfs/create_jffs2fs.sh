#!/bin/sh

#mkdir -p rootfs/tmp/data

./mkfs.jffs2 -d rootfs/etc/config -s 256 -e 4096 -m none -o usr.jffs2
#./mkfs.jffs2 -d rootfs/tmp/data -s 256 -e 4096 -m none -o data.jffs2
