/*
 * Driver for KM02 GPIO (pinctrl + GPIO)
 *
 * Copyright (C) 2023 Anyka(Guangzhou) Microelectronics Technology Co., Ltd.
 *
 * This driver is inspired by:
 * pinctrl-bcm2835.c, please see original file for copyright information
 * pinctrl-tegra.c, please see original file for copyright information
 *
 * Author:
 *
 * This software is licensed under the terms of the GNU General Public
 * License version 2, as published by the Free Software Foundation, and
 * may be copied, distributed, and modified under those terms.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 */

#include <linux/bitmap.h>
#include <linux/bug.h>
#include <linux/delay.h>
#include <linux/device.h>
#include <linux/err.h>
#include <linux/gpio.h>
#include <linux/interrupt.h>
#include <linux/io.h>
#include <linux/irq.h>
#include <linux/irqdesc.h>
#include <linux/irqdomain.h>
#include <linux/irqchip/chained_irq.h>
#include <linux/module.h>
#include <linux/of_address.h>
#include <linux/of.h>
#include <linux/of_gpio.h>
#include <linux/of_irq.h>
#include <linux/pinctrl/consumer.h>
#include <linux/pinctrl/machine.h>
#include <linux/pinctrl/pinconf.h>
#include <linux/pinctrl/pinctrl.h>
#include <linux/pinctrl/pinmux.h>
#include <linux/platform_device.h>
#include <linux/seq_file.h>
#include <linux/slab.h>
#include <linux/syscore_ops.h>
#include <linux/spinlock.h>
#include <linux/types.h>
#include <linux/clk.h>
#include <linux/reset.h>

//#include <mach/map.h>

#include <dt-bindings/pinctrl/ak3918av200_pinctrl.h>

//#define RAW_DEBUG 1
//#define AK_GPIO_DEBUG 1

#define MODULE_NAME              "ak-pinctrl"
#define AK_BANK_GPIOS                 32
#define AK_BANK_NUM                   4  // if dynamic , can delete
#define AK_NUM_GPIOS                  91 // if dynamic, can delete

// gpio reg's offset
#define AK_GPIO_DIR_REG               0x00  //GPIO输出使能寄存器
#define AK_GPIO_INPUT_REG             0x04  //GPIO输入寄存器
#define AK_GPIO_OUT_REG               0x08  //GPIO输出寄存器
#define AK_GPIO_INTEN_REG             0x0c  //GPIO输入中断使能寄存器
#define AK_GPIO_INT_MODE_REG          0x10  //GPIO输入中断触发模式寄存器
#define AK_GPIO_INTPOL_REG            0x14  //GPIO输入中断极性寄存器
#define AK_GPIO_STATUS_REG            0x18  //GPIO输入中断状态寄存器
#define AK_GPIO_DBLEDGE_REG           0x1c  //GPIO双沿中断使能寄存器
#define AK_GPIO_OUTSET_REG            0x20  //GPIO输出置1位操作寄存器
#define AK_GPIO_OUTCLR_REG            0x24  //GPIO输出置0位操作寄存器
#define AK_GPIO_OUTINV_REG            0x28  //GPIO输出翻转位操作寄存器

// pinctrl reg bit;
#define AK_PINCTRL_DRI_BIT            29  //Driving selector[31:29]
#define AK_PINCTRL_IE_BIT             28  //Input enable
#define AK_PINCTRL_PDEN_BIT           27  //Pull down enable
#define AK_PINCTRL_PUEN_BIT           26  //Pull up enable
#define AK_PINCTRL_SMT0_EN_BIT        25  //Schmitt trigger enable
#define AK_PINCTRL_SMT1_EN_BIT        24  //Schmitt trigger enable
#define AK_PINCTRL_HOLDEN_BIT         23  //Hold enable
#define AK_PINCTRL_SLEW_BIT           22  //Slew-rate-control enable.
#define AK_PINCTRL_PSEL_BIT           21  //pupd sel
#define AK_PINCTRL_PUPDEN_BIT         20  //pupd enable
#define AK_PINCTRL_DIREN_BIT          19  //direction enable
#define AK_PINCTRL_DIR_BIT            18  //direction
#define AK_PINCTRL_OUTEN_BIT          17  //output enable
#define AK_PINCTRL_OUTPUT_BIT         16  //output level
#define AK_PINCTRL_DELAY_BIT          8   /*Delay cfg[14:8] 
                             仅对GPIO39~52和57~59，61~84有效。1级为10ps*/
#define AK_PINCTRL_FUNC_CFG_BIT       0   // [2:0]

#define AK_GPIO_OUT_LOW         0
#define AK_GPIO_OUT_HIGH        1

#define AK_GPIO_PIN(a)          PINCTRL_PIN(a, "gpio" #a)

#define AK_GPIO_CONF_INVALID    (-1)

#define AK_PIN_PUPD_DISABLE     0
#define AK_PIN_PUPD_ENABLE      1

#define AK_PIN_CFG_DRV_EN       (0x01)
#define AK_PIN_CFG_INPUT_EN     (0x02)
#define AK_PIN_CFG_PUPD_EN      (0x04)
#define AK_PIN_CFG_PUPD_SEL     (0x08)
#define AK_PIN_CFG_SLEW_RATE    (0x10)

#define AK_PIN_CFG_ALL_DISABLE  (0x0)
#define AK_PIN_CFG_ALL_ENABLE   (AK_PIN_CFG_DRV_EN|AK_PIN_CFG_INPUT_EN|\
                   AK_PIN_CFG_PUPD_EN|AK_PIN_CFG_PUPD_SEL|AK_PIN_CFG_SLEW_RATE)

#ifdef AK_GPIO_DEBUG
#define ak_log_print(fmt, arg...) pr_info(fmt, ##arg)
#else
#define ak_log_print(fmt, arg...) pr_debug(fmt, ##arg)
#endif

#define DRIVE_STRENGTH(strength)         (strength)

#define AK_GPIO_REG_SHIFT(pin)          ((pin) % 32)

#define AK_PIN_AS_GPIO_IN         0 // pin as gpio in
#define AK_PIN_AS_GPIO_OUT        1 // pin as gpio out

#define DEFAULT_FUNC 0

#define PIN_BANK_SET(id, pinbase, pins, label)  \
            {                                       \
                .bank_num   = id,                   \
                .pin_base   = pinbase,              \
                .nr_pins    = pins,                 \
                .name       = label,                \
            }

#define AK_FUNC_NUMS 6

// use for gpio bank;
struct ak_pin_bank {
    // bank's info;
    char *name;
    u8 bank_num;
    u32 pin_base;
    u8 nr_pins;
    void __iomem *reg_base;
    bool valid; // if dynamic, can delete
    struct device_node *of_node;

    // bank's irq domain;
    int irq;
    struct irq_domain *irq_domain;
    unsigned int irq_type[AK_BANK_GPIOS];
    
    // bank's gpio chip;
    struct gpio_chip gc;
    struct pinctrl_gpio_range grange;
};


// use for ctrl gpio bank;
struct ak_pin_ctrl {
    struct ak_pin_bank *pin_banks;
    u32 nr_banks;
    u32 nr_pins;
    char *label;
};

// use for ctrl gpio and pinctrl;
struct ak_pinctrl {
    struct device *dev;
    struct clk *gpio0_clk;
    struct clk *gpio1_clk;
    struct clk *gpio2_clk;
    struct clk *gpio3_clk;
    struct reset_control *gpio0_rstc;
    struct reset_control *gpio1_rstc;
    struct reset_control *gpio2_rstc;
    struct reset_control *gpio3_rstc;
    struct ak_pin_ctrl	*ctrl;
    struct pinctrl_dev *pctl_dev;
    u32 *reg_base;
    int fsel[AK_NUM_GPIOS];
};

u32 *pinctrl_reg;

/*
 * pins/groups/functions
 * one device maybe has many pins, these pins can be a group;
 * one function maybe nedd many pins, these pins can be a function group;
 * different manufacturers have different definition.
 *
 * note: here , one pin per groups , every pin has every func;
 */


