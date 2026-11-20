// SPDX-License-Identifier: GPL-2.0+
/*
 * Copyright (C) 2011 OMICRON electronics GmbH
 *
 * based on drivers/mtd/nand/raw/nand_spl_load.c
 *
 * Copyright (C) 2011
 * Heiko Schocher, DENX Software Engineering, hs@denx.de.
 */

#include <common.h>
#include <image.h>
#include <log.h>
#include <spi.h>
#include <spi_flash.h>
#include <errno.h>
#include <spl.h>
#include <asm/io.h>
#include <asm/global_data.h>
#include <dm/ofnode.h>
#include <dm/uclass.h>
#include <dm/device-internal.h>
#include <asm-generic/gpio.h>
#include <mapmem.h>
#include <u-boot/lz4.h>

DECLARE_GLOBAL_DATA_PTR;

extern int device_probe(struct udevice *dev);
extern int pare_str_form_env(char *buf, char *str, char *out_buf);
extern int spl_device_parse(const char *const mtd_dev, ulong flash_size);
extern int get_mtdparts_by_partition_name (char *partition_name, unsigned long partition_num, unsigned long *run_add, unsigned long *run_len);
extern void spl_fdt_set_totalsize(void *fdt, uint32_t val);
extern int spl_fdt_chosen(void *fdt, int force, char *env_buf);


#ifndef CONFIG_SYS_FDT_PAD
#define CONFIG_SYS_FDT_PAD 0x3000
#endif

#if 0
//#ifdef CONFIG_SPL_OS_BOOT
/*
 * Load the kernel, check for a valid header we can parse, and if found load
 * the kernel and then device tree.
 */
static int spi_load_image_os(struct spl_image_info *spl_image,
			     struct spi_flash *flash,
			     struct image_header *header)
{
	int err;

	/* Read for a header, parse or error out. */
	spi_flash_read(flash, CONFIG_SYS_SPI_KERNEL_OFFS, sizeof(*header),
		       (void *)header);

	if (image_get_magic(header) != IH_MAGIC)
		return -1;

	err = spl_parse_image_header(spl_image, header);
	if (err)
		return err;

	spi_flash_read(flash, CONFIG_SYS_SPI_KERNEL_OFFS,
		       spl_image->size, (void *)spl_image->load_addr);

	/* Read device tree. */
	spi_flash_read(flash, CONFIG_SYS_SPI_ARGS_OFFS,
		       CONFIG_SYS_SPI_ARGS_SIZE,
		       (void *)CONFIG_SYS_SPL_ARGS_ADDR);

	return 0;
}
#endif

#define FASTSYS_SENSOR_DEV_NUM              3
#define FASTSYS_SENSOR_PWDN_LEVEL           0
#define FASTSYS_SENSOR_RESET_LEVEL          0

struct sensor_param {
    int power_pin[FASTSYS_SENSOR_DEV_NUM];
    int reset_pin[FASTSYS_SENSOR_DEV_NUM];
};
#define CAM_SENSOR_PWDN         (-1)
#define CAM_SENSOR_RESET        39

static struct sensor_param fastsys_sensor_param = {
    .power_pin = {CAM_SENSOR_PWDN, -1, -1},
    .reset_pin = {CAM_SENSOR_RESET, -1, -1}
};

static void fastsys_early_init(void)
{
    int i = 0;

    for (i = 0; i < FASTSYS_SENSOR_DEV_NUM; i++) {
        if (fastsys_sensor_param.power_pin[i] >= 0) {
            gpio_request(fastsys_sensor_param.power_pin[i], "power");
            gpio_direction_output(fastsys_sensor_param.power_pin[i], FASTSYS_SENSOR_PWDN_LEVEL);
        }
        if (fastsys_sensor_param.reset_pin[i] >= 0) {
            gpio_request(fastsys_sensor_param.reset_pin[i], "reset_pin");
            gpio_direction_output(fastsys_sensor_param.reset_pin[i], FASTSYS_SENSOR_RESET_LEVEL);
        }
    }
}

