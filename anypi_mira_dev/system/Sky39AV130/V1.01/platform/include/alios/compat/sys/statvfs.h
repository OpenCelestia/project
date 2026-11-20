/* SPDX-License-Identifier: Apache-2.0 */
#ifndef CELESTIA_COMPAT_SYS_STATVFS_H
#define CELESTIA_COMPAT_SYS_STATVFS_H

/* Aos SDK provides the struct and statvfs(); do not replace it with a stub. */
#include_next <sys/statvfs.h>

#ifndef ST_RDONLY
#define ST_RDONLY 1
#endif

#endif
