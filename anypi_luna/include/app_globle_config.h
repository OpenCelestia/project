// SPDX-License-Identifier: Apache-2.0
#ifndef PROJECT_APP_GLOBLE_CONFIG_H
#define PROJECT_APP_GLOBLE_CONFIG_H

#include "app_product_config.h"

/*
 * Screen resolution for shared UI / input code (Luna KM01W: 240x240).
 * Nova defines LCD_*_MAX in its own app_globle_config.h; mirror the convention here
 * from the project config (CONFIG_LCD_HOR_RES/VER_RES) so merged code such as
 * hardware/input/evdev/touch.c that expects LCD_HOR_RES_MAX/LCD_VER_RES_MAX compiles.
 *
 * CONFIG_LCD_HOR_RES/VER_RES come from config.mk via the generated config.h, which is
 * only on the include path for some layers (e.g. app). Framework units that include
 * this header directly (lv_port_display.c) do NOT get it, so fall back to the panel's
 * fixed 240x240 literals — kept in sync with config.mk CONFIG_LCD_HOR_RES/VER_RES.
 */
#ifndef LCD_HOR_RES_MAX
#ifdef CONFIG_LCD_HOR_RES
#define LCD_HOR_RES_MAX                     CONFIG_LCD_HOR_RES
#else
#define LCD_HOR_RES_MAX                     240
#endif
#endif
#ifndef LCD_VER_RES_MAX
#ifdef CONFIG_LCD_VER_RES
#define LCD_VER_RES_MAX                     CONFIG_LCD_VER_RES
#else
#define LCD_VER_RES_MAX                     240
#endif
#endif

#endif /* PROJECT_APP_GLOBLE_CONFIG_H */
