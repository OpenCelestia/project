#! /bin/sh
# ATBM6162 SDIO WiFi for ACTION board (mmc2), ref km02x atbm6162s.sh
#
# ak_mci.ko exposes two hosts: mmc1=SD, mmc2=SDIO WiFi. They are independent:
#   - SD mount only needs ak_mci + mmcblk1 (no WiFi).
#   - WiFi needs cfg80211 + ATBM on mmc2; if ak_mci already loaded (early SD),
#     load ATBM on top and mmc2_rescan (km02x order).
# Boot race was "sta &" loading ak_mci late, not "SD before WiFi".

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin
MODE=$1

WIFI_KO=/usr/modules/ATBM6162_wifi_sdio.ko
CFG_KO=/usr/modules/cfg80211.ko
MCI_KO=/usr/modules/ak_mci.ko

log()
{
    echo "[wifi_driver] $*"
}

log_err()
{
    echo "[wifi_driver][ERR] $*" >&2
}

usage()
{
    echo "Usage: $0 MODE"
    echo "       MODE: install | sta | ap | stop | status"
    echo "             install  Load cfg80211 + ATBM6162 + ak_mci (ATBM before ak_mci)"
    echo "             sta      Station mode (wpa_supplicant + udhcpc; use with '&' at boot like nova)"
    echo "             ap       SoftAP (hostapd + udhcpd)"
    echo "             stop     Unload WiFi driver"
    echo "             status   Show modules / wlan0 / mmc2 state"
}

# NTP/weather resolve names before the DHCP lease lands. /etc/resolv.conf is a
# symlink to tmpfs (/ is read-only squashfs), so seed it with public DNS here;
# udhcpc_wlan.sh replaces it with the DHCP servers once bound.
ensure_resolv_conf()
{
    [ -s /etc/resolv.conf ] && return 0
    {
        echo "nameserver 223.5.5.5"
        echo "nameserver 114.114.114.114"
    } > /tmp/resolv.conf 2>/dev/null && log "seeded /tmp/resolv.conf (public DNS)"
    return 0
}

wifi_status()
{
    log "=== lsmod (wifi related) ==="
    lsmod | grep -E 'cfg80211|ATBM|ak_mci|mmc' || true
    log "=== network interfaces ==="
    ip link show 2>/dev/null || ifconfig -a 2>/dev/null || true
    log "=== ko files ==="
    ls -la "$WIFI_KO" "$CFG_KO" "$MCI_KO" 2>&1 || true
    log "=== mmc / sdio ==="
    ls -la /sys/bus/sdio/devices/ 2>/dev/null || true
    ls -la /sys/bus/mmc/devices/ 2>/dev/null || true
    ls -la /sys/class/mmc_host/ 2>/dev/null || true
    log "=== dmesg (atbm/mmc/wlan) ==="
    dmesg | grep -iE 'atbm|wlan|cfg80211|mmc2|sdio|6162|firmware' | tail -50 || true
}

wifi_stop()
{
    killall wpa_supplicant 2>/dev/null
    killall udhcpc 2>/dev/null
    killall udhcpd 2>/dev/null
    killall hostapd 2>/dev/null
    sleep 1
    rmmod ATBM6162_wifi_sdio 2>/dev/null
    rmmod cfg80211 2>/dev/null
}

wifi_unload_all()
{
    wifi_stop
    rmmod ak_mci 2>/dev/null
    sleep 1
}

# Cold boot: nothing loaded -> skip rmmod/sleep (~2s saved).
# ak_mci only (early SD): keep mmc1, only load WiFi modules on top.
# WiFi reload: drop ATBM/cfg80211; reset ak_mci only if /mnt not mounted.
wifi_prepare_install()
{
    killall wpa_supplicant 2>/dev/null
    killall udhcpc 2>/dev/null
    killall udhcpd 2>/dev/null
    killall hostapd 2>/dev/null

    has_wifi=0
    has_mci=0
    lsmod | grep -q ATBM6162 && has_wifi=1
    lsmod | grep -q cfg80211 && has_wifi=1
    lsmod | grep -q ak_mci && has_mci=1

    if [ "$has_wifi" -eq 0 ] && [ "$has_mci" -eq 0 ]; then
        log "cold boot: skip module unload"
        return 0
    fi

    if [ "$has_wifi" -eq 1 ]; then
        log "reload: unload WiFi modules (ATBM6162, cfg80211)"
        rmmod ATBM6162_wifi_sdio 2>/dev/null
        rmmod cfg80211 2>/dev/null
        sleep 1
        if [ "$has_mci" -eq 1 ]; then
            if mount | grep -q ' on /mnt '; then
                log "keep ak_mci (/mnt mounted)"
            else
                log "reset ak_mci for mmc reprobe"
                rmmod ak_mci 2>/dev/null
                sleep 1
            fi
        fi
        return 0
    fi

    log "ak_mci present (early SD), load WiFi on top"
    return 0
}

insmod_check()
{
    ko="$1"
    shift
    if [ ! -f "$ko" ]; then
        log_err "missing ko: $ko"
        return 1
    fi
    if insmod "$ko" "$@"; then
        log "insmod OK: $(basename "$ko")"
        return 0
    fi
    if lsmod | grep -q "$(basename "$ko" .ko)"; then
        log "already loaded: $(basename "$ko")"
        return 0
    fi
    log_err "insmod failed: $ko"
    dmesg | tail -20
    return 1
}