// use for pinctrl groups and func
// can add into struct ak_pinctrl if dynamic
static struct pinctrl_pin_desc ak_gpio_pins[AK_NUM_GPIOS] = {
    AK_GPIO_PIN(0),
    AK_GPIO_PIN(1),
    AK_GPIO_PIN(2),
    AK_GPIO_PIN(3),
    AK_GPIO_PIN(4),
    AK_GPIO_PIN(5),
    AK_GPIO_PIN(6),
    AK_GPIO_PIN(7),
    AK_GPIO_PIN(8),
    AK_GPIO_PIN(9),
    AK_GPIO_PIN(10),
    AK_GPIO_PIN(11),
    AK_GPIO_PIN(12),
    AK_GPIO_PIN(13),
    AK_GPIO_PIN(14),
    AK_GPIO_PIN(15),
    AK_GPIO_PIN(16),
    AK_GPIO_PIN(17),
    AK_GPIO_PIN(18),
    AK_GPIO_PIN(19),
    AK_GPIO_PIN(20),
    AK_GPIO_PIN(21),
    AK_GPIO_PIN(22),
    AK_GPIO_PIN(23),
    AK_GPIO_PIN(24),
    AK_GPIO_PIN(25),
    AK_GPIO_PIN(26),
    AK_GPIO_PIN(27),
    AK_GPIO_PIN(28),
    AK_GPIO_PIN(29),
    AK_GPIO_PIN(30),
    AK_GPIO_PIN(31),
    AK_GPIO_PIN(32),
    AK_GPIO_PIN(33),
    AK_GPIO_PIN(34),
    AK_GPIO_PIN(35),
    AK_GPIO_PIN(36),
    AK_GPIO_PIN(37),
    AK_GPIO_PIN(38),
    AK_GPIO_PIN(39),
    AK_GPIO_PIN(40),
    AK_GPIO_PIN(41),
    AK_GPIO_PIN(42),
    AK_GPIO_PIN(43),
    AK_GPIO_PIN(44),
    AK_GPIO_PIN(45),
    AK_GPIO_PIN(46),
    AK_GPIO_PIN(47),
    AK_GPIO_PIN(48),
    AK_GPIO_PIN(49),
    AK_GPIO_PIN(50),
    AK_GPIO_PIN(51),
    AK_GPIO_PIN(52),
    AK_GPIO_PIN(53),
    AK_GPIO_PIN(54),
    AK_GPIO_PIN(55),
    AK_GPIO_PIN(56),
    AK_GPIO_PIN(57),
    AK_GPIO_PIN(58),
    AK_GPIO_PIN(59),
    AK_GPIO_PIN(60),
    AK_GPIO_PIN(61),
    AK_GPIO_PIN(62),
    AK_GPIO_PIN(63),
    AK_GPIO_PIN(64),
    AK_GPIO_PIN(65),
    AK_GPIO_PIN(66),
    AK_GPIO_PIN(67),
    AK_GPIO_PIN(68),
    AK_GPIO_PIN(69),
    AK_GPIO_PIN(70),
    AK_GPIO_PIN(71),
    AK_GPIO_PIN(72),
    AK_GPIO_PIN(73),
    AK_GPIO_PIN(74),
    AK_GPIO_PIN(75),
    AK_GPIO_PIN(76),
    AK_GPIO_PIN(77),
    AK_GPIO_PIN(78),
    AK_GPIO_PIN(79),
    AK_GPIO_PIN(80),
    AK_GPIO_PIN(81),
    AK_GPIO_PIN(82),
    AK_GPIO_PIN(83),
    AK_GPIO_PIN(84),
    /* not used */
    AK_GPIO_PIN(85),
    AK_GPIO_PIN(86),
    AK_GPIO_PIN(87),
    AK_GPIO_PIN(88),
    AK_GPIO_PIN(89),
    /* uesd */
    AK_GPIO_PIN(90),
};

// use for func 
static const char * const ak_funcs[6] = {
    [0] = "default func",
    [1] = "func1",
    [2] = "func2",
    [3] = "func3",
    [4] = "func4",
    [5] = "func5",
};

static const char * const irq_type_names[] = {
    [IRQ_TYPE_NONE] = "none",
    [IRQ_TYPE_EDGE_RISING] = "edge-rising",
    [IRQ_TYPE_EDGE_FALLING] = "edge-falling",
    [IRQ_TYPE_LEVEL_HIGH] = "level-high",
    [IRQ_TYPE_LEVEL_LOW] = "level-low",
    [IRQ_TYPE_EDGE_BOTH] = "edge-double",
};

/* one pin per group */
// can add into struct ak_pinctrl if dynamic
static const char * const ak_gpio_groups[AK_NUM_GPIOS] = {
    "gpio0",
    "gpio1",
    "gpio2",
    "gpio3",
    "gpio4",
    "gpio5",
    "gpio6",
    "gpio7",
    "gpio8",
    "gpio9",
    "gpio10",
    "gpio11",
    "gpio12",
    "gpio13",
    "gpio14",
    "gpio15",
    "gpio16",
    "gpio17",
    "gpio18",
    "gpio19",
    "gpio20",
    "gpio21",
    "gpio22",
    "gpio23",
    "gpio24",
    "gpio25",
    "gpio26",
    "gpio27",
    "gpio28",
    "gpio29",
    "gpio30",
    "gpio31",
    "gpio32",
    "gpio33",
    "gpio34",
    "gpio35",
    "gpio36",
    "gpio37",
    "gpio38",
    "gpio39",
    "gpio40",
    "gpio41",
    "gpio42",
    "gpio43",
    "gpio44",
    "gpio45",
    "gpio46",
    "gpio47",
    "gpio48",
    "gpio49",
    "gpio50",
    "gpio51",
    "gpio52",
    "gpio53",
    "gpio54",
    "gpio55",
    "gpio56",
    "gpio57",
    "gpio58",
    "gpio59",
    "gpio60",
    "gpio61",
    "gpio62",
    "gpio63",
    "gpio64",
    "gpio65",
    "gpio66",
    "gpio67",
    "gpio68",
    "gpio69",
    "gpio70",
    "gpio71",
    "gpio72",
    "gpio73",
    "gpio74",
    "gpio75",
    "gpio76",
    "gpio77",
    "gpio78",
    "gpio79",
    "gpio80",
    "gpio81",
    "gpio82",
    "gpio83",
    "gpio84",
    
    /* not used */
    "gpio85",
    "gpio86",
    "gpio87",
    "gpio88",
    "gpio89",
    
    /* uesd */
    "gpio90",
};

#ifdef RAW_DEBUG
static inline u32 RAW_READL_DBG(const volatile void __iomem *addr)
{
    u32 ret;
    ret = __raw_readl(addr);
    if ((((u32)addr) & ~0xfff) == (u32)AK_VA_SYSCTRL) {
        pr_info("RAW_READL VA 0x%x PA 0x%x return 0x%x\n",
                (u32)addr, (u32)AK_PA_SYSCTRL + (((u32)addr) & 0xfff), ret);
    } else if ((((u32)addr) & ~0xfff) == (u32)ak_gpio_base) {
        pr_info("RAW_READL VA 0x%x PA 0x%x return 0x%x\n",
                (u32)addr, (u32)ak_gpio_base_pa + (((u32)addr) & 0xfff), ret);
    } else {
        pr_err("RAW_READL VA 0x%x error!\n", (u32)addr);
    }
    return ret;
}

static inline void RAW_WRITEL_DBG(u32 val, volatile void __iomem *addr)
{
    if ((((u32)addr) & ~0xfff) == (u32)AK_VA_SYSCTRL) {
        pr_info("RAW_WRITEL VA 0x%x PA 0x%x val 0x%x\n",
                (u32)addr, (u32)AK_PA_SYSCTRL + (((u32)addr) & 0xfff), val);
    } else if ((((u32)addr) & ~0xfff) == (u32)ak_gpio_base) {
        pr_info("RAW_WRITEL VA 0x%x PA 0x%x val 0x%x\n",
                (u32)addr, (u32)ak_gpio_base_pa + (((u32)addr) & 0xfff), val);
    } else {
        pr_err("RAW_WRITEL VA 0x%x error!\n", (u32)addr);
    }
    __raw_writel(val, addr);
}
#else
#define RAW_READL_DBG(reg)       __raw_readl(reg)
#define RAW_WRITEL_DBG(val, reg) __raw_writel(val, reg)
#endif

static void __iomem *ak_get_pinctrl_reg(struct ak_pinctrl *pc, unsigned int pin)
{
    void __iomem *reg = pc->reg_base;
    return ( reg + 0x4*pin);
}

static struct ak_pin_bank *pin_to_bank(
                        struct ak_pinctrl *pc, unsigned pin)
{
    struct ak_pin_bank *bank = pc->ctrl->pin_banks;

    while (pin >= (bank->pin_base + bank->nr_pins))
        bank++;

    return bank;
}

__attribute__((unused))
static int pin_set_share(struct ak_pinctrl *info, int pin, int sel)
{
    u32 regval;
    void __iomem *reg;
    struct ak_pin_bank *bank = info->ctrl->pin_banks;
    bank += AK_GPIO_REG_SHIFT(pin);

    if (pin > AK_NUM_GPIOS) {
        pr_err("%s pin_%d should less than pin_%d\n", __func__, pin, AK_NUM_GPIOS);
        return -EINVAL;
    }

    if (sel >= AK_FUNC_NUMS) {
        pr_err("%s pin_%d max %d but sel %d\n",
                __func__, pin, AK_FUNC_NUMS, sel);
        return -EINVAL;
    }

    reg = ak_get_pinctrl_reg(info, pin);

    regval = RAW_READL_DBG(reg);
    regval &= ~(0x7 << AK_PINCTRL_FUNC_CFG_BIT);
    regval |= ((sel & 0x7) << AK_PINCTRL_FUNC_CFG_BIT);
    RAW_WRITEL_DBG(regval, reg);
    
    ak_log_print("PIN_%d: FUNC(%d) 0x%p:0x%x\n", pin, sel, reg,
        RAW_READL_DBG(reg));

    info->fsel[pin] = sel;
    return 0;
}

