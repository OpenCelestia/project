/* SPDX-License-Identifier: Apache-2.0 */
#ifndef CELESTIA_COMPAT_SYS_MOUNT_H
#define CELESTIA_COMPAT_SYS_MOUNT_H

#include_next <sys/mount.h>

#ifndef MS_RDONLY
#define MS_RDONLY 1
#endif
#ifndef MS_NOATIME
#define MS_NOATIME 1024
#endif
#ifndef MS_NODIRATIME
#define MS_NODIRATIME 2048
#endif
#ifndef MNT_FORCE
#define MNT_FORCE 1
#endif
#ifndef MNT_DETACH
#define MNT_DETACH 2
#endif

#endif
