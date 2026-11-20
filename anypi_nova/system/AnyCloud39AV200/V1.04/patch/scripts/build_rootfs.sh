#!/bin/bash
pwd_dir=$(dirname $0)
# Absolute script dir for later use (e.g. deploy settings.json from project config)
SCRIPT_ABS_DIR=$(cd "$pwd_dir" 2>/dev/null && pwd)
source $pwd_dir/../config.mk

get_config_info()
{
	FLASH_TYPE=$CONFIG_FLASH_TYPE
	SCREEN_TYPE=$CONFIG_SCREEN_TYPE
	WIFI_TYPE=$CONFIG_WIFI_TYPE
	IMU_TYPE=$CONFIG_IMU_TYPE
	ETHERNET=$CONFIG_ETHERNET
	CHIP_SERIES=$CONFIG_CHIP_SERIES
	
  if [ $CONFIG_CELESTIA_FASTSYS = "y" ];then
		SYS_BOOT_MODE=normal
  else
    	SYS_BOOT_MODE=$CONFIG_SYS_BOOT_MODE
  fi

    rootfs_dir=$CONFIG_TOP_DIR/rootfs
    # rootfs/utils overlay：未设置时用 CONFIG_TOP_DIR（建议由 scripts/build.sh package 设置 SOC_PATCH_DIR 为源码 board 路径）
    if [ -z "$SOC_PATCH_DIR" ]; then
        SOC_PATCH_DIR=$CONFIG_TOP_DIR
        echo "Warning: SOC_PATCH_DIR unset, using CONFIG_TOP_DIR for rootfs/utils overlay"
    fi
    driver_install_dir=$CONFIG_TOP_DIR/os/driver
    image_install_dir=$CONFIG_IMAGE_OUTPUT_DIR
    sample_install_dir=$rootfs_dir/samples
    
  if [ $CHIP_SERIES = "AK3918AV200" ];then
  	if [ "$SYS_BOOT_MODE" = "FAST" ];then
      driver_ko_dir=$CONFIG_TOP_DIR/os/driver/external/fast
  	else
			driver_ko_dir=$CONFIG_TOP_DIR/os/driver/external/normal
  	fi     
  else
  	driver_ko_dir=$CONFIG_TOP_DIR/os/driver/external/
  fi

    echo "FLASH_TYPE=$FLASH_TYPE, WIFI_TYPE=$WIFI_TYPE, CHIP_SERIES=$CHIP_SERIES"
}