static inline unsigned int ak_pinctrl_fsel_get(struct ak_pinctrl *pc,
                    unsigned int pin)
{
    int status = pc->fsel[pin];

    return status;
}

/**
*
*@brief: ak_gpio_get_direction
*@param[in] struct gpio_chip *chip
*@param[in] int offset
*@return: int
*
**/
/*
* if return 1 means output
* else any positive value means input
*/
static int ak_gpio_get_direction(struct gpio_chip *chip, unsigned offset)
{
    struct ak_pin_bank *bank = gpiochip_get_data(chip);
    void __iomem * reg = bank->reg_base + AK_GPIO_DIR_REG;

    return ( RAW_READL_DBG(reg) & (BIT(offset)) ) ? 0:1;
}

static int ak_gpio_get(struct gpio_chip *chip, unsigned offset)
{
    struct ak_pin_bank *bank = gpiochip_get_data(chip);
    void __iomem *reg_direction = bank->reg_base + AK_GPIO_DIR_REG;
    void __iomem *reg = bank->reg_base + AK_GPIO_OUT_REG;
    unsigned int direction = ((RAW_READL_DBG(reg_direction) & BIT(offset)) ? 0:1);

    if(direction) {
        reg = bank->reg_base + AK_GPIO_INPUT_REG;
    } else {
        reg = bank->reg_base + AK_GPIO_OUT_REG;
    }

    ak_log_print("GPIO_%d(%s): VAL(%d) 0x%p:0x%x\n",
        offset, direction ? "INPUT" : "OUT",
        ((RAW_READL_DBG(reg) & BIT(offset)) ? 1:0), reg, RAW_READL_DBG(reg));

    return (RAW_READL_DBG(reg) & BIT(offset)) ? 1:0;
}

static void ak_gpio_set(struct gpio_chip *chip, unsigned offset, int value)
{
    struct ak_pin_bank *bank = gpiochip_get_data(chip);
    void __iomem *reg;

    if (AK_GPIO_OUT_LOW == value) {
        reg = bank->reg_base + AK_GPIO_OUTCLR_REG;
        RAW_WRITEL_DBG(BIT(offset), reg);
    } else if (AK_GPIO_OUT_HIGH == value) {
        reg = bank->reg_base + AK_GPIO_OUTSET_REG;
        RAW_WRITEL_DBG(BIT(offset), reg);
    }

    ak_log_print("PIN_%d: OUT_VAL(%d) 0x%p:0x%x\n", offset, value, reg,
        RAW_READL_DBG(reg));
}

/**
*
*@brief: ak_gpio_direction_input
*@param[in] struct gpio_chip *chip
*@param[in] int offset
*@return: int
*
**/
static int ak_gpio_direction_input(struct gpio_chip *chip,
    unsigned offset)
{
    return pinctrl_gpio_direction_input(chip->base + offset);
}

static int ak_gpio_direction_output(struct gpio_chip *chip,
                    unsigned offset, int value)
{
    ak_gpio_set(chip, offset, value);
    return pinctrl_gpio_direction_output(chip->base + offset);
}

/**
*
*@brief: ak_gpio_set_drive
*@param[in] struct gpio_chip *chip
*@param[in] int pin
*@return: int
*
**/
static inline int ak_gpio_set_drive(struct gpio_chip *chip,
                    unsigned int offset, int strength)
{
    u32 regval;
    void __iomem *reg = (void __iomem *)pinctrl_reg + 0x4*(chip->base+offset);
    /*
    *1.8V GPIO can not select DRIVE_SEL4~7
    *G PIO[54:35] can not select DRIVE_SEL4~7
    *if selector error, config DRIVE_SEL3
    */
    regval = RAW_READL_DBG(reg);
    regval &= ~(0x7U << AK_PINCTRL_DRI_BIT);
    if( ( (strength << AK_PINCTRL_DRI_BIT) > DRIVE_SEL3 )
        && (offset >= 35 && offset <= 54) ){
        pr_err("%s, PIN[%d] drive sel failed!", __func__, offset);
        regval |= DRIVE_SEL3;
    }else{
        regval |= (strength << AK_PINCTRL_DRI_BIT);
    }
    RAW_WRITEL_DBG(regval, reg);

    ak_log_print("PIN_%d: driver(%d) 0x%p:0x%x\n",
            offset, strength, reg,
            RAW_READL_DBG(reg));

    return 0;
}

/**
*
*@brief: ak_gpio_get_drive
*@param[in] struct gpio_chip *chip
*@param[in] int offset
*@return: int
*
**/
static inline int ak_gpio_get_drive(struct gpio_chip *chip,
                    unsigned int offset)
{
    u32 regval;
    void __iomem *reg = (void __iomem *)pinctrl_reg + 0x4*(chip->base+offset);

    regval = RAW_READL_DBG(reg);

    ak_log_print("%s 0x%p:0x%x\n", __func__, reg, regval);
    ak_log_print("%s 0x%x:0x%x\n", __func__, *(u32*)reg, regval);
    regval >>= AK_PINCTRL_DRI_BIT;

    return regval;
}

/*
*
* gpiolib-sysfs.c
* -- pull_polarity_store
* ---- gpiod_set_pull_polarity
* IF pullup = 1 means pull up.
* else pullup = 0 mean pulldown
* or negative if any error
*
*/
/**
*@brief: ak_gpio_set_pull_polarity
*@param[in] struct gpio_chip *chip
*@param[in] int offset
*@param[in] int pullup
*@return: int
**/
static int ak_gpio_set_pull_polarity(struct gpio_chip *chip,
                    unsigned offset, int pullup)
{
    void __iomem *reg = (void __iomem *)pinctrl_reg + 0x4*(chip->base+offset);
    u32 regval;

    regval = RAW_READL_DBG(reg);

    if (pullup == PULL_UP) {
        regval |= BIT(AK_PINCTRL_PUPDEN_BIT) | BIT(AK_PINCTRL_PUEN_BIT)
                | BIT(AK_PINCTRL_PSEL_BIT);
    } else {
        regval |= BIT(AK_PINCTRL_PUPDEN_BIT) | BIT(AK_PINCTRL_PDEN_BIT);
        regval &= ~(BIT(AK_PINCTRL_PSEL_BIT));
    }
    RAW_WRITEL_DBG(regval, reg);

    ak_log_print("PIN_%d: PUPD(%d) 0x%p:0x%x\n",
            offset, pullup, reg,
            RAW_READL_DBG(reg));

    return 0;


}

/*
*
* gpiolib-sysfs.c
* -- pull_polarity_show
* ---- gpiod_get_pull_polarity
* IF return > 0 means pullup
* else return 0 mean pulldown
* or negative if any error
*
*/
/**
*@brief: ak_gpio_get_pull_polarity
*@param[in] struct gpio_chip *chip
*@param[in] int offset
*@return: int
**/
static int ak_gpio_get_pull_polarity(struct gpio_chip *chip,
                    unsigned offset)
{
    void __iomem *reg = (void __iomem *)pinctrl_reg + 0x4*(chip->base+offset);
    u32 regval;

    regval = RAW_READL_DBG(reg);

    ak_log_print("%s 0x%p:0x%x\n", __func__, reg, regval);

    regval &= BIT(AK_PINCTRL_PSEL_BIT);

    return (regval ? 1 : 0);
}

/*
*
* gpiolib-sysfs.c
* -- pull_enable_store
* ---- gpiod_set_pull_enable
*
*/
/**
*@brief: ak_gpio_set_pull_enable
*@param[in] struct gpio_chip *chip
*@param[in] int offset
*@param[in] int enable
*@return: int
**/
static int ak_gpio_set_pull_enable(struct gpio_chip *chip,
                    unsigned offset, int enable)
{
    void __iomem *reg = (void __iomem *)pinctrl_reg + 0x4*(chip->base+offset);
    u32 regval;
    
    regval = RAW_READL_DBG(reg);

    if (enable) {
        regval |= PUPD_EN | PULL_UP_EN | PULL_DOWN_EN;
    } else {
        regval &= ~(PUPD_EN | PULL_UP_EN | PULL_DOWN_EN);
    }
    RAW_WRITEL_DBG(regval, reg);
    
    ak_log_print("PIN_%d: Input_EN(%d) 0x%p:0x%x\n",
            offset, enable, reg,
            RAW_READL_DBG(reg));

    return 0;
}

/*
*
* gpiolib-sysfs.c
* -- pull_enable_show
* ---- gpiod_get_pull_enable
*
*/
/**
*@brief: ak_gpio_get_pull_enable
*@param[in] struct gpio_chip *chip
*@param[in] int offset
*@return: int
**/
static int ak_gpio_get_pull_enable(struct gpio_chip *chip,
                    unsigned offset)
{
    void __iomem *reg = (void __iomem *)pinctrl_reg + 0x4*(chip->base+offset);
    u32 regval;

    regval = RAW_READL_DBG(reg);

    ak_log_print("%s 0x%p:0x%x\n", __func__, reg, regval);

    regval &= PUPD_EN | PULL_UP_EN | PULL_DOWN_EN;

    return (regval ? 1 : 0);
}

