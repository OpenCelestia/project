// SPDX-License-Identifier: Apache-2.0
#ifndef PROJECT_APP_PRODUCT_CONFIG_H
#define PROJECT_APP_PRODUCT_CONFIG_H

#include "config.h"

/* anti-clockwise rotation 90, 1-enable, 0-disable */
#define USE_LCD_ROTATE_90                   0
#define USE_LCD_ROTATE_180                  0
#define USE_LCD_ROTATE_270                  0

/* WiFi credentials and settings live in /etc/config/settings.json wifi{}.
 * HAL uses built-in defaults when no legacy wifi_config.ini is present. */

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

#define GUI_INPUT_CONFIG_PATH              "/etc/config/settings.json"

#if defined(CONFIG_APP_WEARABLE_CAMERA) || defined(CONFIG_APP_TABLET_CAMERA) || \
    defined(CONFIG_APP_NOVA_CAMERA) || \
    (defined(CONFIG_APP_WEARABLE_DASHCAM_PREVIEW) && CONFIG_APP_WEARABLE_DASHCAM_PREVIEW)
#define APP_GUI_CAMERA                      1
#else
#define APP_GUI_CAMERA                      0
#endif

#endif /* PROJECT_APP_PRODUCT_CONFIG_H */
