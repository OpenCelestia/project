#!/bin/sh
# LCD framebuffer test for ACTION board (ST7262 800x480, BGR24 on fb0).
# Ref: km02x fb-test.sh - direct pixel write, no temp .bin files.

FB="/dev/fb0"
W=800
H=480
DELAY=1

usage()
{
    echo "usage: $0 [delay_sec]"
    echo "  Fill fb0 with solid colors and RGB stripes (no ipc_main / LVGL)."
    echo "  delay_sec: seconds between each step (default $DELAY)"
    echo ""
    echo "Board: ST7262 ${W}x${H}, expect bits_per_pixel=24 BGR"
}

read_fb_geometry()
{
    if [ -r /sys/class/graphics/fb0/virtual_size ]; then
        vs=$(cat /sys/class/graphics/fb0/virtual_size 2>/dev/null)
        cw=$(echo "$vs" | cut -d, -f1)
        ch=$(echo "$vs" | cut -d, -f2)
        [ -n "$cw" ] && [ "$cw" -gt 0 ] && W=$cw
        [ -n "$ch" ] && [ "$ch" -gt 0 ] && H=$ch
    fi
    if [ -r /sys/class/graphics/fb0/bits_per_pixel ]; then
        BPP=$(cat /sys/class/graphics/fb0/bits_per_pixel 2>/dev/null)
    else
        BPP=24
    fi
    case "$BPP" in
        16) PIXEL_BYTES=2; FMT=rgb565 ;;
        24) PIXEL_BYTES=3; FMT=bgr24 ;;
        32) PIXEL_BYTES=4; FMT=bgra32 ;;
        *)  PIXEL_BYTES=3; FMT=bgr24; BPP=24 ;;
    esac
    PIXELS=$((W * H))
    FRAME_BYTES=$((PIXELS * PIXEL_BYTES))
}

ensure_lcd()
{
    if [ -e "$FB" ]; then
        return 0
    fi
    if [ -x /usr/sbin/lcd.sh ]; then
        echo "fb0 missing, run lcd.sh install..."
        /usr/sbin/lcd.sh install
        sleep 1
    fi
    [ -e "$FB" ] || {
        echo "error: $FB not found (load fb.ko + ak_lcd.ko first)"
        exit 1
    }
}

# $1 = red | green | blue | white | black
print_pixel()
{
    case "$1" in
        red)
            if [ "$FMT" = "rgb565" ]; then
                printf '\x00\xF8'
            elif [ "$FMT" = "bgr24" ]; then
                printf '\x00\x00\xFF'
            else
                printf '\x00\x00\xFF\xFF'
            fi
            ;;
        green)
            if [ "$FMT" = "rgb565" ]; then
                printf '\xE0\x07'
            elif [ "$FMT" = "bgr24" ]; then
                printf '\x00\xFF\x00'
            else
                printf '\x00\xFF\x00\xFF'
            fi
            ;;
        blue)
            if [ "$FMT" = "rgb565" ]; then
                printf '\x1F\x00'
            elif [ "$FMT" = "bgr24" ]; then
                printf '\xFF\x00\x00'
            else
                printf '\xFF\x00\x00\xFF'
            fi
            ;;
        white)
            if [ "$FMT" = "rgb565" ]; then
                printf '\xFF\xFF'
            elif [ "$FMT" = "bgr24" ]; then
                printf '\xFF\xFF\xFF'
            else
                printf '\xFF\xFF\xFF\xFF'
            fi
            ;;
        black)
            if [ "$FMT" = "rgb565" ]; then
                printf '\x00\x00'
            elif [ "$FMT" = "bgr24" ]; then
                printf '\x00\x00\x00'
            else
                printf '\x00\x00\x00\xFF'
            fi
            ;;
        *)
            printf '\x00\x00\x00'
            ;;
    esac
}

# $1 = red | green | blue | white | black
fill_solid()
{
    row=0
    while [ "$row" -lt "$H" ]; do
        col=0
        while [ "$col" -lt "$W" ]; do
            print_pixel "$1"
            col=$((col + 1))
        done
        row=$((row + 1))
    done > "$FB"
}

show_info()
{
    echo "========================================"
    echo "LCD framebuffer test"
    echo "  device : $FB"
    echo "  size   : ${W}x${H}"
    echo "  format : ${BPP}bpp ($FMT), frame=${FRAME_BYTES} bytes"
    if [ -r /sys/class/graphics/fb0/stride ]; then
        echo "  stride : $(cat /sys/class/graphics/fb0/stride)"
    fi
    echo "========================================"
}

stripe_vertical()
{
    echo "vertical stripes (30px bands)..."
    row=0
    while [ "$row" -lt "$H" ]; do
        col=0
        while [ "$col" -lt "$W" ]; do
            band=$((col / 30 % 3))
            if [ $band -eq 0 ]; then
                print_pixel red
            elif [ $band -eq 1 ]; then
                print_pixel green
            else
                print_pixel blue
            fi
            col=$((col + 1))
        done
        row=$((row + 1))
    done > "$FB"
}

stripe_horizontal()
{
    echo "horizontal stripes (30px bands)..."
    row=0
    while [ "$row" -lt "$H" ]; do
        band=$((row / 30 % 3))
        col=0
        while [ "$col" -lt "$W" ]; do
            if [ $band -eq 0 ]; then
                print_pixel red
            elif [ $band -eq 1 ]; then
                print_pixel green
            else
                print_pixel blue
            fi
            col=$((col + 1))
        done
        row=$((row + 1))
    done > "$FB"
}

# --- main ---
case "$1" in
    -h|--help|help)
        usage
        exit 0
        ;;
esac

[ -n "$1" ] && DELAY=$1

if pidof nova_main ipc_main ipc_home >/dev/null 2>&1; then
    echo "warn: nova_main is running - stop it first for a clean test:"
    echo "      killall nova_main"
fi

ensure_lcd
read_fb_geometry
show_info

echo "test start (delay ${DELAY}s per step)..."

for name in red green blue white black; do
    echo "$name"
    fill_solid "$name"
    sleep "$DELAY"
done

stripe_vertical
sleep 2

stripe_horizontal
sleep 2

echo "clear screen"
fill_solid black

echo "done"
