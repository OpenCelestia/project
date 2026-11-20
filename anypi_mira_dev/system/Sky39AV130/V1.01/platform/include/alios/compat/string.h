/* SPDX-License-Identifier: Apache-2.0 */
#ifndef CELESTIA_COMPAT_STRING_H
#define CELESTIA_COMPAT_STRING_H

#include_next <string.h>

#if defined(KERNEL_AOS)
/* Bounded copy that always NUL-terminates; implemented in platform/src/aos.
 * Keep the remap scope minimal: audit callers before removing. */
char *string_strncpy(char *dst, const char *src, size_t n);
#undef strncpy
#define strncpy(dst, src, n) string_strncpy((dst), (src), (n))
#endif

#endif