static void fastsys_after_init(void)
{
    int i = 0;

    for (i = 0; i < FASTSYS_SENSOR_DEV_NUM; i++) {
        if (fastsys_sensor_param.power_pin[i] >= 0) {
            gpio_direction_output(fastsys_sensor_param.power_pin[i], !FASTSYS_SENSOR_PWDN_LEVEL);
        }
        if (fastsys_sensor_param.reset_pin[i] >= 0) {
            gpio_direction_output(fastsys_sensor_param.reset_pin[i], !FASTSYS_SENSOR_RESET_LEVEL);
        }
    }
}

struct fastsys_ipi_mem_info {
    char magic[20];
#define IPI_RX              (0x1 << 0)
    unsigned int rx_status;

#define IPI_TX              (0x1 << 0)
    unsigned int tx_status;
    unsigned int state[4];

    unsigned int chan_zone_base_offset;
    unsigned int num_chans;
    unsigned int chan_size;
    unsigned int chan_data_size;

    unsigned int log_mem_base;
    unsigned int log_mem_size;
    unsigned int log_current_end;
};
struct fastsys_ipi_mem_info *fastsys_mem_info;
static int fastsys_log_current_index = 0;

static inline unsigned int log_size_align(unsigned int size)
{
#define align_size          8
    unsigned int _size =  (((size)+((align_size)-1))&(typeof(size))(~((align_size)-1)));

    if (!(_size % align_size))
        return _size + align_size;
    return size;
}

void fastsys_flush_log(void)
{
#if 1
    char *ipi_mem_magic = "anyka@fastsys";
    u64 line_len, len, current_time;
    char *current_buffer_base;

    if (strncmp(fastsys_mem_info->magic, ipi_mem_magic, strlen(ipi_mem_magic))) {
        printf("fastsys ipi no init\n");
        return;
    }
#define FASTSYS_LOG_BUFFER_SIZE      256

    while(fastsys_log_current_index != fastsys_mem_info->log_current_end) {
        current_buffer_base = (char *)((unsigned long)fastsys_mem_info->log_mem_base + fastsys_log_current_index);
        line_len = *((u64 *)current_buffer_base);
        if (line_len > FASTSYS_LOG_BUFFER_SIZE)
            len = FASTSYS_LOG_BUFFER_SIZE;
        else
            len = line_len;
        current_buffer_base +=  sizeof(u64);
        current_time = *((u64 *)current_buffer_base);
        current_buffer_base +=  sizeof(u64);
        fastsys_log_current_index += log_size_align(line_len + 2 * sizeof(u64));
        printf("[%8lldms] %s", current_time, current_buffer_base);
    }
#endif
}
EXPORT_SYMBOL(fastsys_flush_log)

#ifdef AK_FASTSYS_PMP
#include "asm/csr.h"
/**/
static int32_t pmp_pmpcfg0_get_regionx_state(uint8_t region_num, uint8_t *state)
{
    uint64_t pmpcfg0_csr = 0;

    if(state == NULL || region_num > 7)
        return -1;
    /* read pmpcfg0 register */
    pmpcfg0_csr = csr_read(pmpcfg0);
    *state = (pmpcfg0_csr >> (region_num * 8)) & 0xff;
    return 0;
}

/**/
static int32_t pmp_pmpcfg0_set_regionx_config(uint8_t region_num, uint8_t config)
{
    uint64_t pmpcfg0_csr = 0;

    if(region_num > 7)
        return -1;
    /* read pmpcfg0 register */
    pmpcfg0_csr = csr_read(pmpcfg0);
    /* check lock state */
    if((pmpcfg0_csr >> (region_num * 8)) & (0x1 << 7))
        return -1;
    /* update pmpcfg0 register access right */
    pmpcfg0_csr &= ~(0xffull << (region_num * 8));
    pmpcfg0_csr |= ((config & 0x1full) << (region_num * 8));
    /* write pmpcfg0 register */
    csr_write(pmpcfg0, pmpcfg0_csr);

    return 0;
}

/**/
static int32_t pmp_pmpcfg0_get_regionx_lock_state(uint8_t region_num, uint8_t *lock)
{
    uint8_t state = 0;

    if(lock == NULL)
        return -1;
    if(pmp_pmpcfg0_get_regionx_state(region_num, &state))
        return -1;
    *lock = ((state >> 7) & 0x1)? 1 : 0;
    return 0;
}

