#!/bin/sh
# udhcpc handler for wlan0.
#
# / is a read-only squashfs, so the resolver file lives on tmpfs and
# /etc/resolv.conf is a symlink to it (see build_rootfs.sh process_utils).
# Without this, DHCP DNS is lost and every getaddrinfo() returns EAI_AGAIN
# (NTP / weather / OTA all fail while ping by IP still works).

RESOLV=/tmp/resolv.conf

[ -n "$1" ] || exit 1
[ -n "$interface" ] || interface=wlan0

case "$1" in
	deconfig)
		ifconfig "$interface" 0.0.0.0
		;;
	renew|bound)
		ifconfig "$interface" "$ip" netmask "${subnet:-255.255.255.0}"

		if [ -n "$router" ]; then
			while route del default gw 0.0.0.0 dev "$interface" 2>/dev/null; do :; done
			for r in $router; do
				route add default gw "$r" dev "$interface" 2>/dev/null
			done
		fi

		: > "$RESOLV"
		[ -n "$domain" ] && echo "search $domain" >> "$RESOLV"
		for d in $dns; do
			echo "nameserver $d" >> "$RESOLV"
		done
		# Public fallback after the DHCP servers: musl queries all listed
		# nameservers in parallel, so this costs nothing when DHCP DNS answers.
		echo "nameserver 223.5.5.5" >> "$RESOLV"
		echo "nameserver 114.114.114.114" >> "$RESOLV"
		echo "udhcpc_wlan: $ip via ${router:-none}, dns: ${dns:-none}"
		;;
esac

exit 0
