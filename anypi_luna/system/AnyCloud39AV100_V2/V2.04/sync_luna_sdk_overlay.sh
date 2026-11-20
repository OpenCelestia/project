#!/bin/bash
# sync_luna_sdk_overlay.sh
#
# Compare vendor SDK (V2.04) with Luna-modified tree (V2.04_luna), then copy
# deltas into project board/ and patch/ for build_soc_system.sh overlay.
#
# Layout mirrors anypi_nova V1.03:
#   board/<CONFIG_BOARD>/  — board config.mk, DTS, rootfs/utils/etc/config, burntool
#   patch/                 — scripts, shared rootfs sbin, os/kernel driver & DTS base
#
# Usage:
#   ./sync_luna_sdk_overlay.sh              # apply (default)
#   ./sync_luna_sdk_overlay.sh --dry-run    # list only
#
# Environment (optional overrides):
#   CELESTIA_ROOT   repo root
#   SDK_BASE        system/AnyCloud39AV100_V2/V2.04
#   SDK_LUNA        system/AnyCloud39AV100_V2/V2.04_luna
#   CONFIG_BOARD    PDB_MBD_KM01W_ACTCAM

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CELESTIA_ROOT="${CELESTIA_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"
SDK_BASE="${SDK_BASE:-$CELESTIA_ROOT/system/AnyCloud39AV100_V2/V2.04}"
SDK_LUNA="${SDK_LUNA:-$CELESTIA_ROOT/system/AnyCloud39AV100_V2/V2.04_luna}"
CONFIG_BOARD="${CONFIG_BOARD:-PDB_MBD_KM01W_ACTCAM}"
PROJ_OVERLAY="$SCRIPT_DIR"
BOARD_DIR="$PROJ_OVERLAY/board/$CONFIG_BOARD"
PATCH_DIR="$PROJ_OVERLAY/patch"

DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run|--list|-n) DRY_RUN=1 ;;
        -h|--help)
            grep '^#' "$0" | head -20
            exit 0
            ;;
    esac
done

# Only scan these subtrees (avoid walking full kernel tree)
SCAN_PAIRS=(
    "rootfs|$SDK_LUNA/rootfs|$SDK_BASE/rootfs"
    "os/kernel/arch/arm/boot/dts|$SDK_LUNA/os/kernel/arch/arm/boot/dts|$SDK_BASE/os/kernel/arch/arm/boot/dts"
    "os/kernel/arch/arm/configs|$SDK_LUNA/os/kernel/arch/arm/configs|$SDK_BASE/os/kernel/arch/arm/configs"
    "os/kernel/drivers/staging/fbtft|$SDK_LUNA/os/kernel/drivers/staging/fbtft|$SDK_BASE/os/kernel/drivers/staging/fbtft"
    "os/kernel/net/netfilter|$SDK_LUNA/os/kernel/net/netfilter|$SDK_BASE/os/kernel/net/netfilter"
    "scripts|$SDK_LUNA/scripts|$SDK_BASE/scripts"
    "tools/burntool|$SDK_LUNA/burntool|$SDK_BASE/tools/burntool"
    "platform|$SDK_LUNA/platform|$SDK_BASE/platform"
)

should_skip() {
    local rel="$1"
    case "$rel" in
        */log/*|*/image/*) return 0 ;;
        *.o|*.ko|*.a|*.so) return 0 ;;
        *.tar.gz|*.bin|*.img|*.dtb|*.md5|*.exe|*.dll|*.wav) return 0 ;;
        *.sqsh*|*.jffs*|*/uImage|*/u-boot.bin) return 0 ;;
        */usr/modules/*) return 0 ;;
        */usr/sbin/output/*|*/usr/sbin/icon/*) return 0 ;;
        */usr/sbin/action_cam|*/usr/sbin/logo_show|*/usr/sbin/fb-test) return 0 ;;
        */isp_*.conf) return 0 ;;
    esac
    return 1
}

