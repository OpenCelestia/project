/* SPDX-License-Identifier: Apache-2.0 */
#ifndef CELESTIA_COMPAT_PTHREAD_H
#define CELESTIA_COMPAT_PTHREAD_H

#include_next <pthread.h>

#if defined(KERNEL_AOS) && !defined(PTHREAD_COND_INITIALIZER)
#define PTHREAD_COND_INITIALIZER {0}
#endif

#endif