extract_fs()
{
    # 解压缩根文件系统
#    if [ -d "resource" ]; then
#        echo "delete the resource folder !"
#        rm "resource" -rf
#    fi

    if 	test $CHIP_SERIES = "AK3918AV200" ; then
        if [ -d "resource" ]; then
            echo "delete the resource folder !"
            rm "resource" -rf
        fi
        rm -rf rootfs.tar.gz 
        if test "$CONFIG_CROSS_COMPILE" = "riscv64-anyka-linux-musl-" ; then
            echo "musl rootfs!"
            tar zxvf rootfs_av200_musl.tar.gz  -C $rootfs_dir
			cp -rf $SOC_PATCH_DIR/rootfs/utils/* $rootfs_dir/utils/
            echo copy $SOC_PATCH_DIR/rootfs/utils to $rootfs_dir/utils
            if [ -n "$PROJECT_PATCH_UTILS" ] && [ -d "$PROJECT_PATCH_UTILS" ]; then
                cp -rf "$PROJECT_PATCH_UTILS"/* $rootfs_dir/utils/
                echo copy PROJECT_PATCH_UTILS \(project patch\) to $rootfs_dir/utils
            fi
            if [ -n "$PROJECT_PATCH_FASTSYS_UTILS" ] && [ -d "$PROJECT_PATCH_FASTSYS_UTILS" ]; then
                cp -rf "$PROJECT_PATCH_FASTSYS_UTILS"/* $rootfs_dir/utils/
                echo copy PROJECT_PATCH_FASTSYS_UTILS \(project patch_fastsys\) to $rootfs_dir/utils
            fi
            find "$rootfs_dir/utils" -name '*.sh' -exec sed -i 's/\r$//' {} + 2>/dev/null || true
            # sed -i rewrites via temp+rename, dropping the executable bit (755 -> 644).
            # Restore it so .sh on target can be exec'd directly (start_ipc_main.sh etc.).
            find "$rootfs_dir/utils" -name '*.sh' -exec chmod +x {} + 2>/dev/null || true

            ln -s busybox_av200_musl.tar.gz rootfs.tar.gz
        elif test "$CONFIG_CROSS_COMPILE" = "riscv64-anyka-linux-gnu-"; then
            echo "glibc rootfs!"
            tar zxvf rootfs_av200_glibc.tar.gz -C $rootfs_dir
            ln -s busybox_av200_glibc.tar.gz rootfs.tar.gz
        else
            echo "The toochain $CONFIG_CROSS_COMPILE did not match the file system!"
            exit 1
        fi
    else
        echo "extract basic resource"
 #       tar zxvf resouce.tar.gz -C $rootfs_dir
    fi

    ./extract.sh
}

process_wifi_driver()
{
    rm -rf rootfs/usr/modules/rtl*
    rm -rf rootfs/usr/modules/atbm*
    rm -rf rootfs/usr/modules/ssv*
    rm -rf rootfs/usr/modules/cfg*
    rm -rf rootfs/usr/modules/ATBM*

    # 根据选择的WIFI类型，清理掉无用的驱动
    if test $WIFI_TYPE = "NO_WIFI" ; then
		true
    elif test $WIFI_TYPE = "rtl8188ftv" ; then
      if 	test $CHIP_SERIES = "AK3918AV200" ; then
        cp -rf $driver_ko_dir/rtl8188fu.ko rootfs/usr/modules/
      else
        cp -rf $driver_ko_dir/rtl8188ftv.ko rootfs/usr/modules/
      fi
    elif test $WIFI_TYPE = "rtl8189ftv" ; then
        cp -rf $driver_ko_dir/rtl8189ftv.ko rootfs/usr/modules/
    elif test $WIFI_TYPE = "atbm6031" ; then
		cp -rf $driver_ko_dir/atbm6031.ko rootfs/usr/modules/
  elif test $WIFI_TYPE = "atbm6032" ; then
		cp -rf $driver_ko_dir/atbm6032.ko rootfs/usr/modules/
  elif test $WIFI_TYPE = "atbm6012b" ; then
		cp -rf $driver_ko_dir/atbm6032.ko rootfs/usr/modules/
  elif test $WIFI_TYPE = "atbm6132" ; then
    cp -rf $driver_ko_dir/atbm6132_wifi_usb.ko rootfs/usr/modules/
	elif test $WIFI_TYPE = "atbm6031x" ; then
		cp -rf $driver_ko_dir/atbm6031x.ko rootfs/usr/modules/
	elif test $WIFI_TYPE = "atbm6012bx" ; then
		cp -rf $driver_ko_dir/atbm6012bx.ko rootfs/usr/modules/
	elif test $WIFI_TYPE = "atbm6062u" ; then
		cp -rf $driver_ko_dir/ATBM606x_wifi_usb.ko rootfs/usr/modules/
		cp -rf $driver_ko_dir/cfg80211.ko rootfs/usr/modules/
	elif test $WIFI_TYPE = "atbm6062s" ; then
		cp -rf $driver_ko_dir/ATBM606x_wifi_sdio.ko rootfs/usr/modules/
		cp -rf $driver_ko_dir/cfg80211.ko rootfs/usr/modules/
	elif test $WIFI_TYPE = "atbm6162" ; then
		cp -rf $driver_ko_dir/ATBM6162_wifi_sdio.ko rootfs/usr/modules/ 2>/dev/null || true
		cp -rf $driver_ko_dir/cfg80211.ko rootfs/usr/modules/ 2>/dev/null || true
    elif test $WIFI_TYPE = "ssv6x5x" ; then
        cp -rf $driver_ko_dir/ssv6x5x.ko rootfs/usr/modules/
    fi
}

# Board/project-verified ko overlay.
# Prefer project patch/rootfs/utils/usr/modules (PROJECT_PATCH_UTILS), then board / local utils.
# Default: fill only when missing (prefer freshly built out/).
# Force replace for AF/VCM patched drivers: ak_vi.ko, vcm_fp5510.ko, sensor_ov8856.ko.
# Skip ko not matching board config.mk (CONFIG_IMU_TYPE / CONFIG_ETHERNET / ...).
overlay_board_reference_modules()
{
    ref_dir=""
    if [ -n "$PROJECT_PATCH_UTILS" ] && [ -d "$PROJECT_PATCH_UTILS/usr/modules" ]; then
        ref_dir="$PROJECT_PATCH_UTILS/usr/modules"
    elif [ -n "$SOC_PATCH_DIR" ] && [ -d "$SOC_PATCH_DIR/rootfs/utils/usr/modules" ]; then
        ref_dir="$SOC_PATCH_DIR/rootfs/utils/usr/modules"
    elif [ -d "./utils/usr/modules" ]; then
        ref_dir="./utils/usr/modules"
    elif [ -d "./rootfs/utils/usr/modules" ]; then
        ref_dir="./rootfs/utils/usr/modules"
    fi
    if [ -z "$ref_dir" ]; then
        return
    fi
    n_fill=0
    n_force=0
    n_keep=0
    for f in "$ref_dir"/*.ko; do
        [ -f "$f" ] || continue
        bn=$(basename "$f")
        case "$bn" in
            ak_eth.ko)
                [ "$ETHERNET" = "NO" ] && continue
                ;;
            ak_sc7u22.ko|ak_sc7i22.ko)
                [ "$IMU_TYPE" = "NO_IMU" ] && continue
                ;;
            ATBM6162_wifi_sdio.ko|cfg80211.ko)
                [ "$WIFI_TYPE" = "NO_WIFI" ] && continue
                ;;
            ts_*.ko)
                want="ts_${SCREEN_TYPE}.ko"
                [ "$bn" != "$want" ] && continue
                ;;
            sensor_*.ko)
                want="sensor_${CONFIG_SENSOR_TYPE}.ko"
                [ "$bn" != "$want" ] && continue
                ;;
        esac
        force=0
        case "$bn" in
            ak_vi.ko|vcm_fp5510.ko|sensor_ov8856.ko)
                force=1
                ;;
        esac
        if [ -f "rootfs/usr/modules/$bn" ] && [ "$force" -eq 0 ]; then
            n_keep=$((n_keep + 1))
            continue
        fi
        cp -af "$f" rootfs/usr/modules/
        if [ "$force" -eq 1 ] && [ -f "rootfs/usr/modules/$bn" ]; then
            n_force=$((n_force + 1))
        else
            n_fill=$((n_fill + 1))
        fi
    done
    echo "overlay board reference modules from $ref_dir (sensor=$CONFIG_SENSOR_TYPE screen=$SCREEN_TYPE wifi=$WIFI_TYPE imu=$IMU_TYPE eth=$ETHERNET): fill=$n_fill force=$n_force keep_built=$n_keep" >&2
}

process_screen_driver()
{
    rm -rf rootfs/usr/modules/ts_*

    if test -z "$SCREEN_TYPE" ; then
        return
    fi

    if test "$SCREEN_TYPE" = "NO_SCREEN" ; then
        true
    else
        ts_src="$driver_ko_dir/../ts_${SCREEN_TYPE}.ko"
        if [ -f "$ts_src" ]; then
            cp -af "$ts_src" rootfs/usr/modules/
            echo "[driver] staged touch from build: $ts_src" >&2
        else
            echo "[driver] ts_${SCREEN_TYPE}.ko not in build out, wait board overlay" >&2
        fi
    fi
}

process_sensor_driver()
{
    rm -rf rootfs/usr/modules/sensor_*

    #cp -rf ko/external/sensor_*.ko rootfs/usr/modules/
    if test $CHIP_SERIES = "AK37E" ; then
    	cp -rf $driver_install_dir/external/sensor_gc0308.ko rootfs/usr/modules/
    	cp -rf $driver_install_dir/external/sensor_tp9950.ko rootfs/usr/modules/
    elif 	test $CHIP_SERIES = "AK37D" ; then
        cp -rf $driver_install_dir/external/sensor_ar0230.ko rootfs/usr/modules/
        cp -rf $driver_install_dir/external/sensor_pr2000.ko rootfs/usr/modules/
        cp -rf $driver_install_dir/external/sensor_ps5268.ko rootfs/usr/modules/
    elif 	test $CHIP_SERIES = "AK39EV33X" ; then
        cp -rf $driver_install_dir/external/sensor_f22_f23_f28_f35_f37.ko rootfs/usr/modules/
        cp -rf $driver_install_dir/external/sensor_sc3335.ko rootfs/usr/modules/
        cp -rf $driver_install_dir/external/sensor_gc4653.ko rootfs/usr/modules/
        cp -rf $driver_install_dir/external/sensor_gc2063.ko rootfs/usr/modules/
    elif 	test $CHIP_SERIES = "AK3918AV100" ; then
        cp -rf $driver_install_dir/external/sensor_sc3336.ko rootfs/usr/modules/
        cp -rf $driver_install_dir/external/sensor_gc4653.ko rootfs/usr/modules/
        cp -rf $driver_install_dir/external/sensor_gc2063.ko rootfs/usr/modules/
        cp -rf $driver_install_dir/external/sensor_sc2336.ko rootfs/usr/modules/
        cp -rf $driver_install_dir/external/sensor_sc2336x.ko rootfs/usr/modules/
		cp -rf $driver_install_dir/external/sensor_sc1346.ko rootfs/usr/modules/
        cp -rf $driver_install_dir/external/sensor_mis2008.ko rootfs/usr/modules/
        cp -rf $driver_install_dir/external/sensor_sc223a.ko rootfs/usr/modules/
        cp -rf $driver_install_dir/external/sensor_sc401ai.ko rootfs/usr/modules/
        cp -rf $driver_install_dir/external/sensor_gc3003.ko rootfs/usr/modules/
        cp -rf $driver_install_dir/external/sensor_sc5238.ko rootfs/usr/modules/
        cp -rf $driver_install_dir/external/sensor_h63_h63p.ko rootfs/usr/modules/
        cp -rf $driver_install_dir/external/sensor_gc2083.ko rootfs/usr/modules/
        cp -rf $driver_install_dir/external/ak_tsensor.ko rootfs/usr/modules/
    elif 	test $CHIP_SERIES = "AK3918EV300L" ; then
        cp -rf $driver_install_dir/external/sensor_gc2063.ko rootfs/usr/modules/
        cp -rf $driver_install_dir/external/sensor_gc2083.ko rootfs/usr/modules/
        cp -rf $driver_install_dir/external/sensor_sc2336.ko rootfs/usr/modules/
        cp -rf $driver_install_dir/external/sensor_sc223a.ko rootfs/usr/modules/
        cp -rf $driver_install_dir/external/sensor_sc3336.ko rootfs/usr/modules/
        cp -rf $driver_install_dir/external/sensor_gc3003.ko rootfs/usr/modules/
        cp -rf $driver_install_dir/external/sensor_h63_h63p.ko rootfs/usr/modules/
        cp -rf $driver_install_dir/external/sensor_sc1346.ko rootfs/usr/modules/
        cp -rf $driver_install_dir/external/sensor_mis2006.ko rootfs/usr/modules/
    elif 	test $CHIP_SERIES = "AK3918AV200" ; then
        sensor_src="$driver_ko_dir/sensor_${CONFIG_SENSOR_TYPE}.ko"
        if [ -f "$sensor_src" ]; then
            cp -af "$sensor_src" rootfs/usr/modules/
            echo "[driver] staged sensor from build: $sensor_src" >&2
        else
            echo "[driver] sensor_${CONFIG_SENSOR_TYPE}.ko not in build out, wait board overlay" >&2
        fi
    else
    	exit 1
    fi
}

# 安装驱动到文件系统
install_driver()
{
    # 删除文件统中遗留的文件
	if test -d rootfs/usr/modules ; then
        rm -rf rootfs/usr/modules/*
        rm -rf rootfs/lib/modules/*
    else
		mkdir rootfs/usr/modules
	fi

    #拷贝driver ko
    cp -rf $driver_ko_dir/*.ko rootfs/usr/modules

    #拷贝kernel ko
    cp -rf $driver_install_dir/internal/lib rootfs/
    rm -rf rootfs/lib/modules/4.4.*/kernel/crypto/
    rm -rf rootfs/lib/modules/4.4.*/kernel/drivers/staging/rtl8188eu
    rm -rf rootfs/lib/modules/4.4.*/kernel/net/wireless/mac80211.ko
    rm -rf rootfs/lib/modules/4.4.*/kernel/net/bridge/*.ko
    rm -rf rootfs/lib/modules/4.4.*/kernel/net/llc/llc.ko
    rm -rf rootfs/lib/modules/4.4.*/kernel/net/802/stp.ko
    # 5.10 kernel's own cfg80211 lacks cfg80211_bss_color_notify (ATBM6162 BSP
    # backport symbol); if it gets loaded first, ATBM6162_wifi_sdio fails with
    # "Unknown symbol". Drop the vanilla wireless modules so the only cfg80211
    # provider is the board-verified companion in rootfs/usr/modules.
    rm -f rootfs/lib/modules/*/kernel/net/wireless/cfg80211.ko
    rm -f rootfs/lib/modules/*/kernel/net/mac80211/mac80211.ko

    process_wifi_driver

    process_screen_driver

    process_sensor_driver

    overlay_board_reference_modules
}

