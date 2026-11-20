// SPDX-License-Identifier: Apache-2.0
/* SDK lwip_usyscall.o defines gai_strerror as a printf stub. The real
 * implementation is linked as __wrap_gai_strerror via -Wl,--wrap=gai_strerror
 * (see project Makefile), same pattern as __wrap_getifaddrs. */

#include <netdb.h>
#include <stdio.h>

const char *__wrap_gai_strerror(int errcode)
{
    switch (errcode) {
    case 0:
        return "Success";
    case EAI_NONAME:
        return "Name or service not known";
    case EAI_AGAIN:
        return "Temporary failure in name resolution";
    case EAI_FAIL:
        return "Non-recoverable failure in name resolution";
    default:
        break;
    }

    static char msg[48];

    snprintf(msg, sizeof(msg), "getaddrinfo error %d", errcode);
    return msg;
}
