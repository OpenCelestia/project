// SPDX-License-Identifier: Apache-2.0
/*
 * Copyright (C) 2026 Guangzhou Anyka Microelectronics Co., Ltd.
 *
 * This file is part of Celestia/project/anypi_nova.
 *
 * Product-private compile-time constants for anypi_nova.
 * Only application layer should include this directly; shared/cross-layer
 * code should use app_globle_config.h (which includes this).
 */
#ifndef PROJECT_APP_PRODUCT_CONFIG_H
#define PROJECT_APP_PRODUCT_CONFIG_H

#include "config.h"

/* LCD rotation (anti-clockwise). ST7262 on ACTION board: no rotation needed. */
#define USE_LCD_ROTATE_90                   0
#define USE_LCD_ROTATE_180                  0
#define USE_LCD_ROTATE_270                  0

/* media config path (board-level).
 * SYSTEM_CONFIG_FILE (system.ini), ISP_CONFIG_FILE (isp.ini) and WLAN_CONFIG_FILE
 * (fw_wlan_config.ini) were all removed: none of the three, nor their section/key
 * macros, was ever referenced by application/framework code or any board boot
 * script. Backlight level and ISP flip/tuning-path are actually sourced from the
 * framework backlight device and hal_camera_config.ini [camera0] mirror/flip/
 * isp_config_path; WLAN station ssid/psk are settings.json wifi.ssid/wifi.psk —
 * fw_wlan_config.ini was only a legacy fallback inside network.c/network_compat.c
 * (whose callers are wearable-only / unused on Nova's tablet code path). */
/* media.audio_path / media.video_path live in settings.json (file manager).
 * MEDIA_CONFIG_FILE kept as legacy fallback path name only. */
#define MEDIA_CONFIG_FILE                   "/etc/config/media.ini"

/* Install pack mount paths (GUI apps / libs / models on external storage) */
#define INSTALL_MOUNT_DIR                   "/mnt/install"
#define INSTALL_LIB_DIR                     "/usr/lib"
#define INSTALL_TSLIB_PLUGINDIR             INSTALL_LIB_DIR "/ts"
#define INSTALL_MODEL_DIR                   INSTALL_MOUNT_DIR "/model"
/* Flash apps root (e.g. setting). Plugin apps/resources on SD use APPS_SD_BASE_DIR. */
#define APPS_BASE_DIR                       "/usr/apps"
#define APPS_SD_BASE_DIR                    INSTALL_MOUNT_DIR "/apps"

/* Font paths: unified with Luna under /usr/gui/font (OSD + GUI TTF) */
#define GUI_FONT_DIR                        "/usr/gui/font/"
#define FONT_FILE_PATH                      GUI_FONT_DIR "Chinese.ttf"
/* Prefer SD install copy when present (faster than NOR squashfs for ~1.7MB TTF). */
#define FONT_FILE_PATH_INSTALL              INSTALL_MOUNT_DIR "/gui/font/Chinese.ttf"
#define OSD_FONT_FILE_PATH                  GUI_FONT_DIR "ak_font_16.bin"

/*
 * GUI bitmap assets for ipc_main-integrated launcher (not a separate apps/launcher).
 * On SD: flat layout install/gui/image/weather|icon|... (WxH only in source tree).
 * Fallback: /usr/gui/image (anypi_nova_dev / flash layout).
 */
#define RES_IMAGE_ROOT                      "/usr/gui"
#define RES_IMAGE_PATH                      RES_IMAGE_ROOT "/image"
#define RES_IMAGE_PATH_LEGACY               "/mnt/install/gui/image"

/* Resolution-tagged subdirectory under .../res/image/: e.g. "800x480" */
#define _GUI_IMAGE_RES_TAG(w, h)            #w "x" #h
#define _GUI_IMAGE_RES_TAG_EXPAND(w, h)     _GUI_IMAGE_RES_TAG(w, h)
#define GUI_IMAGE_RES_TAG                   _GUI_IMAGE_RES_TAG_EXPAND(LCD_HOR_RES_MAX, LCD_VER_RES_MAX)
#define GUI_IMAGE_RES_PREFIX                GUI_IMAGE_RES_TAG

/* Debug / driver */
#define CONFIG_PRINTF_FPS                   1
#define BACKLIGH_PWM_CHN                    3

/* Image decoder feature flags */
#define CONFIG_LV_PORT_TINYJPEG             0
#define CONFIG_LV_PORT_LIBPNG               1
#define CONFIG_LV_PORT_LIBQOI               1
#define CONFIG_LV_PORT_STBIMAGE             1

/* Video input device */
#define CONFIG_VIDEO_DEVICE                 1
#if CONFIG_VIDEO_DEVICE
#define CONFIG_VIDEO_DEVICE_UVCH            0
#define CONFIG_VIDEO_DEVICE_SENSOR          1
#endif

/* Audio output gain (0=mute, 6=max) */
#define AO_GAIN_LEVEL                       5

#endif /* PROJECT_APP_PRODUCT_CONFIG_H */
