/*
 * FB driver for the ST7789V LCD Controller
 *
 * Copyright (C) 2015 Dennis Menschel
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 */

#include <linux/bitops.h>
#include <linux/delay.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/module.h>
//#include <video/mipi_display.h>

#include "fbtft.h"

#define DRVNAME "fb_st7789"

/**
 * enum st7789v_command - ST7789V display controller commands
 *
 * @PORCTRL: porch setting
 * @GCTRL: gate control
 * @VCOMS: VCOM setting
 * @VDVVRHEN: VDV and VRH command enable
 * @VRHS: VRH set
 * @VDVS: VDV set
 * @VCMOFSET: VCOM offset set
 * @PWCTRL1: power control 1
 * @PVGAMCTRL: positive voltage gamma control
 * @NVGAMCTRL: negative voltage gamma control
 *
 * The command names are the same as those found in the datasheet to ease
 * looking up their semantics and usage.
 *
 * Note that the ST7789V display controller offers quite a few more commands
 * which have been omitted from this list as they are not used at the moment.
 * Furthermore, commands that are compliant with the MIPI DCS have been left
 * out as well to avoid duplicate entries.
 */
enum st7789v_command {
	PORCTRL = 0xB2,
	GCTRL = 0xB7,
	VCOMS = 0xBB,
	VDVVRHEN = 0xC2,
	VRHS = 0xC3,
	VDVS = 0xC4,
	VCMOFSET = 0xC5,
	PWCTRL1 = 0xD0,
	PVGAMCTRL = 0xE0,
	NVGAMCTRL = 0xE1,
};

#define MADCTL_BGR BIT(3) /* bitmask for RGB/BGR order */
#define MADCTL_MH BIT(2) /* bitmask for Display Data Latch Data Order */
#define MADCTL_ML BIT(4) /* bitmask for Line Address Order */
#define MADCTL_MV BIT(5) /* bitmask for page/column order */
#define MADCTL_MX BIT(6) /* bitmask for column address order */
#define MADCTL_MY BIT(7) /* bitmask for page address order */

/**
 * init_display() - initialize the display controller
 *
 * @par: FBTFT parameter object
 *
 * Most of the commands in this init function set their parameters to the
 * same default values which are already in place after the display has been
 * powered up. (The main exception to this rule is the pixel format which
 * would default to 18 instead of 16 bit per pixel.)
 * Nonetheless, this sequence can be used as a template for concrete
 * displays which usually need some adjustments.
 *
 * Return: 0 on success, < 0 if error occurred.
 */
static int init_display(struct fbtft_par *par)
{
	par->fbtftops.reset(par);

    /* turn off sleep mode */
	write_reg(par, 0x11);
	mdelay(120);

	write_reg(par, 0x36, 0x00);

    /* set pixel format to RGB-565 */
	write_reg(par, 0x3A, 0x55);

    write_reg(par, PORCTRL, 0x0C, 0x0C, 0x00, 0x33, 0x33);

    write_reg(par, GCTRL, 0x75);

    write_reg(par, VCOMS, 0x13);

    write_reg(par, 0xC0, 0x2C);

    write_reg(par, VDVVRHEN, 0x01);

    write_reg(par, VRHS, 0x13);

    write_reg(par, VDVS, 0x20);

    write_reg(par, 0xC6, 0x0F); /* frame rate */

	write_reg(par, PWCTRL1, 0xA4, 0xA1);

    write_reg(par, 0xD6, 0xA1);

    write_reg(par, 0x21);

	/* VCOM offset = 0V */
	//write_reg(par, VCMOFSET, 0x20);

    /* TE enable */
    write_reg(par, 0x35, 0x00);

#if 1
	write_reg(par, PVGAMCTRL, 0xD0, 0x08, 0x10, 0x0D, 0x0C, 0x07, 0x37, 0x53, 0x4C, 0x39, 0x15, 0x15, 0x2A,	0x2D);
	write_reg(par, NVGAMCTRL, 0xD0, 0x0D, 0x12, 0x08, 0x08, 0x15, 0x34, 0x34, 0x4A, 0x36, 0x12, 0x13, 0x2B, 0x2F);
#else
	write_reg(par, PVGAMCTRL, 0xD0, 0x00, 0x05, 0x0E, 0x15, 0x0D, 0x37, 0x43, 0x47, 0x09, 0x15, 0x12, 0x16,	0x19);
	write_reg(par, NVGAMCTRL, 0xD0, 0x00, 0x05, 0x0D, 0x0C, 0x06, 0x2D, 0x44, 0x40, 0x0E, 0x1C, 0x18, 0x16, 0x19);
#endif

	write_reg(par, 0x29);
	mdelay(20);

    return 0;
}

/**
 * set_var() - apply LCD properties like rotation and BGR mode
 *
 * @par: FBTFT parameter object
 *
 * Return: 0 on success, < 0 if error occurred.
 */
static int set_var(struct fbtft_par *par)
{
    u8 madctl_par = 0;

    if (par->bgr)
        madctl_par |= MADCTL_BGR;

    switch (par->info->var.rotate) {
    case 0:
        break;
    case 90:
        madctl_par |= (MADCTL_MV | MADCTL_MX | MADCTL_MH);
        break;
    case 180:
        madctl_par |= (MADCTL_MY | MADCTL_MX | MADCTL_ML | MADCTL_MH);
        break;
    case 270:
        madctl_par |= (MADCTL_MY | MADCTL_MV | MADCTL_ML);
        break;
    default:
        return -EINVAL;
    }

    write_reg(par, 0x36, madctl_par);
	return 0;
}

static void set_addr_win(struct fbtft_par *par, int xs, int ys, int xe, int ye)
{
    /* Column address set */
	write_reg(par, 0x2A,
		(xs >> 8) & 0xFF, xs & 0xFF, (xe >> 8) & 0xFF, xe & 0xFF);

	/* Row address set */
	write_reg(par, 0x2B,
		(ys >> 8) & 0xFF, ys & 0xFF, (ye >> 8) & 0xFF, ye & 0xFF);

	/* Memory write */
	write_reg(par, 0x2C);
}

static struct fbtft_display display = {
	.regwidth = 8,
	.width = 240,
	.height = 320,
	.fbtftops = {
		.init_display = init_display,
		.set_var = set_var,
		.set_addr_win = set_addr_win,
	},
};

FBTFT_REGISTER_DRIVER(DRVNAME, "sitronix,st7789", &display);

MODULE_ALIAS("spi:" DRVNAME);
MODULE_ALIAS("platform:" DRVNAME);
MODULE_ALIAS("spi:st7789");
MODULE_ALIAS("platform:st7789");

MODULE_DESCRIPTION("FB driver for the ST7789 LCD Controller");
MODULE_AUTHOR("Dennis Menschel");
MODULE_LICENSE("GPL");
