// SPDX-License-Identifier: Apache-2.0
#ifndef PROJECT_APP_PRODUCT_CONFIG_H
#define PROJECT_APP_PRODUCT_CONFIG_H

#include "config.h"

/*
 * anypi_luna_dev — headless ipcamera (no LCD / no GUI packages).
 * Keep only paths and knobs used by app_main / framework on this product.
 */

#define SYSTEM_CONFIG_FILE                  "/etc/config/system.ini"
#define SYSTEM_CONFIG_BACKLIGHT_SECTION     "backlight"

#define WLAN_CONFIG_FILE                    "/etc/config/fw_wlan_config.ini"
#define WLAN_CONFIG_STATION_SECTION         "station"
#define WLAN_CONFIG_SSID                    "ssid"
#define WLAN_CONFIG_PSK                     "psk"

#define MEDIA_CONFIG_FILE                   "/etc/config/media.ini"
#define ISP_CONFIG_FILE                     "/etc/config/isp.ini"

#define CONFIG_VIDEO_DEVICE                 1
#if CONFIG_VIDEO_DEVICE
#define CONFIG_VIDEO_DEVICE_UVCH            0
#define CONFIG_VIDEO_DEVICE_SENSOR          1
#endif

#define AO_GAIN_LEVEL                       5

/* No UI package on this product */
#define APP_GUI_CAMERA                      0

#endif /* PROJECT_APP_PRODUCT_CONFIG_H */
