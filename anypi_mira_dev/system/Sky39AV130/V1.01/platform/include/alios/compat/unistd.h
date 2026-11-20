/* SPDX-License-Identifier: Apache-2.0 */
#ifndef CELESTIA_COMPAT_UNISTD_H
#define CELESTIA_COMPAT_UNISTD_H

#include_next <unistd.h>

#ifndef F_OK
#define F_OK 0
#define X_OK 1
#define W_OK 2
#define R_OK 4
#endif

#endif
