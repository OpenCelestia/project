// SPDX-License-Identifier: Apache-2.0
/*
 * Copyright (C) 2026 Guangzhou Anyka Microelectronics Co., Ltd.
 *
 * This file is part of Celestia/project/anypi_nova_dev.
 *
 * Shared/cross-layer compile-time constants for anypi_nova_dev.
 * Included by framework/hardware units that need LCD resolution or product
 * feature flags; must not pull in application-layer headers.
 *
 * LCD_HOR/VER_RES_MAX: primary source is config.mk (CONFIG_LCD_HOR_RES /
 * CONFIG_LCD_VER_RES → generated config.h). Literal fallbacks are kept in sync
 * with config.mk so that build units lacking config.h on their include path
 * (e.g. lv_port_display.c) still compile correctly.
 *
 * LV_PORT_IPU_FB_RGB_SWAP: primary source is config.mk
 * (CONFIG_LV_PORT_IPU_FB_RGB_SWAP). The literal fallback below matches the
 * ST7262 board wiring (fb0 B,G,R DDR order vs LVGL R,G,B output).
 */
#ifndef PROJECT_APP_GLOBLE_CONFIG_H
#define PROJECT_APP_GLOBLE_CONFIG_H

#include "app_product_config.h"

/* LCD logical resolution — prefer config.mk value, fall back to panel literal */
#ifndef LCD_HOR_RES_MAX
#ifdef CONFIG_LCD_HOR_RES
#define LCD_HOR_RES_MAX                     CONFIG_LCD_HOR_RES
#else
#define LCD_HOR_RES_MAX                     800
#endif
#endif

#ifndef LCD_VER_RES_MAX
#ifdef CONFIG_LCD_VER_RES
#define LCD_VER_RES_MAX                     CONFIG_LCD_VER_RES
#else
#define LCD_VER_RES_MAX                     480
#endif
#endif

/* IPU framebuffer channel swap: ST7262 fb0 stores B,G,R; LVGL outputs R,G,B.
 * Primary source: CONFIG_LV_PORT_IPU_FB_RGB_SWAP in config.mk. */
#ifndef LV_PORT_IPU_FB_RGB_SWAP
#ifdef CONFIG_LV_PORT_IPU_FB_RGB_SWAP
#define LV_PORT_IPU_FB_RGB_SWAP             CONFIG_LV_PORT_IPU_FB_RGB_SWAP
#else
#define LV_PORT_IPU_FB_RGB_SWAP             1
#endif
#endif

#endif /* PROJECT_APP_GLOBLE_CONFIG_H */
