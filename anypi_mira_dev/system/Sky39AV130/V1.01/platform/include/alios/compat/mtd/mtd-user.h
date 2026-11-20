/* SPDX-License-Identifier: Apache-2.0 */
#ifndef CELESTIA_COMPAT_MTD_USER_H
#define CELESTIA_COMPAT_MTD_USER_H

#if !defined(KERNEL_AOS)
#include_next <mtd/mtd-user.h>
#else
/* Linux MTD ioctl ABI so framework/storage/flash keeps one source file.
 * Aos has no /dev/mtd; the same ioctls fail at runtime. */
#include <stdint.h>
#include <sys/types.h>

/* Aos newlib provides off_t, not the Linux MTD loff_t. */
#ifndef __loff_t_defined
typedef int64_t loff_t;
#define __loff_t_defined
#endif

struct mtd_info_user {
    uint8_t type;
    uint32_t flags;
    uint32_t size;
    uint32_t erasesize;
    uint32_t writesize;
    uint32_t oobsize;
    uint64_t padding;
};

struct erase_info_user {
    uint32_t start;
    uint32_t length;
};

typedef struct erase_info_user erase_info_t;

struct mtd_write_req {
    uint64_t start;
    uint64_t len;
    uint64_t ooblen;
    uint64_t usr_data;
    uint64_t usr_oob;
    uint8_t mode;
    uint8_t padding[7];
};

#ifndef MTD_NANDFLASH
#define MTD_NANDFLASH 4
#endif

#ifndef _IOC
#define _IOC(dir, type, nr, size) \
    (((dir) << 30) | (((size) & 0x3fff) << 16) | ((type) << 8) | (nr))
#define _IOW(type, nr, size)  _IOC(1, (type), (nr), sizeof(size))
#define _IOR(type, nr, size)  _IOC(2, (type), (nr), sizeof(size))
#define _IOWR(type, nr, size) _IOC(3, (type), (nr), sizeof(size))
#endif

#ifndef MEMGETINFO
#define MEMGETINFO      _IOR('M', 1, struct mtd_info_user)
#endif
#ifndef MEMERASE
#define MEMERASE        _IOW('M', 2, struct erase_info_user)
#endif
#ifndef MEMGETBADBLOCK
#define MEMGETBADBLOCK  _IOW('M', 11, loff_t)
#endif
#ifndef MEMWRITE
#define MEMWRITE        _IOWR('M', 24, struct mtd_write_req)
#endif
#endif

#endif