/*
*
* gpiolib-sysfs.c
* -- input_enable_store
* ---- gpiod_set_input_enable
*
*/
/**
*@brief: ak_gpio_set_input_enable
*@param[in] struct gpio_chip *chip
*@param[in] int offset
*@param[in] int enable
*@return: int
**/
static int ak_gpio_set_input_enable(struct gpio_chip *chip,
                    unsigned offset, int enable)
{
    void __iomem *reg = (void __iomem *)pinctrl_reg + 0x4*(chip->base+offset);
    u32 regval;

    regval = RAW_READL_DBG(reg);

    if (enable) {
        regval |= BIT(AK_PINCTRL_IE_BIT);
    } else {
        regval &= ~(BIT(AK_PINCTRL_IE_BIT));
    }
    RAW_WRITEL_DBG(regval, reg);

    ak_log_print("PIN_%d: Input_EN(%d) 0x%p:0x%x\n",
            offset, enable, reg,
            RAW_READL_DBG(reg));

    return 0;
}

/*
*
* gpiolib-sysfs.c
* -- input_enable_show
* ---- gpiod_get_input_enable
*
*/
/**
*
*@brief: ak_gpio_get_input_enable
*@param[in] struct gpio_chip *chip
*@param[in] int offset
*@return: int
*
**/
static int ak_gpio_get_input_enable(struct gpio_chip *chip,
    unsigned offset)
{
    void __iomem *reg = (void __iomem *)pinctrl_reg + 0x4*(chip->base+offset);
    u32 regval;

    regval = RAW_READL_DBG(reg);

    ak_log_print("%s 0x%p:0x%x\n", __func__, reg, regval);

    regval &= BIT(AK_PINCTRL_IE_BIT);

    return (regval ? 1 : 0);
}

/*
*
* gpiolib-sysfs.c
* -- slew_rate_store
* ---- gpiod_set_slew_rate
*
*/
/**
*
*@brief: ak_gpio_set_slew_rate
*@param[in] struct gpio_chip *chip
*@param[in] int offset
*@param[in] int fast
*@return: int
*
**/
static int ak_gpio_set_slew_rate(struct gpio_chip *chip,
                    unsigned offset, int fast)
{
    void __iomem *reg = (void __iomem *)pinctrl_reg + 0x4*(chip->base+offset);
    u32 regval;

    regval = RAW_READL_DBG(reg);

    if (fast) {
        regval &= ~(BIT(AK_PINCTRL_SLEW_BIT));
    } else {
        regval |= BIT(AK_PINCTRL_SLEW_BIT);
    }
    RAW_WRITEL_DBG(regval, reg);

    ak_log_print("PIN_%d: SR(%d) 0x%p:0x%x\n", offset, fast,
        reg,
        RAW_READL_DBG(reg));

    return 0;
}

/*
*
* gpiolib-sysfs.c
* -- slew_rate_show
* ---- gpiod_get_slew_rate
*
*/
/**
*
*@brief: ak_gpio_get_slew_rate
*@param[in] struct gpio_chip *chip
*@param[in] int offset
*@return: int
*
**/
static int ak_gpio_get_slew_rate(struct gpio_chip *chip, unsigned offset)
{
    void __iomem *reg = (void __iomem *)pinctrl_reg + 0x4*(chip->base+offset);
    u32 regval;

    regval = RAW_READL_DBG(reg);

    ak_log_print("%s 0x%p:0x%x\n", __func__, reg, regval);

    regval &= BIT(AK_PINCTRL_SLEW_BIT);

    return (regval ? 1 : 0);
}

static int ak_gpio_to_irq(struct gpio_chip *chip, unsigned offset)
{
    struct ak_pin_bank *bank = gpiochip_get_data(chip);

    return irq_linear_revmap(bank->irq_domain, offset);
}

static int ak_gpio_of_xlate(struct gpio_chip *gc,
        const struct of_phandle_args *gpiospec,
        u32 *flags)
{
    /*
     * We're discouraging gpio_cells < 2, since that way you'll have to
     * write your own xlate function (that will have to retrieve the GPIO
     * number and the flags from a single gpio cell -- this is possible,
     * but not recommended).
     */
    if (gc->of_gpio_n_cells < 2) {
        WARN_ON(1);
        return -EINVAL;
    }

    if (WARN_ON(gpiospec->args_count < gc->of_gpio_n_cells))
        return -EINVAL;

    if (gpiospec->args[0] < gc->base ||
        gpiospec->args[0] >= gc->base + gc->ngpio){
        pr_err("##error! pin(%u) is belong to gpio%d.\n",
                gpiospec->args[0], gpiospec->args[0]/gc->ngpio);
        return -EINVAL;
    }

    if (flags)
        *flags = gpiospec->args[1];

    return gpiospec->args[0] - gc->base;
}

static struct gpio_chip ak_gpio_chip = {
    .label = MODULE_NAME,
    .owner = THIS_MODULE,
    .request = gpiochip_generic_request,
    .free = gpiochip_generic_free,
    .get_direction = ak_gpio_get_direction,
    .direction_input = ak_gpio_direction_input,
    .direction_output = ak_gpio_direction_output,
    .get = ak_gpio_get,
    .set = ak_gpio_set,
    .set_drive = ak_gpio_set_drive,
    .get_drive = ak_gpio_get_drive,
    .set_pull_polarity = ak_gpio_set_pull_polarity,
    .get_pull_polarity = ak_gpio_get_pull_polarity,
    .set_pull_enable = ak_gpio_set_pull_enable,
    .get_pull_enable = ak_gpio_get_pull_enable,
    .set_input_enable = ak_gpio_set_input_enable,
    .get_input_enable = ak_gpio_get_input_enable,
    .set_slew_rate = ak_gpio_set_slew_rate,
    .get_slew_rate = ak_gpio_get_slew_rate,
    .to_irq = ak_gpio_to_irq,
    .base = 0,
    .ngpio = AK_NUM_GPIOS,
    .can_sleep = false,
    .of_gpio_n_cells = 2,
    .of_xlate = ak_gpio_of_xlate,
};

static void ak_pinctrl_irq_handler(struct irq_desc *desc)
{
    struct irq_chip *chip = irq_desc_get_chip(desc);
    struct ak_pin_bank *bank = irq_desc_get_handler_data(desc);
    unsigned long irq_status;
    int pin_irq;

    int off = 0;
    chained_irq_enter(chip, desc);
    irq_status = RAW_READL_DBG(bank->reg_base + AK_GPIO_STATUS_REG);
    for_each_set_bit(off, &irq_status, 32) {
        if (off >= bank->nr_pins)
            break;

        pin_irq = irq_find_mapping(bank->irq_domain, off);

        irq_status |= 0x1 << pin_irq;
        RAW_WRITEL_DBG(irq_status ,bank->reg_base + AK_GPIO_STATUS_REG);

        generic_handle_irq(pin_irq);
    }
    chained_irq_exit(chip, desc);
}

/*
 *  irq_ack called by handle_edge_irq when using edge trigger mode.
 *  Author:zhang zhipeng
 *  date: 2019-5-3
 */
static void ak_gpio_irq_ack(struct irq_data *data)
{
//    struct ak_pin_bank *bank = irq_data_get_irq_chip_data(data);
    //unsigned pin = irqd_to_hwirq(data);
    pr_debug("%s\n", __func__);
}

static void ak_gpio_irq_enable(struct irq_data *data)
{
    struct ak_pin_bank *bank = irq_data_get_irq_chip_data(data);
    unsigned pin = irqd_to_hwirq(data);
    void __iomem *reg = bank->reg_base + AK_GPIO_INTEN_REG;
    u32 regval;

    regval = RAW_READL_DBG(reg);
    regval |= BIT(pin);
    RAW_WRITEL_DBG(regval, reg);
}

static void ak_gpio_irq_disable(struct irq_data *data)
{
    struct ak_pin_bank *bank = irq_data_get_irq_chip_data(data);
    unsigned pin = irqd_to_hwirq(data);
    void __iomem *reg = bank->reg_base + AK_GPIO_INTEN_REG;
    u32 regval;

    regval = RAW_READL_DBG(reg);
    regval &= ~(BIT(pin));
    RAW_WRITEL_DBG(regval, reg);
}

