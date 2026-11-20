// SPDX-License-Identifier: Apache-2.0
/* Minimal POSIX/gcc helpers for Aos user link. */

#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif

#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#if defined(__arm__) || defined(__ARM_EABI__)
ssize_t write(int fd, const void *buf, size_t count);
off_t lseek(int fd, off_t offset, int whence);
#endif

char *realpath(const char *path, char *resolved_path)
{
    if (!path)
        return NULL;
    if (resolved_path) {
        strncpy(resolved_path, path, PATH_MAX - 1);
        resolved_path[PATH_MAX - 1] = '\0';
        return resolved_path;
    }
    static char s_buf[PATH_MAX];

    strncpy(s_buf, path, sizeof(s_buf) - 1);
    s_buf[sizeof(s_buf) - 1] = '\0';
    return s_buf;
}

void __sync_synchronize(void)
{
    __asm__ __volatile__("" ::: "memory");
}

char *string_strncpy(char *dst, const char *src, size_t n)
{
    if (!dst || n == 0)
        return dst;
    snprintf(dst, n, "%s", src ? src : "");
    return dst;
}

int ftruncate(int fd, off_t length)
{
    struct stat st;
    off_t saved;
    char zero = 0;

    if (fd < 0 || length < 0) {
        errno = EINVAL;
        return -1;
    }
    if (fstat(fd, &st) != 0)
        return -1;
    saved = lseek(fd, 0, SEEK_CUR);
    if ((off_t)st.st_size == length)
        return 0;
    if ((off_t)st.st_size < length) {
        if (length == 0)
            return 0;
        if (lseek(fd, length - 1, SEEK_SET) < 0)
            return -1;
        if (write(fd, &zero, 1) != 1)
            return -1;
        if (saved >= 0)
            (void)lseek(fd, saved, SEEK_SET);
        return 0;
    }
    errno = EOPNOTSUPP; /* Aos: no fd truncate; shrink unsupported */
    if (saved >= 0)
        (void)lseek(fd, saved, SEEK_SET);
    return -1;
}