/**/
static int32_t pmp_pmpcfg0_set_regionx_try_lock(uint8_t region_num)
{
    uint64_t pmpcfg0_csr = 0;
    uint8_t lock = 0;

    if(region_num > 7)
        return -1;
    /* read pmpcfg0 register */
    pmpcfg0_csr = csr_read(pmpcfg0);
    /* check lock state */
    if((pmpcfg0_csr >> (region_num * 8)) & (0x1 << 7))
        return 0;
    /* try lock */
    pmpcfg0_csr |= (0x80ull << (region_num * 8));
    /* write pmpcfg0 register */
    csr_write(pmpcfg0, pmpcfg0_csr);

    /* check lock */
    pmp_pmpcfg0_get_regionx_lock_state(region_num, &lock);
    return lock? 0 : -1;
}

/**/
static int32_t pmp_region_get_pmpaddrx(uint8_t region_num,
    uint64_t *val)
{
    if(region_num > 7 || val == NULL)
        return -1;
    switch(region_num){
        case 0:
            *val = csr_read(pmpaddr0);
            break;
        case 1:
            *val = csr_read(pmpaddr1);
            break;
        case 2:
            *val = csr_read(pmpaddr2);
            break;
        case 3:
            *val = csr_read(pmpaddr3);
            break;
        case 4:
            *val = csr_read(pmpaddr4);
            break;
        case 5:
            *val = csr_read(pmpaddr5);
            break;
        case 6:
            *val = csr_read(pmpaddr6);
            break;
        case 7:
            *val = csr_read(pmpaddr7);
            break;
        default:
            return -1;
            break;
    }
    return 0;
}

/**/
static int32_t pmp_region_set_pmpaddrx(uint8_t region_num,
    uint64_t val)
{
     uint8_t lock = 0;

    if(region_num > 7)
        return -1;
    pmp_pmpcfg0_get_regionx_lock_state(region_num, &lock);
    if(lock)
        return -1;
    switch(region_num){
        case 0:
            csr_write(pmpaddr0, val);
            break;
        case 1:
            csr_write(pmpaddr1, val);
            break;
        case 2:
            csr_write(pmpaddr2, val);
            break;
        case 3:
            csr_write(pmpaddr3, val);
            break;
        case 4:
            csr_write(pmpaddr4, val);
            break;
        case 5:
            csr_write(pmpaddr5, val);
            break;
        case 6:
            csr_write(pmpaddr6, val);
            break;
        case 7:
            csr_write(pmpaddr7, val);
            break;
        default:
            return -1;
            break;
    }
    return 0;
}

/**/
#define pmp_get_tor_pmpaddrx_config(addr) \
    ((addr) >> 2)
/**/
#define pmp_get_na4_pmpaddrx_config(addr) \
    ((addr) >> 2)
/**/
#define pmp_get_napot_pmpaddrx_config(addr, size) \
    (((addr) >> 2) | (((size) >> 3) - 1))
/**/
#define pmp_pmpxcfg_rxw(r, x, w) \
    (((r) & 0x1) | (((w) & 0x1)  << 1) | (((x) & 0x1) << 2))
/* 0:disable, 1:tor, 2:na4, 3:napot */
#define pmp_pmpxcfg_adddress_match_mode(a) \
    (((a) & 0x3) << 3)

static void fastspl_mem_pmp_init(unsigned int base, unsigned int end)
{
    uint64_t pmpaddrx_csr;
    uint8_t pmpxcfg_csr;
    uint8_t region_num;

    csr_write(pmpcfg0, 0x0ull);
    /* res */
    region_num = 0;
    pmpxcfg_csr = pmp_pmpxcfg_rxw(0, 0, 0) | pmp_pmpxcfg_adddress_match_mode(2);
    pmpaddrx_csr = pmp_get_na4_pmpaddrx_config(base);
    pmp_region_set_pmpaddrx(region_num, pmpaddrx_csr);
    pmp_pmpcfg0_set_regionx_config(region_num, pmpxcfg_csr);

    /* <RTOSBIN> set rxw */
    region_num = 1;
    pmpxcfg_csr = pmp_pmpxcfg_rxw(0, 0, 0) | pmp_pmpxcfg_adddress_match_mode(1);
    pmpaddrx_csr = pmp_get_tor_pmpaddrx_config(end);
    pmp_region_set_pmpaddrx(region_num, pmpaddrx_csr);
    pmp_pmpcfg0_set_regionx_config(region_num, pmpxcfg_csr);

    pmp_pmpcfg0_set_regionx_try_lock(0);
    pmp_pmpcfg0_set_regionx_try_lock(1);
}
#endif