/* slower path for reconfiguring IRQ type */
static int __ak_gpio_irq_set_type_enabled(struct ak_pin_bank *bank,
                    unsigned offset, unsigned int type)
{
    u32 regval;
    void __iomem *reg_inten = bank->reg_base + AK_GPIO_INTEN_REG;
    void __iomem *reg_intm  = bank->reg_base + AK_GPIO_INT_MODE_REG;
    void __iomem *reg_intp  = bank->reg_base + AK_GPIO_INTPOL_REG;
    void __iomem *reg_inten_double = bank->reg_base + AK_GPIO_DBLEDGE_REG;
    int bit = offset;
    
    /*
    * reg_inten/AK_GPIO_INTEN_REG
    * GPIO Interrupt Enable Register.
    * write 1 to enable the specific gpio's interrupt
    * write 0 to disable the specific gpio's interrupt
    *
    * reg_intm/AK_GPIO_INT_MODE_REG
    * GPIO Interrupt Mode Select Register.Interrupt trigger mode
    * write 1 to make edge-trigger
    * write 0 to make level-trigger
    *
    * reg_intp/AK_GPIO_INTPOL_BASE
    * GPIO Interrupt Polarity Select Register.Interrupt "input" polarity
    * Edge-trigger
    * write 0 to falling edge
    * write 1 to rasing edge
    *
    * Level-trigger
    * write 0 to active low
    * write 1 to active high
    */

    switch (type) {
        case IRQ_TYPE_NONE:
            if (bank->irq_type[offset] != type) {
                regval = RAW_READL_DBG(reg_inten);
                regval &= ~(BIT(bit));
                RAW_WRITEL_DBG(regval, reg_inten);

                regval = RAW_READL_DBG(reg_inten_double);
                regval &= ~(BIT(bit));
                RAW_WRITEL_DBG(regval, reg_inten_double);

                bank->irq_type[offset] = type;
            }
            break;
        case IRQ_TYPE_EDGE_RISING:
        case IRQ_TYPE_EDGE_FALLING:
            if (bank->irq_type[offset] != type) {
                /* Make the edge-trigger */
                regval = RAW_READL_DBG(reg_intm);
                regval |= BIT(bit);
                RAW_WRITEL_DBG(regval, reg_intm);

                regval = RAW_READL_DBG(reg_inten_double);
                regval &= ~(BIT(bit));
                RAW_WRITEL_DBG(regval, reg_inten_double);

                /* Config the trigger way*/
                regval = RAW_READL_DBG(reg_intp);
                if (IRQ_TYPE_EDGE_FALLING == type)
                    regval &= ~(BIT(bit));
                else
                    regval |= BIT(bit);
                RAW_WRITEL_DBG(regval, reg_intp);
                bank->irq_type[offset] = type;
            }
            break;
        case IRQ_TYPE_EDGE_BOTH:
            if (bank->irq_type[offset] != type) {
                /* Make the edge-trigger */
                regval = RAW_READL_DBG(reg_intm);
                regval |= BIT(bit);
                RAW_WRITEL_DBG(regval, reg_intm);

                regval = RAW_READL_DBG(reg_inten_double);
                regval |= BIT(bit);
                RAW_WRITEL_DBG(regval, reg_inten_double);

                bank->irq_type[offset] = type;
            }
            break;
        case IRQ_TYPE_LEVEL_HIGH:
        case IRQ_TYPE_LEVEL_LOW:
            if (bank->irq_type[offset] != type) {
                /* Make the level-trigger */
                regval = RAW_READL_DBG(reg_intm);
                regval &= ~(BIT(bit));
                RAW_WRITEL_DBG(regval, reg_intm);

                /* Config the trigger way*/
                regval = RAW_READL_DBG(reg_intp);
                if (IRQ_TYPE_LEVEL_LOW == type)
                    regval &= ~(BIT(bit));
                else
                    regval |= BIT(bit);
                RAW_WRITEL_DBG(regval, reg_intp);
                bank->irq_type[offset] = type;
            }
            break;
        default:
            return -EINVAL;
    }
    return 0;
}
/*end of __ak_gpio_irq_set_type_enabled*/

static int ak_gpio_irq_set_type(struct irq_data *data, unsigned int type)
{
    struct ak_pin_bank *bank = irq_data_get_irq_chip_data(data);
    unsigned pin = irqd_to_hwirq(data);	
    int ret;

    /*
    * First irq_set_type called by __setup_irq,
    * and then irq_enable  called by __setup_irq.
    * refer to kernel/irq/manage.c.  fixed by zhang zhipeng (2019/5/3)
    */
    ret = __ak_gpio_irq_set_type_enabled(bank, pin, type);

    if (type & IRQ_TYPE_EDGE_BOTH)
        irq_set_handler_locked(data, handle_edge_irq);
    else
        irq_set_handler_locked(data, handle_level_irq);

    return ret;
}

static struct irq_chip ak_gpio_irq_chip = {
    .name = "ak_gpio_edge",
    .irq_ack    = ak_gpio_irq_ack,
    .irq_enable = ak_gpio_irq_enable,
    .irq_disable = ak_gpio_irq_disable,
    .irq_set_type = ak_gpio_irq_set_type,
    .irq_mask = ak_gpio_irq_disable,
    .irq_mask_ack = ak_gpio_irq_disable,
    .irq_unmask = ak_gpio_irq_enable,
};

static int ak_pctl_get_groups_count(struct pinctrl_dev *pctldev)
{
    return ARRAY_SIZE(ak_gpio_groups);
}

static const char *ak_pctl_get_group_name(struct pinctrl_dev *pctldev,
        unsigned selector)
{
    return ak_gpio_groups[selector];
}

static int ak_pctl_get_group_pins(struct pinctrl_dev *pctldev,
        unsigned selector,
        const unsigned **pins,
        unsigned *num_pins)
{
    *pins = &ak_gpio_pins[selector].number;
    *num_pins = 1;

    return 0;
}

static void ak_pctl_pin_dbg_show(struct pinctrl_dev *pctldev,
        struct seq_file *s,
        unsigned offset)
{
    struct ak_pinctrl *pc = pinctrl_dev_get_drvdata(pctldev);
    unsigned int fsel = ak_pinctrl_fsel_get(pc, offset);
    struct ak_pin_bank *bank = pin_to_bank(pc, offset);
    const char *fname = ak_funcs[fsel];
    int irq = irq_find_mapping(bank->irq_domain, offset);

    seq_printf(s, "function %s; irq %d (%s)",
        fname, irq, irq_type_names[bank->irq_type[offset]]);
}

static int ak_pctl_dt_node_to_map_func(struct ak_pinctrl *pc,
        struct device_node *np, u32 pin, u32 fnum,
        struct pinctrl_map **maps)
{
    struct pinctrl_map *map = *maps;

    if (fnum >= ARRAY_SIZE(ak_funcs)) {
        dev_err(pc->dev, "%s: invalid anyka,function %d\n",
            of_node_full_name(np), fnum);
        return -EINVAL;
    }

    map->type = PIN_MAP_TYPE_MUX_GROUP;
    map->data.mux.group = ak_gpio_groups[pin];
    map->data.mux.function = ak_funcs[fnum];
    (*maps)++;

    return 0;
}

static int ak_pctl_dt_node_to_map_pull(struct ak_pinctrl *pc,
        struct device_node *np, u32 pin, u32 pull,
        struct pinctrl_map **maps)
{
    struct pinctrl_map *map = *maps;
    unsigned long *configs;

    configs = kzalloc(sizeof(*configs), GFP_KERNEL);
    if (!configs)
        return -ENOMEM;
    configs[0] = pull;

    map->type = PIN_MAP_TYPE_CONFIGS_PIN;
    map->data.configs.group_or_pin = ak_gpio_pins[pin].name;
    map->data.configs.configs = configs;
    map->data.configs.num_configs = 1;
    (*maps)++;

    return 0;
}

static int ak_pctl_dt_node_to_map(struct pinctrl_dev *pctldev,
        struct device_node *np,
        struct pinctrl_map **map, unsigned *num_maps)
{
    struct ak_pinctrl *pc = pinctrl_dev_get_drvdata(pctldev);
    struct property *pins, *funcs, *pulls;
    int num_pins, num_funcs, num_pulls, maps_per_pin;
    struct pinctrl_map *maps, *cur_map;
    int i, err;
    u32 pin, func, pull;

    pins = of_find_property(np, "anyka,pins", NULL);
    if (!pins) {
        dev_err(pc->dev, "%s: missing anyka,pins property\n",
                of_node_full_name(np));
        return -EINVAL;
    }

    funcs = of_find_property(np, "anyka,function", NULL);
    pulls = of_find_property(np, "anyka,pull", NULL);

    if (!funcs && !pulls) {
        dev_err(pc->dev,
            "%s: neither anyka,function nor anyka,pull specified\n",
            of_node_full_name(np));
        return -EINVAL;
    }

    num_pins = pins->length / 4;
    num_funcs = funcs ? (funcs->length / 4) : 0;
    num_pulls = pulls ? (pulls->length / 4) : 0;

    if (num_funcs > 1 && num_funcs != num_pins) {
        dev_err(pc->dev,
            "%s: anyka,function must have 1 or %d entries\n",
            of_node_full_name(np), num_pins);
        return -EINVAL;
    }

