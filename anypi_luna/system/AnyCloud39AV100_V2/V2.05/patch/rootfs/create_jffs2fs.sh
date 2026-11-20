#!/bin/sh
# Celestia Luna: stage board config, pack with SDK ./mkfs.jffs2 (Anyka BSP tool).

set -e

CONFIG_DIR=rootfs/etc/config
mkdir -p "$CONFIG_DIR"

if [ -d rootfs/utils/etc/config ]; then
	cp -af rootfs/utils/etc/config/. "$CONFIG_DIR/"
	find "$CONFIG_DIR" -name '*.sh' -exec chmod +x {} +
fi

if [ ! -f ./mkfs.jffs2 ]; then
	echo "ERROR: SDK mkfs.jffs2 not found in $(pwd)" >&2
	exit 1
fi
chmod +x ./mkfs.jffs2 2>/dev/null || true

./mkfs.jffs2 -d "$CONFIG_DIR" -s 256 -e 4096 -m none -o usr.jffs2 || {
	echo "ERROR: ./mkfs.jffs2 failed." >&2
	echo "SDK mkfs.jffs2 is 32-bit i386. On WSL/Ubuntu enable i386, then install libs:" >&2
	echo "  sudo dpkg --add-architecture i386" >&2
	echo "  sudo apt update" >&2
	echo "  sudo apt install libc6-i386 zlib1g:i386 liblzo2-2:i386" >&2
	echo "Missing libs:" >&2
	ldd ./mkfs.jffs2 2>&1 | grep 'not found' >&2 || true
	exit 1
}
echo "Created usr.jffs2 from $CONFIG_DIR"