enum {
    ENV_MD5_INDEX,
    FASTSYS_PARAM_MD5_INDEX,
    FASTSYS_MD5_INDEX,
//    FASTSYS_ISPCFG_MD5_INDEX,
    SBI_MD5_INDEX,
    KERNEL_MD5_INDEX,
    INITFS_MD5_INDEX,
    DTB_MD5_INDEX,
    MAX_MD5_INDEX,
};
#define ENV_MD5SUM_SAVE_OFFSET          0xe00
static char *image_md5_results;

#if CONFIG_SPL_MD5

static unsigned char md5_char_to_hex(char c)
{
    if (c >= '0' && c <= '9') {
        return c - '0';
    } else if (c >= 'A' && c <= 'F') {
        return c - 'A' + 10;
    } else if (c >= 'a' && c <= 'f') {
        return c - 'a' + 10;
    } else {
        return 0;
    }
}

static unsigned char md5_two_chars_to_byte(char c1, char c2)
{
    return (md5_char_to_hex(c1) << 4) | md5_char_to_hex(c2);
}

static unsigned int md5_eight_chars_to_byte(char *str)
{
    return ((md5_char_to_hex(str[0]) << 28) |
            (md5_char_to_hex(str[1]) << 24) |
            (md5_char_to_hex(str[2]) << 20) |
            (md5_char_to_hex(str[3]) << 16) |
            (md5_char_to_hex(str[4]) << 12) |
            (md5_char_to_hex(str[5]) << 8) |
            (md5_char_to_hex(str[6]) << 4) |
            md5_char_to_hex(str[7]));
}

static void echck_part_md5sum(unsigned char *input, int md5_index)
{
    extern void md5(unsigned char *input, int len, unsigned char output[16]);
    int flag = 0, i;
    unsigned char md5sum_check[16];
    char md5sum[16];
    unsigned int len = 100;

    len = md5_eight_chars_to_byte(image_md5_results + md5_index * 40);
    md5(input, len, md5sum);

    for (int i = 0; i < 16; i++) {
        char *_md5sum_check = image_md5_results + md5_index * 40 + 8;
        md5sum_check[i] = md5_two_chars_to_byte(_md5sum_check[i * 2], _md5sum_check[i * 2 + 1]);
        if (md5sum[i] != md5sum_check[i]) {
            flag = 1;
        }
    }

    if (flag) {
        printf("echck_part_md5sum error\n");
        printf("md5_index %d addr 0x%08lx size %d md5: ", md5_index, (unsigned long)input, len);
        for (i = 0; i < 16; i++) {
            if (i == 15)
                printf("0x%02x", md5sum[i]);
            else
                printf("0x%02x, ", md5sum[i]);
        }
        printf("\n");

        printf("ms5sum check: ");
        for (i = 0; i < 16; i++) {
            if (i == 15)
                printf("0x%02x", md5sum_check[i]);
            else
                printf("0x%02x, ", md5sum_check[i]);
        }
        printf("\n");
        fastsys_flush_log();
    }
}

#else

static inline void echck_part_md5sum(unsigned char *input, int md5_index)
{

}

#endif

/*
 * The main entry for SPI booting. It's necessary that SDRAM is already
 * configured and available since this code loads the main U-Boot image
 * from SPI into SDRAM and starts it from there.
 */