mmc2_rescan()
{
    if [ -f /sys/class/mmc_host/mmc2/rescan ]; then
        log "mmc2 rescan..."
        echo 1 > /sys/class/mmc_host/mmc2/rescan
        sleep 2
        return 0
    fi
    for f in /sys/class/mmc_host/mmc*/rescan; do
        [ -f "$f" ] || continue
        log "mmc rescan: $f"
        echo 1 > "$f"
        sleep 2
    done
}

wait_wlan0()
{
    i=0
    while [ $i -lt 20 ]; do
        if [ -d /sys/class/net/wlan0 ]; then
            log "wlan0 ready after ${i}s"
            ip link show wlan0 2>/dev/null || ifconfig wlan0 2>/dev/null
            return 0
        fi
        sleep 1
        i=$((i + 1))
    done
    log_err "wlan0 not created after ${i}s"
    wifi_status
    return 1
}

# SCAN / GUI WiFi settings need wpa_supplicant ctrl socket; install-only used to skip this.
start_wpa_supplicant()
{
    WPA_BIN=/usr/sbin/wpa_supplicant
    WPA_CFG=/etc/config/wpa_supplicant.conf
    WPA_CTRL=/var/run/wpa_supplicant/wlan0

    if [ ! -d /sys/class/net/wlan0 ]; then
        log_err "start_wpa_supplicant: wlan0 missing"
        return 1
    fi
    if [ -S "$WPA_CTRL" ]; then
        log "wpa_supplicant ctrl socket ready: $WPA_CTRL"
        return 0
    fi
    if pidof wpa_supplicant >/dev/null 2>&1; then
        log "wpa_supplicant running, wait for ctrl socket..."
        i=0
        while [ $i -lt 5 ]; do
            [ -S "$WPA_CTRL" ] && return 0
            sleep 1
            i=$((i + 1))
        done
        log_err "wpa_supplicant running but no ctrl socket at $WPA_CTRL"
        return 1
    fi
    if [ ! -x "$WPA_BIN" ]; then
        log_err "wpa_supplicant not found: $WPA_BIN"
        return 1
    fi
    if [ ! -f "$WPA_CFG" ]; then
        # No shipped network block — STA ssid/psk live in settings.json;
        # HAL rewrites this file on connect. Stub is enough for scan/ctrl.
        mkdir -p /etc/config
        cat > "$WPA_CFG" <<'EOF'
ctrl_interface=/var/run/wpa_supplicant
update_config=1
EOF
        log "created minimal $WPA_CFG (creds from settings.json)"
    fi

    mkdir -p /var/run/wpa_supplicant
    ip link set wlan0 up 2>/dev/null || ifconfig wlan0 up 2>/dev/null
    log "starting wpa_supplicant (scan/connect ctrl for GUI & NTP)..."
    "$WPA_BIN" -Dnl80211 -i wlan0 -c "$WPA_CFG" -B
    sleep 1
    if [ -S "$WPA_CTRL" ]; then
        log "wpa_supplicant OK: $WPA_CTRL"
        return 0
    fi
    log_err "wpa_supplicant started but ctrl socket missing: $WPA_CTRL"
    return 1
}

wifi_load_modules()
{
    modprobe mmc_core 2>/dev/null
    modprobe mmc_block 2>/dev/null
    modprobe firmware_class path=/usr/sbin 2>/dev/null
    modprobe nls_base 2>/dev/null
    modprobe libarc4 2>/dev/null

    insmod_check "$CFG_KO" || return 1
    if lsmod | grep -q ak_mci; then
        # Early SD: ak_mci already up on mmc1; add ATBM for mmc2 (km02x order)
        insmod_check "$WIFI_KO" atbm_printk_mask=0 || return 1
        sleep 2
    else
        # Cold path: ATBM registers SDIO driver, then ak_mci probes mmc1+mmc2
        insmod_check "$WIFI_KO" atbm_printk_mask=0 || return 1
        sleep 1
        insmod_check "$MCI_KO" || return 1
        sleep 2
    fi
    mmc2_rescan
    sleep 2
    return 0
}

driver_install()
{
    if [ -d /sys/class/net/wlan0 ]; then
        log "wlan0 already exists, skip driver reload"
        start_wpa_supplicant
        return $?
    fi

    wifi_prepare_install
    wifi_load_modules || return 1
    wait_wlan0 || return 1
    start_wpa_supplicant
}

case "$MODE" in
    install)
        driver_install
        ;;
    ap)
        driver_install || exit 1
        ifconfig wlan0 172.14.10.1
        mkdir -p /var/lib/misc/
        touch /var/lib/misc/udhcpd.leases
        rm -f /dev/random
        ln -sf /dev/urandom /dev/random
        udhcpd -S /etc/config/udhcpd.conf &
        hostapd -dd -S -B /etc/config/hostapd.conf
        ;;
    sta)
        driver_install || exit 1
        if [ ! -x /usr/sbin/wpa_supplicant ]; then
            log_err "wpa_supplicant not found at /usr/sbin/wpa_supplicant"
            exit 1
        fi
        # Align with nova EVB: wpa_supplicant -B then foreground udhcpc.
        # app_01_start.sh runs "sta &" so udhcpc retry does not block SD mount / ipc_main.
        start_wpa_supplicant || exit 1
        ensure_resolv_conf
        sleep 1
        if [ -x /usr/sbin/udhcpc_wlan.sh ]; then
            udhcpc -i wlan0 -s /usr/sbin/udhcpc_wlan.sh
        else
            log_err "udhcpc_wlan.sh missing, DHCP DNS will be lost"
            udhcpc -i wlan0
        fi
        ;;
    stop)
        wifi_stop
        ;;
    status)
        wifi_status
        ;;
    *)
        usage
        ;;
esac
exit 0
