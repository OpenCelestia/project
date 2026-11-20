// SPDX-License-Identifier: Apache-2.0
#ifndef PROJECT_APP_PRODUCT_CONFIG_H
#define PROJECT_APP_PRODUCT_CONFIG_H

#include "config.h"

#define USE_LCD_ROTATE_90                   0
#define USE_LCD_ROTATE_180                  0
#define USE_LCD_ROTATE_270                  0

/* system.ini (SYSTEM_CONFIG_FILE/SYSTEM_CONFIG_BACKLIGHT_SECTION), isp.ini
 * (ISP_CONFIG_FILE) and fw_wlan_config.ini (WLAN_CONFIG_FILE and its section/key
 * macros) were all removed, matching anypi_nova: none was ever referenced by
 * application/framework code or any board boot script. Backlight level and ISP
 * flip/tuning-path are sourced from the framework backlight device and
 * hal_camera_config.ini [camera0] mirror/flip/isp_config_path; WLAN station
 * ssid/psk are settings.json wifi.ssid/wifi.psk. */
/* media.audio_path / media.video_path live in settings.json (file manager).
 * MEDIA_CONFIG_FILE kept as legacy fallback path name only. */
#define MEDIA_CONFIG_FILE                   "/etc/config/media.ini"

/* Flash apps root (read-only at runtime; enable flags live in installed_apps.json). */
#define APPS_BASE_DIR                       "/usr/apps"

#define GUI_FONT_DIR                        "/usr/gui/font/"
#define FONT_FILE_PATH                      GUI_FONT_DIR "gui_font.ttf"
#define GUI_FONT_FILE_NAME                  "gui_font.ttf"
#define OSD_FONT_FILE_PATH                  GUI_FONT_DIR "ak_font_16.bin"
#define RES_IMAGE_PATH                      "/usr/gui/image"

#define CONFIG_PRINTF_FPS                   1
#define BACKLIGH_PWM_CHN                    3

#define CONFIG_LV_PORT_TINYJPEG             0
#define CONFIG_LV_PORT_LIBPNG               1
#define CONFIG_LV_PORT_LIBQOI               1
#define CONFIG_LV_PORT_STBIMAGE             1

#define CONFIG_VIDEO_DEVICE                 1

#if CONFIG_VIDEO_DEVICE
#define CONFIG_VIDEO_DEVICE_UVCH            0
#define CONFIG_VIDEO_DEVICE_SENSOR          1
#endif

#define AO_GAIN_LEVEL                       5

/* Tablet app module compile guards (from config.mk via config.h). */
#ifdef CONFIG_APP_TABLET_CAMERA
#define NOVA_CAMERA                         1
#define APP_GUI_CAMERA                      1
#else
#define NOVA_CAMERA                         0
#define APP_GUI_CAMERA                      0
#endif

#ifdef CONFIG_APP_TABLET_SETTING
#define NOVA_SETTING                        1
#else
#define NOVA_SETTING                        0
#endif

#define NOVA_INFO                           NOVA_SETTING

#ifdef CONFIG_APP_TABLET_VOLC_ENGINE
#define NOVA_VOLC                           1
#else
#define NOVA_VOLC                           0
#endif

#ifdef CONFIG_APP_TABLET_IPC_CAMERA
#define NOVA_CALL                           1
#else
#define NOVA_CALL                           0
#endif

#endif /* PROJECT_APP_PRODUCT_CONFIG_H */