# 安装平台中间件的库文件到文件系统
install_platform()
{
    cp -rf $CONFIG_TOP_DIR/platform/lib/*.so rootfs/usr/lib
    rm -rf rootfs/usr/lib/*.so
}

prepare_install_pack_and_exclude_list()
{
    # Flash usr.sqsh4 (/usr): lib/, gui/image/, ipc_main, apps/setting, sbin/, tips/
    # SD install/ (/mnt/install): other apps + model/ (never pack model into usr)

    if [ ! -d rootfs/usr ]; then
        echo "[install] rootfs/usr missing, skip install prepare." >&2
        return 0
    fi

    utils_usr_dir=""
    if [ -d utils/usr ]; then
        utils_usr_dir="utils/usr"
    elif [ -d rootfs/utils/usr ]; then
        utils_usr_dir="rootfs/utils/usr"
    fi
    if [ -z "$utils_usr_dir" ]; then
        echo "[install] utils/usr and rootfs/utils/usr are both missing, skip install prepare." >&2
        return 0
    fi

    install_stage_dir="install"
    install_exclude_file="install.exclude"
    rm -rf "$install_stage_dir" 2>/dev/null || true
    rm -f "$install_exclude_file" 2>/dev/null || true
    mkdir -p "$install_stage_dir"
    : > "$install_exclude_file"

    echo "[install] keep lib/ + ipc_main + gui + apps/setting + sbin/ + tips/ in usr.sqsh4 (/usr)" >&2

    if [ -d "$utils_usr_dir/lib" ]; then
        mkdir -p rootfs/usr/lib
        cp -af "$utils_usr_dir/lib"/. rootfs/usr/lib/ 2>/dev/null || true
    fi

    ipc_name="${CONFIG_APP_MAIN_TARGET:-ipc_main}"
    ipc_src=""
    for cand in "./rootfs/$ipc_name" "./$ipc_name" "./rootfs/ipc_main" "rootfs/usr/sbin/$ipc_name"; do
        if [ -f "$cand" ]; then
            ipc_src="$cand"
            break
        fi
    done
    if [ -n "$ipc_src" ]; then
        mkdir -p rootfs/usr/sbin
        cp -af "$ipc_src" "rootfs/usr/sbin/$ipc_name"
        chmod +x "rootfs/usr/sbin/$ipc_name" 2>/dev/null || true
        echo "[install] $ipc_name on flash: rootfs/usr/sbin/$ipc_name (from $ipc_src)" >&2
        # Drop the old ipc_home alias so the process name stays $ipc_name.
        rm -f rootfs/usr/sbin/ipc_home 2>/dev/null || true
    else
        echo "[install] WARN: $ipc_name not found; usr.sqsh4 may miss main binary" >&2
    fi

    gui_img_src=""
    if [ -n "$SRC_APPLICATION_DIR" ] && [ -d "$SRC_APPLICATION_DIR/packages/tablet/launcher/res/image" ]; then
        gui_img_src="$SRC_APPLICATION_DIR/packages/tablet/launcher/res/image"
    elif [ -n "$PROJECT_ROOT" ] && [ -d "$PROJECT_ROOT/../../application/packages/tablet/launcher/res/image" ]; then
        gui_img_src="$PROJECT_ROOT/../../application/packages/tablet/launcher/res/image"
    elif [ -n "$SRC_APPLICATION_DIR" ] && [ -d "$SRC_APPLICATION_DIR/gui/nova/launcher/res/image" ]; then
        gui_img_src="$SRC_APPLICATION_DIR/gui/nova/launcher/res/image"
    elif [ -n "$PROJECT_ROOT" ] && [ -d "$PROJECT_ROOT/../../application/gui/nova/launcher/res/image" ]; then
        gui_img_src="$PROJECT_ROOT/../../application/gui/nova/launcher/res/image"
    fi
    lcd_w="${CONFIG_LCD_HOR_RES:-${LCD_HOR_RES_MAX:-800}}"
    lcd_h="${CONFIG_LCD_VER_RES:-${LCD_VER_RES_MAX:-480}}"
    gui_res_tag="${lcd_w}x${lcd_h}"
    gui_res_src=""
    if [ -n "$gui_img_src" ] && [ -d "$gui_img_src/$gui_res_tag" ]; then
        gui_res_src="$gui_img_src/$gui_res_tag"
    elif [ -n "$gui_img_src" ] && [ "$(ls -A "$gui_img_src" 2>/dev/null)" ]; then
        gui_res_src="$gui_img_src"
    fi
    if [ -n "$gui_res_src" ]; then
        mkdir -p rootfs/usr/gui/image
        cp -af "$gui_res_src"/. rootfs/usr/gui/image/ 2>/dev/null || true
        n_gui=$(find rootfs/usr/gui/image -type f 2>/dev/null | wc -l)
        echo "[install] staged gui images -> rootfs/usr/gui/image/ ($n_gui files)" >&2
    else
        echo "[install] launcher res/image/$gui_res_tag not found, skip gui image stage" >&2
    fi

    if [ -d rootfs/usr/apps ] && [ "$(ls -A rootfs/usr/apps 2>/dev/null)" ]; then
        mkdir -p "$install_stage_dir/apps"
        for app_dir in rootfs/usr/apps/*; do
            [ -d "$app_dir" ] || continue
            app_id=$(basename "$app_dir")
            if [ "$app_id" = "setting" ]; then
                echo "[install] keep apps/setting on usr flash" >&2
                continue
            fi
            rm -rf "$install_stage_dir/apps/$app_id"
            cp -af "$app_dir" "$install_stage_dir/apps/" 2>/dev/null || true
            echo "apps/$app_id" >> "$install_exclude_file"
            rm -rf "$app_dir"
            echo "[install] staged apps/$app_id -> SD install/ (removed from usr)" >&2
        done
    else
        echo "[install] rootfs/usr/apps missing or empty, skip apps stage" >&2
    fi
    # Also strip non-setting apps from utils overlay so they are not re-copied later.
    if [ -n "$utils_usr_dir" ] && [ -d "$utils_usr_dir/apps" ]; then
        for app_dir in "$utils_usr_dir/apps"/*; do
            [ -d "$app_dir" ] || continue
            app_id=$(basename "$app_dir")
            [ "$app_id" = "setting" ] && continue
            rm -rf "$app_dir"
            echo "[install] removed utils apps/$app_id (SD-only)" >&2
        done
    fi

    # Volc RTC Lite (~9MB): keep with volc app on SD, not in usr/lib (ipc_main DT_NEEDED
    # resolves via LD_LIBRARY_PATH .../apps/volc_engine/lib).
    stage_volc_rtclite_to_install_app

    # Drop unused shared libs from flash usr (ipc_main already static-links LVGL;
    # websockets not DT_NEEDED by any usr binary in current nova config).
    # libpng/libz/libfreetype/libzxing: stay in /usr/lib (from rootfs/utils/usr/lib via application Makefile).
    trim_unused_usr_shared_libs
    # Keep usr/sbin and usr/tips on flash — do not stage them to burntool/install.

    model_src=""
    if [ -d rootfs/usr/model ] && [ "$(ls -A rootfs/usr/model 2>/dev/null)" ]; then
        model_src="rootfs/usr/model"
    elif [ -d "$utils_usr_dir/model" ] && [ "$(ls -A "$utils_usr_dir/model" 2>/dev/null)" ]; then
        model_src="$utils_usr_dir/model"
    fi
    if [ -n "$model_src" ]; then
        mkdir -p "$install_stage_dir/model"
        cp -af "$model_src"/. "$install_stage_dir/model/" 2>/dev/null || true
        echo "model" >> "$install_exclude_file"
        rm -rf rootfs/usr/model
        echo "[install] staged model -> SD install/model (removed from usr)" >&2
    fi

    stage_tslib_to_usr

    echo "[install] exclude_file=$install_exclude_file entries=$(wc -l < "$install_exclude_file" 2>/dev/null || echo 0)" >&2
}

# Move libVolcEngineRTCLite.so out of flash usr/lib into SD volc_engine app.
stage_volc_rtclite_to_install_app()
{
    local rtc_name="libVolcEngineRTCLite.so"
    local rtc_src=""
    local dest_dir="$install_stage_dir/apps/volc_engine/lib"

    for cand in \
        "rootfs/usr/lib/$rtc_name" \
        "$utils_usr_dir/lib/$rtc_name"
    do
        if [ -n "$cand" ] && [ -f "$cand" ]; then
            rtc_src="$cand"
            break
        fi
    done
    if [ -z "$rtc_src" ] && [ -n "$APPLICATION_INSTALL_DIR" ] && \
        [ -f "$APPLICATION_INSTALL_DIR/lib/$rtc_name" ]; then
        rtc_src="$APPLICATION_INSTALL_DIR/lib/$rtc_name"
    fi

    if [ -z "$rtc_src" ]; then
        echo "[install] $rtc_name not found, skip volc RTC stage" >&2
        return 0
    fi

    mkdir -p "$dest_dir"
    cp -af "$rtc_src" "$dest_dir/$rtc_name"
    chmod +x "$dest_dir/$rtc_name" 2>/dev/null || true

    echo "lib/$rtc_name" >> "$install_exclude_file"
    rm -f "rootfs/usr/lib/$rtc_name" 2>/dev/null || true

    echo "[install] staged $rtc_name -> SD $dest_dir/ (excluded from usr.sqsh4)" >&2
}

# Remove flash-bloat / unused .so; runtime libs stay in flash /usr/lib (from rootfs/utils/usr/lib).
# libwebsockets: never ship — WSS/Aliyun off on Nova; delete leftover from old builds.
# liblvgl: static in ipc_main — delete from usr and leftover SD.
# libpng / libz / libfreetype / libzxing: keep in /usr/lib (application/Makefile -> utils/usr/lib).
trim_unused_usr_shared_libs()
{
    local f
    local path

    for f in \
        rootfs/usr/lib/libwebsockets.so \
        rootfs/usr/lib/libwebsockets.so.* \
        "$install_stage_dir/lib/libwebsockets.so" \
        "$install_stage_dir/lib/libwebsockets.so."*
    do
        for path in $f; do
            [ -e "$path" ] || continue
            rm -f "$path"
            echo "[install] removed leftover $(basename "$path") (WSS unused on Nova)" >&2
        done
    done

    # LVGL is statically linked into ipc_main for Home; never ship liblvgl.so
    # (framework still builds .so as a byproduct — drop from usr and leftover SD).
    for f in \
        rootfs/usr/lib/liblvgl.so \
        rootfs/usr/lib/liblvgl.so.* \
        "$install_stage_dir/lib/liblvgl.so" \
        "$install_stage_dir/lib/liblvgl.so."*
    do
        for path in $f; do
            [ -e "$path" ] || continue
            rm -f "$path"
            echo "[install] removed $(basename "$path") (LVGL static in ipc_main; not deferred so)" >&2
        done
    done

    # Purge legacy burntool/install/lib copies; flash /usr/lib is canonical.
    for f in \
        "$install_stage_dir/lib/libpng.so" \
        "$install_stage_dir/lib/libpng.so."* \
        "$install_stage_dir/lib/libpng16.so" \
        "$install_stage_dir/lib/libpng16.so."* \
        "$install_stage_dir/lib/libz.so" \
        "$install_stage_dir/lib/libz.so."* \
        "$install_stage_dir/lib/libfreetype.so" \
        "$install_stage_dir/lib/libfreetype.so."* \
        "$install_stage_dir/lib/libzxing.so" \
        "$install_stage_dir/lib/libzxing.so."*
    do
        for path in $f; do
            [ -e "$path" ] || [ -L "$path" ] || continue
            rm -f "$path"
            echo "[install] removed SD leftover $(basename "$path") (keep in /usr/lib)" >&2
        done
    done
}

# Stage tslib into /usr/lib/ts on flash.
stage_tslib_to_usr()
{
    local tslib_src=""
    local tslib_lib_src=""
    local tslib_plugin_src=""
    local n_plugins=0

    if [ -z "$THIRD_PARTY_INSTALL_DIR" ]; then
        echo "[tslib] THIRD_PARTY_INSTALL_DIR unset, skip usr tslib." >&2
        return 0
    fi

    tslib_src="$THIRD_PARTY_INSTALL_DIR/tslib"
    if [ ! -d "$tslib_src" ]; then
        echo "[tslib] install dir missing: $tslib_src, skip." >&2
        return 0
    fi

    if [ -d "$tslib_src/usr/lib/ts" ]; then
        tslib_lib_src="$tslib_src/usr/lib"
        tslib_plugin_src="$tslib_src/usr/lib/ts"
    elif [ -d "$tslib_src/lib/ts" ]; then
        tslib_lib_src="$tslib_src/lib"
        tslib_plugin_src="$tslib_src/lib/ts"
    else
        echo "[tslib] ERROR: plugin dir not found under $tslib_src" >&2
        exit 1
    fi

    mkdir -p rootfs/usr/lib/ts
    cp -af "$tslib_lib_src"/libts.so* rootfs/usr/lib/ 2>/dev/null || true
    cp -af "$tslib_plugin_src"/*.so rootfs/usr/lib/ts/ 2>/dev/null || true
    n_plugins=$(ls -1 rootfs/usr/lib/ts/*.so 2>/dev/null | wc -l)
    echo "[tslib] staged to rootfs/usr/lib/ts plugins=$n_plugins" >&2
    if [ ! -f rootfs/usr/lib/ts/input.so ]; then
        echo "[tslib] ERROR: input.so missing under rootfs/usr/lib/ts" >&2
        exit 1
    fi
    rm -rf rootfs/usr/bin/tslib 2>/dev/null || true
}
process_flash_scripts()
{
    if test $FLASH_TYPE = "NOR" ; then
        cp ./scripts/flash/rc.local.nor rootfs/etc/init.d/rc.local
        cp ./scripts/flash/update.nor.sh rootfs/sbin/update.sh
    elif test $FLASH_TYPE = "NAND" ; then
        cp ./scripts/flash/rc.local.nand rootfs/etc/init.d/rc.local
        cp ./scripts/flash/update.nand.sh rootfs/sbin/update.sh
		cp ./scripts/flash/nand_update rootfs/bin/nand_update
    elif test $FLASH_TYPE = "MMC" ; then
        echo "update.sh didn't support now!"
        cp ./scripts/flash/rc.local.mmc rootfs/etc/init.d/rc.local
    else
        echo "Flash type error, please check!"
        exit 1
    fi
    
    if test "$CONFIG_SYS_BOOT_MODE" = "FAST" ; then
    	cp ./scripts/flash/fast.rcS rootfs/etc/init.d/rcS
    fi
    cp ./scripts/flash/update_ddr.sh rootfs/sbin/update_ddr.sh
}

process_sensor_scripts()
{
    cp scripts/sensor/*.sh rootfs/usr/sbin/
}

process_screen_scripts()
{
    if test -z $SCREEN_TYPE ; then
        return
    fi
}

process_lcd_scripts()
{
    cp $driver_ko_dir/ak_lcd.ko rootfs/usr/modules/
    cp scripts/screen/lcd.sh rootfs/usr/sbin/
}

process_wifi_scripts()
{
    # 根据选择的WIFI类型，清理掉无用的驱动
    if test $WIFI_TYPE = "NO_WIFI" ; then
        true
    elif test $WIFI_TYPE = "rtl8188ftv" ; then
        cp scripts/wifi/rtl8188.sh rootfs/usr/sbin/wifi_driver.sh
        cp -rf ./wifi/* rootfs/
        rm rootfs/usr/sbin/atbm_cli_6062
        rm rootfs/usr/sbin/atbm_tool_6062
        rm rootfs/usr/sbin/nimble_linux_6062
        rm rootfs/usr/sbin/atbm_cli_6132
        rm rootfs/usr/sbin/atbm_tool_6132
        rm rootfs/usr/sbin/nimble_linux_6132
        rm rootfs/usr/sbin/atbm_cli_6031x_300w
        rm rootfs/usr/sbin/atbm_tool_6031x_300w
        rm rootfs/usr/sbin/nimble_linux_6031x_300w
    elif test $WIFI_TYPE = "rtl8189ftv" ; then
        cp scripts/wifi/rtl8189.sh rootfs/usr/sbin/wifi_driver.sh
        cp -rf ./wifi/* rootfs/
        rm rootfs/usr/sbin/atbm_cli_6062
        rm rootfs/usr/sbin/atbm_tool_6062
        rm rootfs/usr/sbin/nimble_linux_6062
        rm rootfs/usr/sbin/atbm_cli_6132
        rm rootfs/usr/sbin/atbm_tool_6132
        rm rootfs/usr/sbin/nimble_linux_6132
        rm rootfs/usr/sbin/atbm_cli_6031x_300w
        rm rootfs/usr/sbin/atbm_tool_6031x_300w
        rm rootfs/usr/sbin/nimble_linux_6031x_300w
    elif test $WIFI_TYPE = "atbm6031" ; then
        cp scripts/wifi/atbm6031.sh rootfs/usr/sbin/wifi_driver.sh
        cp -rf ./wifi/* rootfs/
        rm rootfs/usr/sbin/atbm_cli_6062
        rm rootfs/usr/sbin/atbm_tool_6062
        rm rootfs/usr/sbin/nimble_linux_6062
        rm rootfs/usr/sbin/atbm_cli_6132
        rm rootfs/usr/sbin/atbm_tool_6132
        rm rootfs/usr/sbin/nimble_linux_6132
        rm rootfs/usr/sbin/atbm_cli_6031x_300w
        rm rootfs/usr/sbin/atbm_tool_6031x_300w
        rm rootfs/usr/sbin/nimble_linux_6031x_300w
    elif test $WIFI_TYPE = "atbm6032" ; then
        cp scripts/wifi/atbm6032.sh rootfs/usr/sbin/wifi_driver.sh
        cp -rf ./wifi/* rootfs/
        rm rootfs/usr/sbin/atbm_cli_6062
        rm rootfs/usr/sbin/atbm_tool_6062
        rm rootfs/usr/sbin/nimble_linux_6062
        rm rootfs/usr/sbin/atbm_cli_6132
        rm rootfs/usr/sbin/atbm_tool_6132
        rm rootfs/usr/sbin/nimble_linux_6132
        rm rootfs/usr/sbin/atbm_cli_6031x_300w
        rm rootfs/usr/sbin/atbm_tool_6031x_300w
        rm rootfs/usr/sbin/nimble_linux_6031x_300w
    elif test $WIFI_TYPE = "atbm6012b" ; then
        cp scripts/wifi/atbm6032.sh rootfs/usr/sbin/wifi_driver.sh
        cp -rf ./wifi/* rootfs/
        rm rootfs/usr/sbin/atbm_cli_6062
        rm rootfs/usr/sbin/atbm_tool_6062
        rm rootfs/usr/sbin/nimble_linux_6062
        rm rootfs/usr/sbin/atbm_cli_6132
        rm rootfs/usr/sbin/atbm_tool_6132
        rm rootfs/usr/sbin/nimble_linux_6132
        rm rootfs/usr/sbin/atbm_cli_6031x_300w
        rm rootfs/usr/sbin/atbm_tool_6031x_300w
        rm rootfs/usr/sbin/nimble_linux_6031x_300w
    elif test $WIFI_TYPE = "atbm6132" ; then
        cp scripts/wifi/atbm6132.sh rootfs/usr/sbin/wifi_driver.sh
        cp scripts/wifi/wifi_bt_driver_6132.sh rootfs/usr/sbin/
        cp scripts/wifi/connect_ap.sh rootfs/usr/sbin/
        cp -rf ./wifi/* rootfs/
        rm rootfs/usr/sbin/atbm_cli
        rm rootfs/usr/sbin/atbm_tool
        rm rootfs/usr/sbin/nimble_linux
        rm rootfs/usr/sbin/atbm_cli_6062
        rm rootfs/usr/sbin/atbm_tool_6062
        rm rootfs/usr/sbin/nimble_linux_6062
        rm rootfs/usr/sbin/atbm_cli_6031x_300w
        rm rootfs/usr/sbin/atbm_tool_6031x_300w
        rm rootfs/usr/sbin/nimble_linux_6031x_300w
        mv rootfs/usr/sbin/atbm_cli_6132 rootfs/usr/sbin/atbm_cli
        mv rootfs/usr/sbin/atbm_tool_6132 rootfs/usr/sbin/atbm_tool
        mv rootfs/usr/sbin/nimble_linux_6132 rootfs/usr/sbin/nimble_linux
    elif test $WIFI_TYPE = "atbm6031x" ; then
        cp scripts/wifi/atbm6031x.sh rootfs/usr/sbin/wifi_driver.sh
        cp scripts/wifi/wifi_bt_driver_6031x.sh rootfs/usr/sbin/
        cp scripts/wifi/connect_ap.sh rootfs/usr/sbin/
        cp -rf ./wifi/* rootfs/
        rm rootfs/usr/sbin/atbm_cli_6062
        rm rootfs/usr/sbin/atbm_tool_6062
        rm rootfs/usr/sbin/nimble_linux_6062
        rm rootfs/usr/sbin/atbm_cli_6132
        rm rootfs/usr/sbin/atbm_tool_6132
        rm rootfs/usr/sbin/nimble_linux_6132
        if 	test $CONFIG_CHIP_TYPE = "AK3918EV300W" ; then
            echo "chip type is AK3918EV300W!"
            rm rootfs/usr/sbin/atbm_cli
            rm rootfs/usr/sbin/atbm_tool
            rm rootfs/usr/sbin/nimble_linux
            mv rootfs/usr/sbin/atbm_cli_6031x_300w rootfs/usr/sbin/atbm_cli
            mv rootfs/usr/sbin/atbm_tool_6031x_300w rootfs/usr/sbin/atbm_tool
            mv rootfs/usr/sbin/nimble_linux_6031x_300w rootfs/usr/sbin/nimble_linux
        else
        	  echo "chip type is not AK3918EV300W!"
            rm rootfs/usr/sbin/atbm_cli_6031x_300w
            rm rootfs/usr/sbin/atbm_tool_6031x_300w
            rm rootfs/usr/sbin/nimble_linux_6031x_300w
        fi
    elif test $WIFI_TYPE = "atbm6012bx" ; then
        cp scripts/wifi/atbm6012bx.sh rootfs/usr/sbin/wifi_driver.sh
        cp scripts/wifi/wifi_bt_driver_6012bx.sh rootfs/usr/sbin/
        cp scripts/wifi/connect_ap.sh rootfs/usr/sbin/
        cp -rf ./wifi/* rootfs/
        rm rootfs/usr/sbin/atbm_cli_6062
        rm rootfs/usr/sbin/atbm_tool_6062
        rm rootfs/usr/sbin/nimble_linux_6062
        rm rootfs/usr/sbin/atbm_cli_6132
        rm rootfs/usr/sbin/atbm_tool_6132
        rm rootfs/usr/sbin/nimble_linux_6132
        rm rootfs/usr/sbin/atbm_cli_6031x_300w
        rm rootfs/usr/sbin/atbm_tool_6031x_300w
        rm rootfs/usr/sbin/nimble_linux_6031x_300w
    elif test $WIFI_TYPE = "atbm6062u" ; then
        cp scripts/wifi/atbm6062u.sh rootfs/usr/sbin/wifi_driver.sh
        cp scripts/wifi/wifi_bt_driver_6062u.sh rootfs/usr/sbin/
        cp scripts/wifi/connect_ap.sh rootfs/usr/sbin/
        cp -rf ./wifi/* rootfs/
        rm rootfs/usr/sbin/atbm_cli
        rm rootfs/usr/sbin/atbm_tool
        rm rootfs/usr/sbin/nimble_linux
        rm rootfs/usr/sbin/atbm_cli_6132
        rm rootfs/usr/sbin/atbm_tool_6132
        rm rootfs/usr/sbin/nimble_linux_6132
        rm rootfs/usr/sbin/atbm_cli_6031x_300w
        rm rootfs/usr/sbin/atbm_tool_6031x_300w
        rm rootfs/usr/sbin/nimble_linux_6031x_300w
        mv rootfs/usr/sbin/atbm_cli_6062 rootfs/usr/sbin/atbm_cli
        mv rootfs/usr/sbin/atbm_tool_6062 rootfs/usr/sbin/atbm_tool
        mv rootfs/usr/sbin/nimble_linux_6062 rootfs/usr/sbin/nimble_linux
    elif test $WIFI_TYPE = "atbm6062s" ; then
        cp scripts/wifi/atbm6062s.sh rootfs/usr/sbin/wifi_driver.sh
        cp scripts/wifi/wifi_bt_driver_6062s.sh rootfs/usr/sbin/
        cp scripts/wifi/connect_ap.sh rootfs/usr/sbin/
        cp -rf ./wifi/* rootfs/
        rm rootfs/usr/sbin/atbm_cli
        rm rootfs/usr/sbin/atbm_tool
        rm rootfs/usr/sbin/nimble_linux
        rm rootfs/usr/sbin/atbm_cli_6132
        rm rootfs/usr/sbin/atbm_tool_6132
        rm rootfs/usr/sbin/nimble_linux_6132
        rm rootfs/usr/sbin/atbm_cli_6031x_300w
        rm rootfs/usr/sbin/atbm_tool_6031x_300w
        rm rootfs/usr/sbin/nimble_linux_6031x_300w
        mv rootfs/usr/sbin/atbm_cli_6062 rootfs/usr/sbin/atbm_cli
        mv rootfs/usr/sbin/atbm_tool_6062 rootfs/usr/sbin/atbm_tool
        mv rootfs/usr/sbin/nimble_linux_6062 rootfs/usr/sbin/nimble_linux
    elif test $WIFI_TYPE = "ssv6x5x" ; then
        cp scripts/wifi/ssv6x5x.sh rootfs/usr/sbin/wifi_driver.sh
        cp -rf ./wifi/* rootfs/
        rm rootfs/usr/sbin/atbm_cli_6062
        rm rootfs/usr/sbin/atbm_tool_6062
        rm rootfs/usr/sbin/nimble_linux_6062
        rm rootfs/usr/sbin/atbm_cli_6132
        rm rootfs/usr/sbin/atbm_tool_6132
        rm rootfs/usr/sbin/nimble_linux_6132
        rm rootfs/usr/sbin/atbm_cli_6031x_300w
        rm rootfs/usr/sbin/atbm_tool_6031x_300w
        rm rootfs/usr/sbin/nimble_linux_6031x_300w
    elif test $WIFI_TYPE = "atbm6162" ; then
        cp -rf ./wifi/* rootfs/
        rm rootfs/usr/sbin/atbm_cli_6062
        rm rootfs/usr/sbin/atbm_tool_6062
        rm rootfs/usr/sbin/nimble_linux_6062
        rm rootfs/usr/sbin/atbm_cli_6132
        rm rootfs/usr/sbin/atbm_tool_6132
        rm rootfs/usr/sbin/nimble_linux_6132
        rm rootfs/usr/sbin/atbm_cli_6031x_300w
        rm rootfs/usr/sbin/atbm_tool_6031x_300w
        rm rootfs/usr/sbin/nimble_linux_6031x_300w
        # wifi_driver.sh from patch utils (ATBM6162 SDIO); process_utils copies it later
    else
        echo "Wifi Type Error, please check!"
        exit 1
    fi
    
    rm -rf rootfs/usr/sbin/wpa3

}

process_fs_scripts()
{
    cp -rf scripts/fs/* rootfs/usr/sbin/
}

process_other_scripts()
{
    cp -rf scripts/others/* rootfs/usr/sbin/
    rm -rf rootfs/usr/sbin/key_gpio.sh
}

process_utils()
{
	UTILS_SUPPORT=1
    if test $UTILS_SUPPORT -eq 1 ; then
        cp -rf utils/* rootfs/
        # / is read-only squashfs at runtime: udhcpc cannot publish DHCP DNS into
        # /etc. Point resolv.conf at tmpfs (udhcpc_wlan.sh writes /tmp/resolv.conf).
        rm -f rootfs/etc/resolv.conf
        ln -snf /tmp/resolv.conf rootfs/etc/resolv.conf
        # Windows CRLF breaks ash/sh on device (": not found", shebang /bin/sh\r).
        # sed -i rewrites via temp+rename and drops the executable bit; chmod +x after.
        find rootfs/usr/sbin rootfs/etc/init.d -type f -name '*.sh' 2>/dev/null | while IFS= read -r f; do
            sed -i 's/\r$//' "$f" 2>/dev/null || true
            chmod +x "$f" 2>/dev/null || true
        done
        if [ -f rootfs/usr/sbin/mount_install.sh ]; then
            sed -i 's/\r$//' rootfs/usr/sbin/mount_install.sh 2>/dev/null || true
            chmod +x rootfs/usr/sbin/mount_install.sh 2>/dev/null || true
        fi
        if [ -f rootfs/usr/sbin/usb_udc.sh ]; then
            sed -i 's/\r$//' rootfs/usr/sbin/usb_udc.sh 2>/dev/null || true
            chmod +x rootfs/usr/sbin/usb_udc.sh 2>/dev/null || true
        fi
        if [ -f rootfs/usr/sbin/storage_mode_switch.sh ]; then
            sed -i 's/\r$//' rootfs/usr/sbin/storage_mode_switch.sh 2>/dev/null || true
            chmod +x rootfs/usr/sbin/storage_mode_switch.sh 2>/dev/null || true
        fi
        if [ -f rootfs/usr/sbin/storage_mode_restart_ipc.sh ]; then
            sed -i 's/\r$//' rootfs/usr/sbin/storage_mode_restart_ipc.sh 2>/dev/null || true
            chmod +x rootfs/usr/sbin/storage_mode_restart_ipc.sh 2>/dev/null || true
        fi
        if 	test $CHIP_SERIES = "AK3918AV100" ; then
          rm -f rootfs/usr/sbin/dt320_param.bin
          rm -f rootfs/usr/sbin/dt480_param.bin
          rm -f rootfs/usr/sbin/dt640_param.bin
          rm -f rootfs/usr/sbin/fr224_param.bin
          rm -f rootfs/usr/sbin/fas224_param.bin
          rm -f rootfs/usr/sbin/model_0x0A000000_V1.1.01.bin
          rm -f rootfs/usr/sbin/model_0x0A000002_V1.1.02.bin
          rm -f rootfs/usr/sbin/model_0x0A00000D_V1.0.00.bin
          rm rootfs/usr/sbin/crydet*.bin
          rm -f rootfs/usr/sbin/model_0x0A00000A_V1.0.01.bin
          rm -f rootfs/usr/sbin/model_0x0A00000B_V1.0.00.bin
          rm -f rootfs/usr/sbin/model_0x0A00000C_V1.0.0.bin
          rm -f rootfs/usr/sbin/model_0x0A00000C_V1.0.00.bin
          rm -f rootfs/usr/sbin/model_0x0A000009_V1.0.00.bin
        elif 	test $CHIP_SERIES = "AK3918AV200" ; then
          rm -f utils/usr/sbin/yolov5n_640*
          rm -f rootfs/usr/sbin/yolov5n_640*
          rm -f utils/usr/sbin/yolov5c_480*
          rm -f rootfs/usr/sbin/yolov5c_480*
          rm -f utils/usr/sbin/ak_ddr_param
          rm -f rootfs/usr/sbin/ak_ddr_param
          rm -f utils/usr/sbin/model*
          rm -f rootfs/usr/sbin/model*
          rm -f utils/usr/sbin/upperbody640_opt
          rm -f rootfs/usr/sbin/upperbody640_opt
          rm -f rootfs/usr/sbin/model*
          rm -f rootfs/usr/sbin/ftpd
          rm -f rootfs/usr/sbin/tftp*
          rm -rf rootfs/usr/sbin/yolov5n_v1_640
        fi
    fi
}

#安装samples
install_samples()
{
    if [ -d $sample_install_dir ];then
        cp -rf $sample_install_dir/* rootfs/usr/bin
    fi
}

# 安装各类脚本
install_scripts()
{
    process_flash_scripts
    
    process_lcd_scripts

    process_screen_scripts

    process_sensor_scripts

    process_wifi_scripts

    process_fs_scripts

    process_other_scripts

    process_utils

    # settings.json / installed_apps.json / weather.json ship from the board's own
    # rootfs/utils/etc/config/ (already staged into utils/ above and merged into
    # rootfs/ by process_utils). The top-level project config/ mirror is retired;
    # do not re-copy over the board copy here.
    # PROJECT_ROOT itself is still needed as a fallback GUI-resource path by
    # prepare_install_pack_and_exclude_list() (called after install_scripts), so
    # keep computing it.
    if [ -n "$SCRIPT_ABS_DIR" ]; then
        PROJECT_ROOT=$(cd "$SCRIPT_ABS_DIR/../../../../.." 2>/dev/null && pwd)
    fi
}

prepare_image()
{
    extract_fs
    install_platform

    install_driver

    install_scripts

    # After install_scripts/process_utils deploy runtime libs into rootfs.
    # Keep lib/gui/ipc_main/apps/setting/sbin/tips on flash /usr; stage other apps+model to SD install/.
    prepare_install_pack_and_exclude_list

#    install_samples
}

# 制作烧录镜像
make_image()
{
    # 制作fast boot rootfs镜像
    if test "$SYS_BOOT_MODE" = "FAST" ; then
        if test "$FLASH_TYPE" = "NOR" ; then
            ./create_initfs.sh all
            ./create_ramfs.sh all
            ./create_jffs2fs.sh
            ./create_squashfs.sh
            # 将制作好的烧录镜像放到burntool下
            cp -rf usr.sqsh4 $image_install_dir
            cp -rf usr.jffs2 $image_install_dir
            cp -rf root.sqsh4 $image_install_dir
            # install/: SD only, never listed in burntool download_to_nand
            if [ -d install ] && [ "$(ls -A install 2>/dev/null)" ]; then
                rm -rf "$image_install_dir/install"
                mkdir -p "$image_install_dir"
                cp -a install "$image_install_dir/"
            fi
        elif test "$FLASH_TYPE" = "NAND" ; then
            ./create_initfs_nand.sh all
            ./create_ramfs_nand.sh all
            # ./create_yaffs2fs_fast_ZKTeco.sh
            ./create_ubifs_fast_ZKTeco.sh
            # cp -rf *.yaffs2 $image_install_dir
            cp -rf *.ubi $image_install_dir
        fi
    else
        # 根据选择的Flash类型制作烧录镜像
        if test "$FLASH_TYPE" = "NOR" ; then
            ./create_jffs2fs.sh
            ./create_squashfs.sh
            # 将制作好的烧录镜像放到burntool下
            cp -rf usr.sqsh4 $image_install_dir
            cp -rf usr.jffs2 $image_install_dir
			cp -rf data.sqsh4 $image_install_dir
            cp -rf root.sqsh4 $image_install_dir
            if [ -d install ] && [ "$(ls -A install 2>/dev/null)" ]; then
                rm -rf "$image_install_dir/install"
                mkdir -p "$image_install_dir"
                cp -a install "$image_install_dir/"
            fi
        elif test $FLASH_TYPE = "NAND" ; then
            ./create_yaffs2fs.sh
            cp -rf *.yaffs2 $image_install_dir
        elif test $FLASH_TYPE = "MMC" ; then
            ./create_fat32.sh
            ./create_squashfs.sh

            cp -rf usr.sqsh4 $image_install_dir
            cp -rf usr.fat32 $image_install_dir
            cp -rf root.sqsh4 $image_install_dir
            if [ -d install ] && [ "$(ls -A install 2>/dev/null)" ]; then
                rm -rf "$image_install_dir/install"
                mkdir -p "$image_install_dir"
                cp -a install "$image_install_dir/"
            fi
        fi
    fi

}

clean_image()
{
    echo "clean fs image..."
}

get_config_info

cd $rootfs_dir

case "$1" in
	all)
		prepare_image
		make_image
		;;
	prepare)
		prepare_image
		;;
	install)
		install_scripts
		make_image
		;;
	clean)
		clean_image
		;;
	*)
		echo "Usage:"
		echo " $0 all  : build all"
		echo " $0 clean: clean all"
		;;
esac

cd -