static int spl_spi_load_image(struct spl_image_info *spl_image,
			      struct spl_boot_device *bootdev)
{
	int err = 0;
	struct spi_flash *flash;
	struct image_header *header;
	unsigned int bus = CONFIG_SF_DEFAULT_BUS;
	unsigned int cs = CONFIG_SF_DEFAULT_CS;
	// unsigned int speed = CONFIG_SF_DEFAULT_SPEED;
	// unsigned int mode = CONFIG_SF_DEFAULT_MODE;
	char env_buf[CONFIG_ENV_SIZE] = {0};
	char out_buf[1024] = {0};
    void *load_buf, *image_buf;
	//unsigned long load_addr = 0;
	unsigned long dtb_addr = 0;
	unsigned long image_flag = 0;
	unsigned long run_add = 0, run_len = 0;
    unsigned long fastsys_offset = 0, fastsys_len = 0;
	unsigned long part_num = 0;
    ulong load_end;
    uint magic;
	int	ret = 0;
    size_t realsize;
    u32 first_load_size;
    unsigned int fastsys_image_load_addr;
    unsigned int fastsys_param_load_addr;
    unsigned int fastsys_ispcfg_load_addr;

#ifdef CONFIG_SPL_DM_SPI_FLASH
	struct udevice *spi_dev, *dev;

	/*
	 * Load U-Boot image from SPI flash into RAM
	 * In DM mode: defaults speed and mode will be
	 * taken from DT when available
	 */
	uclass_get_device(UCLASS_SPI, 0, &spi_dev);
	device_probe(spi_dev);

	ret = spi_flash_probe_bus_cs(bus, cs, &dev);
	if (ret) {
		printf("Failed to initialize SPI flash at %u:%u\n", bus, cs);
		return ret;
	}

	flash = dev_get_uclass_priv(dev);

#else
	flash = spi_flash_probe(bus, cs,speed, mode);
#endif
	if (!flash) {
		puts("SPI probe failed.\n");
		return -ENODEV;
	}

	/* read env for partiton info */
	err = spi_flash_read(flash, CONFIG_ENV_OFFSET, CONFIG_ENV_SIZE, env_buf);
	if (err) {
		debug("%s: Failed to read from SPI flash (err=%d)\n",
		      __func__, err);
		return err;
	}

    image_md5_results = env_buf + ENV_MD5SUM_SAVE_OFFSET;
    echck_part_md5sum(env_buf, ENV_MD5_INDEX);

	memset(out_buf, 0, 1024);
	pare_str_form_env(env_buf, "dtb_addr=", out_buf);
	dtb_addr = simple_strtoul(&out_buf[9], NULL, 16);
	spl_image->arg = (void *)dtb_addr;
	memset(out_buf, 0, 1024);
	pare_str_form_env(env_buf, "mtdparts=mtdparts=", out_buf);
	part_num = spl_device_parse(&out_buf[9], flash->size);

	pare_str_form_env(env_buf, "a_uboot_flags=", out_buf);
	image_flag = simple_strtoul(&out_buf[14], NULL, 16);

#ifdef CONFIG_FAST_LAUNCH //cpio file for init ramfs
	pare_str_form_env(env_buf, "cpioaddr=", out_buf);
	unsigned long cpioaddr = simple_strtoul(&out_buf[9], NULL, 16); 
#endif
    fastsys_early_init();
#if 0//ndef CONFIG_CELESTIA_FASTSYS
    /* read fastsys header */
    if(get_mtdparts_by_partition_name (PART_FASTSYS_NAME, part_num, &fastsys_offset, &fastsys_len) == -1){
        puts("spinor_get_mtdparts FASTSYS failed.\n");
        return -EINVAL;
    }

    header = (struct image_header *)out_buf;
    if( (err = spi_flash_read(flash, fastsys_offset, 1024, out_buf)) ){
        printf("spi_flash_read FASTSYS header fail\r\n");
        return err;
    }

    magic = image_get_magic(header);
    if(magic == FDT_MAGIC){
        realsize = fdt_totalsize(header);
    }
    else if(magic == IH_MAGIC){
        realsize = image_get_data_size(header) + sizeof(image_header_t);
    }
    else{
        printf("fastsys not supported, magic=0x%x\n", magic);
    }

    fastsys_image_load_addr = image_get_load(header);
    first_load_size = 1024 - sizeof(struct image_header);
    memcpy((void *)(unsigned long)fastsys_image_load_addr, out_buf + sizeof(struct image_header), first_load_size);
    fastsys_param_load_addr = *(unsigned int *)((unsigned long)fastsys_image_load_addr + 16);
    fastsys_ispcfg_load_addr = *(unsigned int *)((unsigned long)fastsys_image_load_addr + 20);