    if (num_pulls > 1 && num_pulls != num_pins) {
        dev_err(pc->dev,
            "%s: anyka,pull must have 1 or %d entries\n",
            of_node_full_name(np), num_pins);
        return -EINVAL;
    }

    maps_per_pin = 0;
    if (num_funcs)
        maps_per_pin++;
    if (num_pulls)
        maps_per_pin++;
    cur_map = maps = kzalloc(num_pins * maps_per_pin * sizeof(*maps),
                GFP_KERNEL);
    if (!maps)
        return -ENOMEM;

    for (i = 0; i < num_pins; i++) {
        err = of_property_read_u32_index(np, "anyka,pins", i, &pin);
        if (err)
            goto out;
        if (pin >= ARRAY_SIZE(ak_gpio_pins)) {
            dev_err(pc->dev, "%s: invalid anyka,pins value %d\n",
                of_node_full_name(np), pin);
            err = -EINVAL;
            goto out;
        }
        if (num_funcs) {
            err = of_property_read_u32_index(np, "anyka,function",
                    (num_funcs > 1) ? i : 0, &func);
            if (err)
                goto out;
            err = ak_pctl_dt_node_to_map_func(pc, np, pin,
                            func, &cur_map);
            if (err)
                goto out;
        }
        if (num_pulls) {
            err = of_property_read_u32_index(np, "anyka,pull",
                    (num_pulls > 1) ? i : 0, &pull);
            if (err)
                goto out;
            err = ak_pctl_dt_node_to_map_pull(pc, np, pin,
                            pull, &cur_map);
            if (err)
                goto out;
        }
    }

    *map = maps;
    *num_maps = num_pins * maps_per_pin;
    return 0;

out:
    kfree(maps);
    return err;
}
/*end of ak_pctl_dt_node_to_map*/


static void ak_pctl_dt_free_map(struct pinctrl_dev *pctldev,
        struct pinctrl_map *maps, unsigned num_maps)
{
    int i;

    for (i = 0; i < num_maps; i++)
        if (maps[i].type == PIN_MAP_TYPE_CONFIGS_PIN)
            kfree(maps[i].data.configs.configs);

    kfree(maps);
}

static const struct pinctrl_ops ak_pctl_ops = {
    .get_groups_count = ak_pctl_get_groups_count,
    .get_group_name = ak_pctl_get_group_name,
    .get_group_pins = ak_pctl_get_group_pins,
    .pin_dbg_show = ak_pctl_pin_dbg_show,
    .dt_node_to_map = ak_pctl_dt_node_to_map,
    .dt_free_map = ak_pctl_dt_free_map,
};

static int ak_pmx_get_functions_count(struct pinctrl_dev *pctldev)
{
    return ARRAY_SIZE(ak_funcs);
}

static const char *ak_pmx_get_function_name(struct pinctrl_dev *pctldev,
        unsigned selector)
{
    return ak_funcs[selector];
}

static int ak_pmx_get_function_groups(struct pinctrl_dev *pctldev,
        unsigned selector,
        const char * const **groups,
        unsigned * const num_groups)
{
    *groups = ak_gpio_groups;
    *num_groups = ARRAY_SIZE(ak_gpio_groups);

    return 0;
}

/* pin just use to get pinctrl reg*/
/* ak3918av200 needn't to get bit by pin*/
static int ak_set_share(struct ak_pinctrl *pc, int pin, int sel)
{
    u32 regval;
    void __iomem *reg = ak_get_pinctrl_reg(pc, pin);
    
    regval = RAW_READL_DBG(reg);
    regval &= ~(0x7 << AK_PINCTRL_FUNC_CFG_BIT);
    regval |= ((sel & 0x7) << AK_PINCTRL_FUNC_CFG_BIT);
    RAW_WRITEL_DBG(regval, reg);
    
    ak_log_print("PIN_%d: FUNC(%d) 0x%p:0x%x\n", pin, sel, reg,
        RAW_READL_DBG(reg));
    pc->fsel[pin] = sel;
    return 0;
}

static int ak_pmx_set(struct pinctrl_dev *pctldev,
        unsigned func_selector,
        unsigned group_selector)
{
    struct ak_pinctrl *pc = pinctrl_dev_get_drvdata(pctldev);

    ak_set_share(pc, group_selector, func_selector);
    return 0;
}

/**
*
*@brief: ak_pinctrl_fsel_reset
*@param[in] struct ak_pinctrl *pc
*@param[in] unsigned pin
*@param[in] unsigned fsel
*@return: int
*
**/
static inline void ak_pinctrl_fsel_reset(struct ak_pinctrl *pc,
                    unsigned pin, unsigned fsel)
{
    u32 regval;
    int cur = pc->fsel[pin];
    void __iomem *reg = ak_get_pinctrl_reg(pc, pin);

    if (cur == -1)
        return;

    regval = RAW_READL_DBG(reg);
    regval &= ~(0x7 << AK_PINCTRL_FUNC_CFG_BIT);
    RAW_WRITEL_DBG(regval, reg);


    ak_log_print("PIN_%d fsel reset 0x%p:0x%x\n", pin, reg,
            RAW_READL_DBG(reg));

    pc->fsel[pin] = -1;
}

static void ak_pmx_gpio_disable_free(struct pinctrl_dev *pctldev,
        struct pinctrl_gpio_range *range,
        unsigned offset)
{
    struct ak_pinctrl *pc = pinctrl_dev_get_drvdata(pctldev);

    /* disable by setting sharepin cfg to default value */
    ak_pinctrl_fsel_reset(pc, offset, pc->fsel[offset]);
}

static int ak_pmx_gpio_set_direction(struct pinctrl_dev *pctldev,
        struct pinctrl_gpio_range *range,
        unsigned offset,
        bool input)
{
    u32 regval;
    struct ak_pinctrl *pc = pinctrl_dev_get_drvdata(pctldev);
    struct ak_pin_bank *bank = pin_to_bank(pc, offset);
    void __iomem *reg = bank->reg_base + AK_GPIO_DIR_REG;
    unsigned int bit = AK_GPIO_REG_SHIFT(offset); 
    int gpio_cfg = input ?
        AK_PIN_AS_GPIO_IN : AK_PIN_AS_GPIO_OUT;

    regval = RAW_READL_DBG(reg);
    if(gpio_cfg == AK_PIN_AS_GPIO_IN){
        regval &= ~(BIT(bit));
    }else{
        regval |= BIT(bit);
    }
    RAW_WRITEL_DBG(regval, reg);

    return 0;
}

static const struct pinmux_ops ak_pmx_ops = {
    .get_functions_count = ak_pmx_get_functions_count,
    .get_function_name = ak_pmx_get_function_name,
    .get_function_groups = ak_pmx_get_function_groups,
    .set_mux = ak_pmx_set,
    .gpio_disable_free = ak_pmx_gpio_disable_free,
    .gpio_set_direction = ak_pmx_gpio_set_direction,
};

static int ak_pinconf_get(struct pinctrl_dev *pctldev,
            unsigned pin, unsigned long *config)
{
    /* No way to read back config in HW */
    return -ENOTSUPP;
}

