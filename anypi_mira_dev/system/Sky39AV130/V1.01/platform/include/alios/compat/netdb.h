/* SPDX-License-Identifier: Apache-2.0 */
#ifndef CELESTIA_COMPAT_NETDB_H
#define CELESTIA_COMPAT_NETDB_H

#if !defined(KERNEL_AOS)
#include_next <netdb.h>
#else
#include_next <netdb.h>

#ifdef __cplusplus
extern "C" {
#endif

const char *gai_strerror(int errcode);

#ifndef EAI_NONAME
#define EAI_NONAME 4
#endif
#ifndef EAI_AGAIN
#define EAI_AGAIN 2
#endif
#ifndef EAI_FAIL
#define EAI_FAIL 3
#endif

#ifdef __cplusplus
}
#endif

#endif

#endif
