// SPDX-License-Identifier: Apache-2.0
#ifndef PROJECT_APP_GLOBLE_CONFIG_H
#define PROJECT_APP_GLOBLE_CONFIG_H

#include "app_product_config.h"

/* anti-clockwise rotation 90, 1-enable, 0-disable */
#define USE_LCD_ROTATE_90                   0

/* anti-clockwise rotation 180, 1-enable, 0-disable */
#define USE_LCD_ROTATE_180                  0

/* anti-clockwise rotation 270, 1-enable, 0-disable */
#define USE_LCD_ROTATE_270                  0

/* Horizontal width of the screen after rotation */
#define LCD_HOR_RES_MAX                     1024

/* Vertical height of the screen after rotation */
#define LCD_VER_RES_MAX                     600

/* system.ini, fw_wlan_config.ini and isp.ini (and the macros that used to point
 * at them: SYSTEM_CONFIG_FILE/SYSTEM_CONFIG_BACKLIGHT_SECTION, WLAN_CONFIG_FILE
 * and its section/key macros, ISP_CONFIG_FILE) were removed, matching
 * anypi_nova — none was ever referenced by name from application/framework code.
 * Backlight level and ISP flip/tuning-path are sourced from the framework
 * backlight device and hal_camera_config.ini [camera0] mirror/flip/
 * isp_config_path; WLAN station ssid/psk are settings.json wifi.ssid/wifi.psk. */

/* full path of media config */
#define MEDIA_CONFIG_FILE                   "/etc/config/media.ini"

/* full path of font file */
#undef  FONT_FILE_PATH
#define FONT_FILE_PATH                      "/usr/gui/font/Chinese.ttf"

/* path of image or icon */
#define RES_IMAGE_ROOT                      "/usr/gui"
#define RES_IMAGE_PATH                      "/usr/gui/image"
#define RES_IMAGE_PATH_LEGACY               RES_IMAGE_PATH

/* GUI bitmap assets resolution subdir: derived from LCD_HOR/VER_RES_MAX */
#define _GUI_IMAGE_RES_TAG(w, h)            #w "x" #h
#define _GUI_IMAGE_RES_TAG_EXPAND(w, h)     _GUI_IMAGE_RES_TAG(w, h)
#define GUI_IMAGE_RES_TAG                   _GUI_IMAGE_RES_TAG_EXPAND(LCD_HOR_RES_MAX, LCD_VER_RES_MAX)
/* Under .../image/: e.g. 1024x600/clock/... */
#define GUI_IMAGE_RES_PREFIX                GUI_IMAGE_RES_TAG

/* printf fps, 1-enable, 0-disable */
#define CONFIG_PRINTF_FPS                   1

/* pwm channel of backlight */
#define BACKLIGH_PWM_CHN                    3

#define CONFIG_LV_PORT_TINYJPEG             0
#define CONFIG_LV_PORT_LIBPNG               1
#define CONFIG_LV_PORT_LIBQOI               1
#define CONFIG_LV_PORT_STBIMAGE             1

/* config videvo device */
#define CONFIG_VIDEO_DEVICE                 1

#if CONFIG_VIDEO_DEVICE
/* usb camera */
#define CONFIG_VIDEO_DEVICE_UVCH            0

/* camera sensor */
#define CONFIG_VIDEO_DEVICE_SENSOR          1
#endif

/* gain level definition of audio output, 0-mute, 6-max */
#define AO_GAIN_LEVEL                       5


/* enable application: 0-disable, 1-enable (Music/Video removed: no impl, same as V0.12.1 main page) */
#define LV_DEMO_CALL                        1
#define LV_DEMO_CAMERA                      1
#define LV_DEMO_MUSIC                       0
#define LV_DEMO_VIDEO                       0
#define LV_DEMO_CLOCK                       1
#define LV_DEMO_FILE                        1
#define LV_DEMO_SETTING                     1
#define LV_DEMO_INFO                        1
#define LV_DEMO_VOLC                        1
#define LV_DEMO_SSL                         1
/* Qwen AI chat: off — no server endpoint for this product; tablet_qwen.c excluded from build
 * by CONFIG_APP_TABLET_LV_DEMO_QWEN=n in config.mk + packages/tablet Makefile filter. */
#define LV_DEMO_QWEN                        0

/* Storage mode settings: off for anypi_nova_dev (lite enables via CONFIG_APP_USB_MSC_SUPPORT) */
#define LV_DEMO_STORAGE                     0

#endif // PROJECT_APP_GLOBLE_CONFIG_H