static int ak_pinconf_set(struct pinctrl_dev *pctldev,
            unsigned pin, unsigned long *configs,
            unsigned num_configs)
{
    u8 drive, ie, pd_en, pu_en, st0, st1, hold, slew;
    u8 pupd_sel, pupd_en, dir_en, dir, output_en, output, delay_cfg;
    struct ak_pinctrl *pc = pinctrl_dev_get_drvdata(pctldev);
    struct ak_pin_bank *bank = pin_to_bank(pc, pin);
    void __iomem *reg = ak_get_pinctrl_reg(pc, pin);
    u32 regval;
    if (num_configs != 1)
        return -EINVAL;

    /* for km02 pin mux register*/
    /**
     * configs
     * bit[31:29] DS, Driving selector
     * bit[28] IE, input enable
     * bit[27] PD pull down enable
     * bit[26] PU  up enable
     * bit[25] ST0, ST(ST0)=1 enables Schmitt trigger input function 
     * bit[24] ST1, Schmitt trigger enable
     * bit[23] HE, hold enable
     * bit[22] SL, Slew-rate-control enable
     * bit[21] PS, pull up(1) or pull down(0) selection
     * bit[20] PE，pull up and pull down enable
     * bit[19] DIR, io direction 0 is output, 1 is input
     * bit[18] output enable
     * bit[17] output level, 0 is low level, 1 is high level
     * bit[14:8] Delay cfg, only for GPIO39~52, GPIO57~59，GPIO61~84
     * bit[2:0] Function cfg  (ak3918av200_pmx_set has been configed)
    */
    drive = ((configs[0]>>29) & 0x7);
    ie = ((configs[0]>>28) & 0x1);
    pd_en = ((configs[0]>>27) & 0x1);
    pu_en = ((configs[0]>>26) & 0x1);
    st0 = ((configs[0]>>25) & 0x1);
    st1 = ((configs[0]>>24) & 0x1);
    hold = ((configs[0]>>23) & 0x1);
    slew = ((configs[0]>>22) & 0x1);
    pupd_sel = ((configs[0]>>21) & 0x1);
    pupd_en = ((configs[0]>>20) & 0x1);
    dir_en = ((configs[0]>>19) & 0x1);
    dir = ((configs[0]>>18) & 0x1);
    output_en = ((configs[0]>>17) & 0x1);
    output =  ((configs[0]>>16) & 0x1);
    delay_cfg = ((configs[0]>>8) & 0x7F);

    regval = RAW_READL_DBG(reg);
    /*
    *reserve the lower 3 bit
    */
    regval &= 0x7;

    /*
    *1.8V GPIO can not select DRIVE_SEL4~7
    *GPIO[54:35] can not select DRIVE_SEL4~7
    *if selector error, config DRIVE_SEL3
    */
    if( ( (drive << AK_PINCTRL_DRI_BIT) > DRIVE_SEL3 )
        && (pin >= 35 && pin <= 54) ){
        pr_err("%s, PIN[%d] drive sel failed!", __func__, pin);
        regval |= DRIVE_SEL3;
    }else{
        regval |= (drive << AK_PINCTRL_DRI_BIT);
    }

    if(delay_cfg){
        if( (pin >= 39 && pin <= 52) || (pin >= 57 && pin <= 59)
            || (pin >= 61 && pin <= 84) ){
            regval |= (delay_cfg << AK_PINCTRL_DELAY_BIT);
        }else{
            pr_err("%s, PIN[%d] delay cfg failed!", __func__, pin);
        }
    }

    /*
    *perform both configurations simultaneously
    */
    if ( (pu_en<<AK_PINCTRL_PUEN_BIT) == PULL_UP_EN ) {
        regval |= PUPD_EN | PULL_UP_EN;
    }else if( (pd_en<<AK_PINCTRL_PDEN_BIT) == PULL_DOWN_EN ){
        regval |= PUPD_EN | PULL_DOWN_EN;
    }
    if ( (pupd_sel<<AK_PINCTRL_PSEL_BIT) == PULL_UP) {
        regval |= PULL_UP;
    }else if( (pupd_sel<<AK_PINCTRL_PSEL_BIT) == PULL_DOWN){
        regval |= PULL_DOWN;
    }

    regval |= ( (ie << AK_PINCTRL_IE_BIT) | (st0 << AK_PINCTRL_SMT0_EN_BIT)
            | (st1 << AK_PINCTRL_SMT1_EN_BIT) | (hold << AK_PINCTRL_HOLDEN_BIT)
            | (slew << AK_PINCTRL_SLEW_BIT) );

    RAW_WRITEL_DBG(regval, reg);

    if(dir_en){
        if ( (dir << AK_PINCTRL_DIR_BIT) == DIR_OUTPUT ) { // gpio direction enable?
            pinctrl_gpio_direction_output(bank->gc.base + pin%32);
        }else if( (dir << AK_PINCTRL_DIR_BIT) == DIR_INPUT ){
            ak_gpio_direction_input(&bank->gc, pin%32);
        }
    }
    if ( (output_en << AK_PINCTRL_OUTEN_BIT) == OUTPUT_EN ) {
        ak_gpio_set(&bank->gc, pin%32, output);
    }

    return 0;
}

/* for gpio PU/PD config */
static const struct pinconf_ops ak_pinconf_ops = {
    .pin_config_get = ak_pinconf_get,
    .pin_config_set = ak_pinconf_set,
};

static struct pinctrl_desc ak_pinctrl_desc = {
    .name = MODULE_NAME,
    .pins = ak_gpio_pins,
    .npins = ARRAY_SIZE(ak_gpio_pins),
    .pctlops = &ak_pctl_ops,
    .pmxops = &ak_pmx_ops,
    .confops = &ak_pinconf_ops,
    .owner = THIS_MODULE,
};

// can get banks dynamic by dts
static struct ak_pin_bank ak3918av200_pin_banks[] = {
    PIN_BANK_SET(0, 0,  32, "gpio0"),
    PIN_BANK_SET(1, 32, 32, "gpio1"),
    PIN_BANK_SET(2, 64, 32, "gpio2"),
    PIN_BANK_SET(3, 96, 32, "gpio3"),
};


// value set after banks set over; 
static struct ak_pin_ctrl ak3918av200_pin_ctrl = {
        .pin_banks      = ak3918av200_pin_banks,
        .nr_banks       = ARRAY_SIZE(ak3918av200_pin_banks),
        .nr_pins        = 32*ARRAY_SIZE(ak3918av200_pin_banks),
        .label          = "AnyCloud3918AV200-GPIO",
};


static const struct of_device_id ak_pinctrl_dt_match[] = {
    { .compatible = "anyka,ak3918av200-pinctrl",
        .data = &ak3918av200_pin_ctrl },
    {},
};


static const struct of_device_id ak_bank_match[] = {
    { .compatible = "anyka,gpio-bank" },
    {},
};

static int ak_get_bank_data(struct ak_pin_bank *bank,
                  struct ak_pinctrl *info)
{
    struct resource res;

    if (of_address_to_resource(bank->of_node, 0, &res)) {
        pr_err("cannot find IO resource for bank\n");
        return -ENOENT;
    }
    
    bank->reg_base = devm_ioremap_resource(info->dev, &res);
    if (IS_ERR(bank->reg_base))
        return -1;
    return 0;
}

#ifndef CONFIG_SYS_FAST_BOOT
static int ak_pinctrl_reset(
                struct platform_device *pdev,
                struct reset_control *rstc, const char *id)
{
    int ret;

    rstc = devm_reset_control_get(&pdev->dev, id);
    if (IS_ERR(rstc)) {
        dev_err(&pdev->dev, "No reset controller specified\n");
        ret = PTR_ERR(rstc);
        return ret;
    }

    ret = reset_control_assert(rstc);
    if (ret) {
        dev_err(&pdev->dev, "unable to reset_control_assert\n");
    }
    udelay(1);
    ret = reset_control_deassert(rstc);
    if (ret) {
        dev_err(&pdev->dev, "unable to reset_control_deassert\n");
    }
    return ret;
}

static int ak_pinctrl_enable_clk(
                  struct platform_device *pdev,
                  struct clk *clk, const char *id)
{
    int ret;

    clk = devm_clk_get(&pdev->dev, id);
    if (IS_ERR(clk)) {
        pr_err("[%s], get %s failed\n", __func__, id);
        ret = PTR_ERR(clk);
        return ret;
    }

    clk_prepare_enable(clk);

    return 0;
}

#else
static int __maybe_unused ak_pinctrl_reset(
                struct platform_device *pdev,
                struct reset_control *rstc, const char *id)
{
    int ret;

    rstc = devm_reset_control_get(&pdev->dev, id);
    if (IS_ERR(rstc)) {
        dev_err(&pdev->dev, "No reset controller specified\n");
        ret = PTR_ERR(rstc);
        return ret;
    }

    ret = reset_control_assert(rstc);
    if (ret) {
        dev_err(&pdev->dev, "unable to reset_control_assert\n");
    }
    udelay(1);
    ret = reset_control_deassert(rstc);
    if (ret) {
        dev_err(&pdev->dev, "unable to reset_control_deassert\n");
    }
    return ret;
}

static int __maybe_unused ak_pinctrl_enable_clk(
                  struct platform_device *pdev,
                  struct clk *clk, const char *id)
{
    int ret;

    clk = devm_clk_get(&pdev->dev, id);
    if (IS_ERR(clk)) {
        pr_err("[%s], get %s failed\n", __func__, id);
        ret = PTR_ERR(clk);
        return ret;
    }

    clk_prepare_enable(clk);

    return 0;
}
#endif

/* retrieve the soc specific data */
static struct ak_pin_ctrl *ak_pinctrl_get_soc_data(
                        struct platform_device *pdev,
                        struct ak_pinctrl *info)
{
    const struct of_device_id *match;
    struct device_node *node = pdev->dev.of_node;
    struct device_node *np;
    struct ak_pin_ctrl *ctrl;
    struct ak_pin_bank *bank;
    int i;

    match = of_match_node(ak_pinctrl_dt_match, node);
    
    ctrl = (struct ak_pin_ctrl *)match->data;
    
    for_each_child_of_node(node, np) {
        if (!of_find_property(np, "gpio-controller", NULL))
            continue;
    
        bank = ctrl->pin_banks;
        for (i = 0; i < ctrl->nr_banks; ++i, ++bank) {
            if (!strcmp(bank->name, np->name)) {
                bank->of_node = np;

                if (!ak_get_bank_data(bank, info))
                    bank->valid = true;

                break;
            }
        }
    }
    return ctrl;
}

static int ak_pinctrl_register(struct platform_device *pdev,
                    struct ak_pinctrl *info)
{
    struct ak_pin_bank *pin_bank;
    int i,bank; 
    info->pctl_dev = devm_pinctrl_register(&pdev->dev, &ak_pinctrl_desc, info);

