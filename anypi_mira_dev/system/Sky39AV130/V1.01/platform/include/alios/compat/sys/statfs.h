/* SPDX-License-Identifier: Apache-2.0 */
#ifndef CELESTIA_COMPAT_SYS_STATFS_H
#define CELESTIA_COMPAT_SYS_STATFS_H

#ifndef ST_RDONLY
#define ST_RDONLY 1
#endif

#if !defined(KERNEL_AOS)
#include_next <sys/statfs.h>
#ifndef CELESTIA_COMPAT_STATFS_HAS_F_FLAGS
#define CELESTIA_COMPAT_STATFS_HAS_F_FLAGS 1
#endif
#else
/* Do not #include_next SDK sys/statfs.h: it pulls toolchain dirent.h, which
 * defines struct statfs without f_flags and collides with a compat struct. */
#include <dirent.h>

int statfs(const char *path, struct statfs *buf);

#define CELESTIA_COMPAT_STATFS_HAS_F_FLAGS 0
#endif

#endif