classify_overlay() {
    local rel="$1"
    case "$rel" in
        config.mk) echo "board/config.mk"; return ;;
        rules.mk) echo "patch/rules.mk"; return ;;
        scripts/*) echo "patch/$rel"; return ;;
        platform/*) echo "patch/$rel"; return ;;
        rootfs/utils/etc/config/*|rootfs/utils/etc/ps_*)
            echo "board/rootfs/${rel#rootfs/}"; return ;;
        rootfs/wifi/etc/config/*)
            echo "board/rootfs/${rel#rootfs/}"; return ;;
        rootfs/utils/usr/sbin/*.sh|rootfs/utils/sbin/*)
            echo "patch/$rel"; return ;;
        tools/burntool/*)
            echo "board/$rel"; return ;;
        os/kernel/arch/arm/boot/dts/*ACTCAM*|os/kernel/arch/arm/boot/dts/*KM01W*)
            echo "board/$rel"; return ;;
        os/kernel/arch/arm/configs/*)
            echo "board/$rel"; return ;;
        os/kernel/*)
            echo "patch/$rel"; return ;;
        *) echo "patch/$rel"; return ;;
    esac
}

copy_one() {
    local src="$1" dest="$2"
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "  COPY $src -> $dest"
    else
        mkdir -p "$(dirname "$dest")"
        cp -f "$src" "$dest"
        echo "  COPY $src -> $dest"
    fi
}

collect_diff_files() {
    local luna_dir="$1" base_dir="$2"
    [[ -d "$luna_dir" ]] || return 0
    luna_dir="$(cd "$luna_dir" && pwd)"
    local base_arg=()
    [[ -d "$base_dir" ]] && base_arg=("$(cd "$base_dir" && pwd)")
    diff -qr "${base_arg[@]}" "$luna_dir" 2>/dev/null | while IFS= read -r line; do
        local rel="" src=""
        case "$line" in
            "Only in "*)
                local only_path="${line#Only in }"
                only_path="${only_path%: *}"
                rel="${line##*: }"
                if [[ "$only_path" == "$luna_dir" ]]; then
                    src="$luna_dir/$rel"
                else
                    continue
                fi
                ;;
            Files*and*differ)
                src="${line##* and }"
                src="${src% differ}"
                rel="${src#$luna_dir/}"
                ;;
            *)
                continue
                ;;
        esac
        rel="${rel#/}"
        [[ -n "$rel" && -f "$src" ]] || continue
        echo "$rel|$src"
    done
}

echo "=== sync_luna_sdk_overlay ==="
echo "SDK_BASE=$SDK_BASE"
echo "SDK_LUNA=$SDK_LUNA"
echo "BOARD_DIR=$BOARD_DIR"
echo "PATCH_DIR=$PATCH_DIR"
echo "DRY_RUN=$DRY_RUN"
echo ""

if [[ ! -d "$SDK_BASE" || ! -d "$SDK_LUNA" ]]; then
    echo "ERROR: SDK_BASE or SDK_LUNA missing" >&2
    exit 1
fi

copied=0
while IFS='|' read -r rel src; do
    should_skip "$rel" && continue
    dest_rel="$(classify_overlay "$rel")"
    case "$dest_rel" in
        board/*) dest="$BOARD_DIR/${dest_rel#board/}" ;;
        patch/*) dest="$PATCH_DIR/${dest_rel#patch/}" ;;
        *) dest="$PATCH_DIR/$rel" ;;
    esac
    copy_one "$src" "$dest"
    copied=$((copied + 1))
done < <(
    for entry in "${SCAN_PAIRS[@]}"; do
        IFS='|' read -r prefix luna_dir base_dir <<< "$entry"
        while IFS='|' read -r rel src; do
            echo "${prefix}/${rel}|$src"
        done < <(collect_diff_files "$luna_dir" "$base_dir")
    done
    # Top-level files
    for f in config.mk rules.mk; do
        if [[ -f "$SDK_LUNA/$f" ]]; then
            if [[ ! -f "$SDK_BASE/$f" ]] || ! cmp -s "$SDK_LUNA/$f" "$SDK_BASE/$f"; then
                echo "$f|$SDK_LUNA/$f"
            fi
        fi
    done
)

# ACTCAM DTS only in Luna (diff may report as Only in; also copy explicitly)
ACTCAM_DTS="os/kernel/arch/arm/boot/dts/CA100V2_EVB_MBD_KM01W_ACTCAM_V1.0.0.dts"
if [[ -f "$SDK_LUNA/$ACTCAM_DTS" ]]; then
    dest="$BOARD_DIR/$ACTCAM_DTS"
    if [[ ! -f "$dest" ]] || ! cmp -s "$SDK_LUNA/$ACTCAM_DTS" "$dest"; then
        copy_one "$SDK_LUNA/$ACTCAM_DTS" "$dest"
        copied=$((copied + 1))
    fi
    # Makefile line for ACTCAM dtb
    if [[ -f "$SDK_LUNA/os/kernel/arch/arm/boot/dts/Makefile" ]]; then
        if ! grep -q 'CA100V2_EVB_MBD_KM01W_ACTCAM_V1.0.0.dtb' "$SDK_BASE/os/kernel/arch/arm/boot/dts/Makefile" 2>/dev/null; then
            copy_one "$SDK_LUNA/os/kernel/arch/arm/boot/dts/Makefile" \
                "$PATCH_DIR/os/kernel/arch/arm/boot/dts/Makefile"
            copied=$((copied + 1))
        fi
    fi
fi

BOARD_CFG="$BOARD_DIR/config.mk"
if [[ -f "$BOARD_CFG" && $DRY_RUN -eq 0 ]]; then
    if grep -qE '^CONFIG_DTB_NAME=' "$BOARD_CFG"; then
        sed -i 's|^CONFIG_DTB_NAME=.*|CONFIG_DTB_NAME=EVB_CBDM_KM01A_V1.0.0|' "$BOARD_CFG"
    else
        echo 'CONFIG_DTB_NAME=EVB_CBDM_KM01A_V1.0.0' >> "$BOARD_CFG"
    fi
    if grep -qE '^CONFIG_KERN_DTB_NAME=' "$BOARD_CFG"; then
        sed -i 's|^CONFIG_KERN_DTB_NAME=.*|CONFIG_KERN_DTB_NAME=CA100V2_EVB_MBD_KM01W_ACTCAM_V1.0.0|' "$BOARD_CFG"
    else
        echo 'CONFIG_KERN_DTB_NAME=CA100V2_EVB_MBD_KM01W_ACTCAM_V1.0.0' >> "$BOARD_CFG"
    fi
    for key in CONFIG_SENSOR_NAME CONFIG_WIFI_TYPE; do
        val="$(grep -E "^${key}=" "$SDK_BASE/config.mk" 2>/dev/null | tail -1 || true)"
        [[ -z "$val" ]] && continue
        if grep -qE "^${key}=" "$BOARD_CFG"; then
            sed -i "s|^${key}=.*|${val}|" "$BOARD_CFG"
        fi
    done
    # Luna board uses ov05a10 per modified main.sh / hal_camera
    if grep -qE '^CONFIG_SENSOR_NAME=' "$BOARD_CFG"; then
        sed -i 's|^CONFIG_SENSOR_NAME=.*|CONFIG_SENSOR_NAME=ov05a10|' "$BOARD_CFG"
    fi
    if grep -qE '^CONFIG_FAST_MODE=' "$BOARD_CFG"; then
        sed -i 's|^CONFIG_FAST_MODE=.*|CONFIG_FAST_MODE=no_fast|' "$BOARD_CFG"
    fi
fi

echo ""
echo "Done: copied=$copied"
[[ $DRY_RUN -eq 1 ]] && echo "(dry-run: no files written)"
echo "Build: build_soc_system.sh copies board/* then patch/* onto SDK tree."