    if (IS_ERR(info->pctl_dev)) {
        dev_err(&pdev->dev, "could not register pinctrl driver\n");
        return PTR_ERR(info->pctl_dev);
    }

    for ( i = 0; i < AK_NUM_GPIOS; i++) {
        info->fsel[i] = -1;
    }

    for (bank = 0; bank < info->ctrl->nr_banks; ++bank) {
        pin_bank = &info->ctrl->pin_banks[bank];
        pin_bank->grange.name = pin_bank->name;
        pin_bank->grange.id = bank;
        pin_bank->grange.pin_base = pin_bank->pin_base;
        pin_bank->grange.base = pin_bank->gc.base;
        pin_bank->grange.npins = pin_bank->gc.ngpio;
        pin_bank->grange.gc = &pin_bank->gc;
        pinctrl_add_gpio_range(info->pctl_dev, &pin_bank->grange);
    }

    return 0;
}

static int ak_interrupts_register(struct platform_device *pdev,
                        struct ak_pinctrl *info)
{
    struct ak_pin_ctrl *ctrl = info->ctrl;
    struct ak_pin_bank *bank = ctrl->pin_banks;
    int i,j;
    
    for ( i = 0; i < ctrl->nr_banks; ++i, ++bank ) {
        // if donymic calloc nr_banks;
        // don't need to judger if valid;
        if(!bank->valid) {
            dev_warn(&pdev->dev,"bank %s isn't valid.\n",
                        bank->name);
            continue;
        }

        bank->irq = irq_of_parse_and_map(bank->of_node, 0);
        if(bank->irq < 0) {
            dev_err(&pdev->dev,"bank %s 's irq is err.\n",
                        bank->name);
            continue;
        }
    
        bank->irq_domain = irq_domain_add_linear(bank->of_node, 32,
                                     &irq_domain_simple_ops, bank);
        
        if (!bank->irq_domain){
            dev_err(&pdev->dev,"could not create IRQ domain for bank %s.\n",
                        bank->name);
            continue;
        }

        for( j = 0; j < AK_BANK_GPIOS; ++j ) {
            int irq;
            if( (i*32 + j) > AK_NUM_GPIOS){
                break;
            }
            irq = irq_create_mapping(bank->irq_domain, j);
            bank->irq_type[i] = 0;
            info->fsel[i*32 + j] = -1;
            irq_set_chip_and_handler(irq, &ak_gpio_irq_chip,
                                    handle_level_irq);
            irq_set_chip_data(irq, bank);
        }

        // this func use for connect 1st irq to 2nd irq.
        irq_set_chained_handler_and_data(bank->irq,
                            ak_pinctrl_irq_handler, bank);  
    }
    
    return 0;
}

static int ak_gpiolib_register(struct platform_device *pdev,
                        struct ak_pinctrl *info)
{
    struct ak_pin_ctrl *ctrl = info->ctrl;
    struct ak_pin_bank *bank = ctrl->pin_banks;
    struct gpio_chip *gc;
    int ret;
    int i;

    for (i = 0; i < ctrl->nr_banks; ++i, ++bank) {
        // if donymic calloc nr_banks;
        // don't need to judger if valid;
        if (!bank->valid) {
            printk("bank->valid:%d",bank->valid);
            pr_info("bank %s is not valid\n", bank->name);
            continue;
        }

        // bank's info has be set already 
        bank->gc = ak_gpio_chip;

        gc = &bank->gc;
        gc->base = bank->pin_base;
        gc->ngpio = bank->nr_pins;
        gc->parent = &pdev->dev;
        gc->of_node = bank->of_node;
        gc->label = bank->name;

        ret = gpiochip_add_data(gc, bank);
        if (ret) {
            pr_info("failed to register gpio_chip %s, error code: %d\n",
                            gc->label, ret);
            goto fail;
        }
    }

    ak_interrupts_register(pdev, info);

    return 0;

fail:
    for (--i, --bank; i >= 0; --i, --bank) {
        if (!bank->valid)
            continue;
        gpiochip_remove(&bank->gc);
    }
    return ret;
}

                        
static int ak_gpiolib_unregister(struct platform_device *pdev,
                        struct ak_pinctrl *info)
{
    struct ak_pin_ctrl *ctrl = info->ctrl;
    struct ak_pin_bank *bank = ctrl->pin_banks;
    int i;

    for (i = 0; i < ctrl->nr_banks; ++i, ++bank) {
        if (!bank->valid)
            continue;
        gpiochip_remove(&bank->gc);
    }

    return 0;
}

#define ak_gpio_suspend     NULL
#define ak_gpio_resume      NULL

struct syscore_ops ak_gpio_syscore_ops = {
    .suspend    = ak_gpio_suspend,
    .resume     = ak_gpio_resume,
};

static int ak_pinctrl_probe(struct platform_device *pdev)
{
    struct ak_pinctrl *info;
    struct device *dev = &pdev->dev;
    struct ak_pin_ctrl *ctrl;
    struct device_node *np = pdev->dev.of_node;
    struct resource res;
    int ret;

    if (!dev->of_node) {
        pr_err( "func:%s,device tree node not found\n",__func__);
        return -ENODEV;
    }

    info = devm_kzalloc(dev, sizeof(*info), GFP_KERNEL);
    if (!info)
        return -ENOMEM;

    info->dev = dev;
    if (of_address_to_resource(np, 0, &res)) {
        pr_err("cannot find resource for pinctrl\n");
        return -ENOENT;
    }
    
    info->reg_base = devm_ioremap_resource(dev, &res);
    if (IS_ERR(info->reg_base))
        return -1;
    pinctrl_reg = info->reg_base;

#ifndef CONFIG_SYS_FAST_BOOT
    if (!device_property_read_bool(dev, "no-reset-gpio-clk")) {
        ret = ak_pinctrl_reset(pdev, info->gpio0_rstc, "gpio0");
        if (ret)
            return ret;
        ret = ak_pinctrl_reset(pdev, info->gpio1_rstc, "gpio1");
        if (ret)
            return ret;
        ret = ak_pinctrl_reset(pdev, info->gpio2_rstc, "gpio2");
        if (ret)
            return ret;
        ret = ak_pinctrl_reset(pdev, info->gpio3_rstc, "gpio3");
        if (ret)
            return ret;
        ret = ak_pinctrl_enable_clk(pdev, info->gpio0_clk, "gpio0_gclk");
        if (ret)
            return ret;
        ret = ak_pinctrl_enable_clk(pdev, info->gpio1_clk, "gpio1_gclk");
        if (ret)
            return ret;
        ret = ak_pinctrl_enable_clk(pdev, info->gpio2_clk, "gpio2_gclk");
        if (ret)
            return ret;
        ret = ak_pinctrl_enable_clk(pdev, info->gpio3_clk, "gpio3_gclk");
        if (ret)
            return ret;
    }
#endif

    ctrl = ak_pinctrl_get_soc_data(pdev, info);
    if (!ctrl) {
        dev_err(dev, "driver data not available\n");
        return -EINVAL;
    }
    info->ctrl = ctrl;

    ret = ak_gpiolib_register(pdev, info);
    if (ret)
        return ret;

    ret = ak_pinctrl_register(pdev, info);
    if (ret) {
        ak_gpiolib_unregister(pdev, info);
        return ret;
    }
    
    platform_set_drvdata(pdev, info);
    
    return 0;
}

static int ak_pinctrl_remove(struct platform_device *pdev)
{
    int i;
    struct ak_pinctrl *pc = platform_get_drvdata(pdev);
    struct ak_pin_bank *bank;

    unregister_syscore_ops(&ak_gpio_syscore_ops);

    pinctrl_unregister(pc->pctl_dev);
    for(i = 0; i < AK_BANK_NUM; i++){
        bank = pc->ctrl->pin_banks + i;
        gpiochip_remove(&bank->gc);
    }
    clk_disable_unprepare(pc->gpio0_clk);
    clk_disable_unprepare(pc->gpio1_clk);
    clk_disable_unprepare(pc->gpio2_clk);
    clk_disable_unprepare(pc->gpio3_clk);
    clk_put(pc->gpio0_clk);
    clk_put(pc->gpio1_clk);
    clk_put(pc->gpio2_clk);
    clk_put(pc->gpio3_clk);

    return 0;
}

static struct platform_driver ak_pinctrl_driver = {
    .probe = ak_pinctrl_probe,
    .remove = ak_pinctrl_remove,
    .driver = {
        .name = MODULE_NAME,
        .of_match_table = ak_pinctrl_dt_match,
    },
};

static int __init ak_pinctrl_init(void)
{
    return platform_driver_register(&ak_pinctrl_driver);
}

static void __exit ak_pinctrl_exit(void)
{
    platform_driver_unregister(&ak_pinctrl_driver);
}

subsys_initcall(ak_pinctrl_init);
module_exit(ak_pinctrl_exit);

MODULE_DESCRIPTION("km02 sharepin control driver");
MODULE_AUTHOR("Anyka");
MODULE_LICENSE("GPL");
MODULE_VERSION("1.0.02");
