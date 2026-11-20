/* SPDX-License-Identifier: Apache-2.0 */
#ifndef CELESTIA_COMPAT_IFADDRS_H
#define CELESTIA_COMPAT_IFADDRS_H

#if !defined(KERNEL_AOS)
#include_next <ifaddrs.h>
#else
#include <sys/socket.h>

/* Implemented in system/core/aos/aos_ifaddrs.c (SDK stubs are no-ops). */

/* SDK net/if.h defines ifa_broadaddr/ifa_dstaddr as struct ifaddr field macros. */
#undef ifa_broadaddr
#undef ifa_dstaddr

struct ifaddrs {
    struct ifaddrs *ifa_next;
    char *ifa_name;
    unsigned int ifa_flags;
    struct sockaddr *ifa_addr;
    struct sockaddr *ifa_netmask;
    struct sockaddr *ifa_broadaddr;
    struct sockaddr *ifa_dstaddr;
    void *ifa_data;
};

int getifaddrs(struct ifaddrs **ifap);
void freeifaddrs(struct ifaddrs *ifa);

#undef ifa_broadaddr
#undef ifa_dstaddr

#endif

#endif
