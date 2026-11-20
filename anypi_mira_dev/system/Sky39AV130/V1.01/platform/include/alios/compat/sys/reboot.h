/* SPDX-License-Identifier: Apache-2.0 */
#ifndef CELESTIA_COMPAT_SYS_REBOOT_H
#define CELESTIA_COMPAT_SYS_REBOOT_H

/* Linux reboot(2) constants for watchdog.c to compile on Aos. No uspace
 * reboot path exists; nothing references the watchdog symbols on Mira, so
 * the object is never pulled into the link. */

#define RB_AUTOBOOT     0x01234567
#define RB_HALT_SYSTEM  0xcdef0123
#define RB_ENABLE_CAD   0x89abcdef
#define RB_DISABLE_CAD  0
#define RB_POWER_OFF    0x4321fedc

int reboot(int cmd);

#endif