    /* read fastsys param */
    if (get_mtdparts_by_partition_name (PART_PARAM_NAME, part_num, &run_add, &run_len) == -1){
        puts("spinor_get_mtdparts param failed.\n");
        return -EINVAL;
    }

    if ((err = spi_flash_read(flash, run_add, run_len, (void *)(unsigned long)fastsys_param_load_addr)) ){
        printf("spi_flash_read fastsys param data fail\r\n");
        return err;
    }

    echck_part_md5sum((unsigned char *)(unsigned long)fastsys_param_load_addr, FASTSYS_PARAM_MD5_INDEX);
    fastsys_early_init((char *)(unsigned long)fastsys_param_load_addr);
    if ((err = spi_flash_read(flash, fastsys_offset + 1024, realsize - first_load_size,
                        (void *)((unsigned long)fastsys_image_load_addr + first_load_size))) ){
        printf("spi_flash_read kernel data fail\r\n");
        return err;
    }
    echck_part_md5sum((unsigned char *)(unsigned long)fastsys_image_load_addr, FASTSYS_MD5_INDEX);

    /* read ispcfg */
    if(get_mtdparts_by_partition_name (PART_ISPCONF_NAME, part_num, &run_add, &run_len) == -1){
        puts("spinor_get_mtdparts ispconf failed.\n");
        return -EINVAL;
    }

    if( (err = spi_flash_read(flash, run_add, run_len, (void *)(unsigned long)fastsys_ispcfg_load_addr)) ){
        printf("spi_flash_read fastsys ispconf data fail\r\n");
        return err;
    }

    // echck_part_md5sum(fastsys_ispcfg_load_addr, run_len, FASTSYS_ISPCFG_MD5_INDEX);
    fastsys_after_init();
    fastsys_mem_info = (struct fastsys_ipi_mem_info *)(unsigned long)(*(unsigned int *)((unsigned long)fastsys_image_load_addr + 24));
#ifdef AK_FASTSYS_PMP
    fastspl_mem_pmp_init(fastsys_image_load_addr, fastsys_image_load_addr + 0x300000);
#endif
    /*start second hart. from ROMCODE jump to fastsys*/
    (*(volatile unsigned long*)(0xd28027fc)) = fastsys_image_load_addr;
    (*(volatile unsigned long*)(0x2000004)) = 1;
#endif
    /*read OPENSBI*/
    if(get_mtdparts_by_partition_name (PART_SBI_NAME, part_num, &run_add, &run_len) == -1){
        puts("spinor_get_mtdparts OPENSBI failed.\n");
        return -EINVAL;
    }

    header = (struct image_header *)out_buf;
    if(spi_flash_read(flash, run_add, sizeof(image_header_t), out_buf)){
        printf("spi_flash_read OPENSBI headers fail\r\n");
        return err;
    }

    err = spl_parse_image_header(spl_image, bootdev, header);
    if (err){
        printf("spl_parse_image_header fail\r\n");
        return err;
    }

    magic = image_get_magic(header);
    if(magic == FDT_MAGIC){
        realsize = fdt_totalsize(header);
    }
    else if(magic == IH_MAGIC){
        realsize = image_get_data_size(header) + sizeof(image_header_t);
    }
    else{
        printf("OPENSBI not supported, magic=0x%x\n", magic);
    }

    err = spi_flash_read(flash, run_add+64, realsize, (void *)spl_image->entry_point);
    if (err) {
        printf("%s: Failed to read opensbi image (err=%d)\n",
                __func__, err);
        return err;
    }

    echck_part_md5sum((unsigned char *)(unsigned long)spl_image->entry_point, SBI_MD5_INDEX);

    /*read KERNEL*/
    if(get_mtdparts_by_partition_name (PART_BIOS_NAME, part_num, &run_add, &run_len) == -1){
        puts("spinor_get_mtdparts KERNEL failed.\n");
        return -EINVAL;
    }

    header = (struct image_header *)out_buf;
    if( (err = spi_flash_read(flash, run_add, sizeof(image_header_t), out_buf)) ){
        printf("spi_flash_read KERNEL header fail\r\n");
        return err;
    }

