// SPDX-License-Identifier: Apache-2.0
/*
 * Aos lwIP uspace exposes getifaddrs/freeifaddrs stubs that log "NOT supported".
 * Nebula discovery needs real IPv4 per-interface addresses (wlan0/eth0).
 */

#include <ifaddrs.h>

#include <arpa/inet.h>
#include <errno.h>
#include <net/if.h>
#include <netinet/in.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <unistd.h>

static struct ifaddrs *aos_ifaddrs_append(struct ifaddrs *head, struct ifaddrs *node)
{
    struct ifaddrs *p;

    if (!head)
        return node;
    for (p = head; p->ifa_next; p = p->ifa_next)
        ;
    p->ifa_next = node;
    return head;
}

static void aos_ifaddrs_free_one(struct ifaddrs *ifa)
{
    if (!ifa)
        return;
    free(ifa->ifa_name);
    free(ifa->ifa_addr);
    free(ifa->ifa_netmask);
    free(ifa->ifa_broadaddr);
    free(ifa->ifa_dstaddr);
    free(ifa);
}

static int aos_ifaddrs_add(int fd, const char *ifname, struct ifaddrs **head)
{
    struct ifreq ifr;
    struct ifaddrs *ifa;
    struct sockaddr_in *sin;
    struct sockaddr_in *addr;
    struct sockaddr_in *mask;

    if (!ifname || !ifname[0])
        return -1;

    memset(&ifr, 0, sizeof(ifr));
    strncpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name) - 1);
    if (ioctl(fd, SIOCGIFFLAGS, &ifr) != 0)
        return -1;
    if ((ifr.ifr_flags & IFF_UP) == 0)
        return -1;

    memset(&ifr, 0, sizeof(ifr));
    strncpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name) - 1);
    if (ioctl(fd, SIOCGIFADDR, &ifr) != 0)
        return -1;

    sin = (struct sockaddr_in *)&ifr.ifr_addr;
    if (sin->sin_family != AF_INET)
        return -1;
    if (sin->sin_addr.s_addr == 0 || sin->sin_addr.s_addr == htonl(INADDR_LOOPBACK))
        return -1;

    ifa = calloc(1, sizeof(*ifa));
    addr = malloc(sizeof(struct sockaddr_in));
    mask = malloc(sizeof(struct sockaddr_in));
    if (!ifa || !addr || !mask) {
        free(ifa);
        free(addr);
        free(mask);
        errno = ENOMEM;
        return -1;
    }

    ifa->ifa_name = strdup(ifname);
    if (!ifa->ifa_name) {
        aos_ifaddrs_free_one(ifa);
        errno = ENOMEM;
        return -1;
    }

    memcpy(addr, sin, sizeof(*addr));
    ifa->ifa_addr = (struct sockaddr *)addr;

    memset(&ifr, 0, sizeof(ifr));
    strncpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name) - 1);
    if (ioctl(fd, SIOCGIFNETMASK, &ifr) == 0) {
        memcpy(mask, &ifr.ifr_netmask, sizeof(*mask));
        ifa->ifa_netmask = (struct sockaddr *)mask;
    } else {
        free(mask);
    }

    memset(&ifr, 0, sizeof(ifr));
    strncpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name) - 1);
    if (ioctl(fd, SIOCGIFFLAGS, &ifr) == 0)
        ifa->ifa_flags = (unsigned int)ifr.ifr_flags;

    *head = aos_ifaddrs_append(*head, ifa);
    return 0;
}

static int aos_ifaddrs_from_ifconf(int fd, struct ifaddrs **head)
{
    char buf[2048];
    struct ifconf ifc;
    char *cp;
    int n;

    memset(&ifc, 0, sizeof(ifc));
    ifc.ifc_len = sizeof(buf);
    ifc.ifc_buf = buf;
    if (ioctl(fd, SIOCGIFCONF, &ifc) != 0)
        return -1;

    n = (int)sizeof(struct ifreq);
    for (cp = buf; cp + n <= buf + ifc.ifc_len; cp += n) {
        struct ifreq *ifr = (struct ifreq *)cp;

        (void)aos_ifaddrs_add(fd, ifr->ifr_name, head);
    }
    return 0;
}

int __wrap_getifaddrs(struct ifaddrs **ifap)
{
    static const char *fallback[] = { "wlan0", "eth0", "eth1", "wlan1", "net0", NULL };
    int fd;
    struct ifaddrs *head = NULL;
    size_t i;

    if (!ifap) {
        errno = EINVAL;
        return -1;
    }
    *ifap = NULL;

    fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (fd < 0)
        return -1;

    if (aos_ifaddrs_from_ifconf(fd, &head) != 0 || head == NULL) {
        for (i = 0; fallback[i]; i++)
            (void)aos_ifaddrs_add(fd, fallback[i], &head);
    }

    close(fd);

    if (!head) {
        errno = ENXIO;
        return -1;
    }

    *ifap = head;
    return 0;
}

void __wrap_freeifaddrs(struct ifaddrs *ifa)
{
    while (ifa) {
        struct ifaddrs *next = ifa->ifa_next;

        aos_ifaddrs_free_one(ifa);
        ifa = next;
    }
}
