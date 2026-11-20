/* SPDX-License-Identifier: Apache-2.0 */
#ifndef CELESTIA_COMPAT_ASM_TYPES_H
#define CELESTIA_COMPAT_ASM_TYPES_H

#if defined(KERNEL_AOS)
#include <stdint.h>
typedef uint8_t __u8;
typedef uint16_t __u16;
typedef uint32_t __u32;
typedef uint64_t __u64;
#else
#include_next <asm/types.h>
#endif

#endif