    magic = image_get_magic(header);
    if(magic == FDT_MAGIC){
        realsize = fdt_totalsize(header);
    }
    else if(magic == IH_MAGIC){
        realsize = image_get_data_size(header) + sizeof(image_header_t);
    }
    else{
        printf("KERNEL not supported, magic=0x%x\n", magic);
    }

    fastsys_after_init();
    // printf("read kernel:run_add:0x%lx, realsize:0x%lx\r\n", run_add, realsize);
    if( (err = spi_flash_read(flash, run_add, realsize, (u_char *)(PART_KERNEL_ADDR-64))) ){
        printf("spi_flash_read kernel data fail\r\n");
        return err;
    }

    echck_part_md5sum((unsigned char *)(unsigned long)PART_KERNEL_ADDR - 64, KERNEL_MD5_INDEX);

    // printf("ulz4fn kerne image\n");
	load_end = 4 * realsize;
	load_buf = map_sysmem(PART_KERNEL_LOAD_ADDR, load_end);
	image_buf = map_sysmem(PART_KERNEL_ADDR, realsize);
    err = ulz4fn(image_buf, realsize, load_buf, &load_end);
	if(err) {
		printf("ulz4fn err[%d]\n", err);
        fastsys_flush_log();
    }
#if 0//ndef CONFIG_CELESTIA_FASTSYS
    /*read INITFS*/
    // printf("read INITFS image\n");
    if(get_mtdparts_by_partition_name (PART_INITFS_NAME, part_num, &run_add, &run_len) == -1){
        puts("spinor_get_mtdparts INITFS failed, and read kernel.\n");
        return -EINVAL;
    }

    header = (struct image_header *)out_buf;
    if( (err = spi_flash_read(flash, run_add, sizeof(image_header_t), out_buf)) ){
        printf("nand_read_data INITFS data fail\r\n");
        return err;
    }

    magic = image_get_magic(header);
    if(magic == FDT_MAGIC){
        realsize = fdt_totalsize(header);
    }
    else if(magic == IH_MAGIC){
        realsize = image_get_data_size(header) + sizeof(image_header_t);
    }
    else{
        printf("INITFS not supported, magic=0x%x\n", magic);
    }

    // printf("read initfs:run_add:0x%lx, realsize:0x%lx\r\n", run_add, realsize);
    if( (err = spi_flash_read(flash, run_add, realsize, (u_char *)(PART_INITFS_ADDR-64))) ){
        printf("nand_read_data opensbi data fail\r\n");
        return err;
    }

    echck_part_md5sum((unsigned char *)(unsigned long)PART_INITFS_ADDR - 64, INITFS_MD5_INDEX);
#endif
    /*read DTB*/
    // printf("read DTB image\n");
    if(get_mtdparts_by_partition_name (PART_DTB_NAME, part_num, &run_add, &run_len) == -1){
        puts("spinor_get_mtdparts UBOOT failed, and read kernel.\n");
        return -EINVAL;
    }

    header = (struct image_header *)out_buf;
    if( (err = spi_flash_read(flash, run_add, sizeof(image_header_t), out_buf)) ){
        printf("nand_read_data opensbi data fail\r\n");
        return err;
    }

    magic = image_get_magic(header);
    if(magic == FDT_MAGIC){
        realsize = fdt_totalsize(header);
    }
    else if(magic == IH_MAGIC){
        realsize = image_get_data_size(header) + sizeof(image_header_t);
    }
    else{
        printf("DTB not supported, magic=0x%x\n", magic);
    }

    //printf("read dtb:run_add:0x%lx, run_len:0x%x\r\n", run_add, run_len);
    if( spi_flash_read(flash, run_add, realsize, (void *)dtb_addr)){
        printf("nand_read_data dtb data fail\r\n");
        return err;
    }
    echck_part_md5sum((unsigned char *)(unsigned long)dtb_addr, DTB_MD5_INDEX);

    device_remove(spi_dev, DM_REMOVE_NORMAL);
    // spl_fdt_chosen((void *)dtb_addr, 1, env_buf);

	return err;
}
/* Use priorty 1 so that boards can override this */
SPL_LOAD_IMAGE_METHOD("SPI", 1, BOOT_DEVICE_SPI, spl_spi_load_image);
