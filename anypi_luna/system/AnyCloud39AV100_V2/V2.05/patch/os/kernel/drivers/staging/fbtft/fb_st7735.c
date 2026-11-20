/*
 * FB driver for the ST7735 LCD Controller
 *
 * Copyright (C) 2013 Noralf Tronnes
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

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/delay.h>

#include "fbtft.h"

#define DRVNAME "fb_st7735"

#define MADCTL_BGR BIT(3) /* bitmask for RGB/BGR order */
#define MADCTL_MH BIT(2) /* bitmask for Display Data Latch Data Order */
#define MADCTL_ML BIT(4) /* bitmask for Line Address Order */
#define MADCTL_MV BIT(5) /* bitmask for page/column order */
#define MADCTL_MX BIT(6) /* bitmask for column address order */
#define MADCTL_MY BIT(7) /* bitmask for page address order */

static int init_display(struct fbtft_par *par)
{
	par->fbtftops.reset(par);

	/* Sleep OUT */
	write_reg(par, 0x11);
	mdelay(120);

    /* Set normal mode frame rate */
	//write_reg(par, 0xb1, 0x02, 0x35, 0x36);
	write_reg(par, 0xb1, 0x0f, 0x35, 0x36); /* 40hz, 333000/((0x0f + 20) x (128  + 53 + 54)) */

	write_reg(par, 0xb2, 0x02, 0x35, 0x36);

	write_reg(par, 0xb3, 0x02, 0x35, 0x36, 0x02, 0x35, 0x36 );

	write_reg(par, 0xb4, 0x00);

	write_reg(par, 0xc0, 0xa2, 0x02, 0x84);

	write_reg(par, 0xc1, 0xc5);

	write_reg(par, 0xc2, 0x0d, 0x00);

	write_reg(par, 0xc3, 0x8a, 0x2a);

	write_reg(par, 0xc4, 0x8d, 0xee);

	write_reg(par, 0xc5, 0x02);

	write_reg(par, 0xe0, 0x12, 0x1c, 0x10, 0x18, 0x33, 0x2c, 0x25, 0x28, 0x28, 0x27, 0x2f, 0x3c, 0x00, 0x03, 0x03, 0x10);
	write_reg(par, 0xe1, 0x12, 0x1c, 0x10, 0x18, 0x2d, 0x28, 0x23, 0x28, 0x28, 0x26, 0x2f, 0x3b, 0x00, 0x03, 0x03, 0x10);

	write_reg(par, 0x3a, 0x05);

	write_reg(par, 0x36, 0xC8);

	write_reg(par, 0x29);

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

static struct fbtft_display display = {
	.regwidth = 8,
	.width = 128,
	.height = 160,
	.fbtftops = {
		.init_display = init_display,
		.set_var = set_var,
        .set_addr_win = set_addr_win,
    },
};

FBTFT_REGISTER_DRIVER(DRVNAME, "sitronix,st7735", &display);

MODULE_ALIAS("spi:" DRVNAME);
MODULE_ALIAS("platform:" DRVNAME);
MODULE_ALIAS("spi:st7735");
MODULE_ALIAS("platform:st7735");

MODULE_DESCRIPTION("FB driver for the ST7735 LCD Controller");
MODULE_AUTHOR("Noralf Tronnes");
MODULE_LICENSE("GPL");
