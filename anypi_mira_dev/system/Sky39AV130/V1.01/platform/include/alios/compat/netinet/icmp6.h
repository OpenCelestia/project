/* SPDX-License-Identifier: Apache-2.0 */
#ifndef CELESTIA_COMPAT_NETINET_ICMP6_H
#define CELESTIA_COMPAT_NETINET_ICMP6_H

#if defined(KERNEL_AOS)

#include <stdint.h>

struct icmp6_hdr {
    uint8_t icmp6_type;
    uint8_t icmp6_code;
    uint16_t icmp6_cksum;
    union {
        uint32_t icmp6_un_data32[4];
    } icmp6_dataun;
};

#define ICMP6_ECHO_REQUEST 128
#define ICMP6_ECHO_REPLY   129

#else
#include_next <netinet/icmp6.h>
#endif

#endif
