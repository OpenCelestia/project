/* Aos dlopen/dlsym stubs for statically linked ipc_cam (settings.json so_path). */
#include <dlfcn.h>
#include <signal.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

extern int module_init(const char *config_path);
extern int module_start(void);

static const char k_ipc_cam_so[] = "libipc_cam_app.so";
static char s_dlerror[128];
static int s_ipc_open;

static int path_is_ipc_cam(const char *filename)
{
    size_t flen;
    size_t slen;

    if (filename == NULL || filename[0] == '\0')
        return 0;
    flen = strlen(filename);
    slen = sizeof(k_ipc_cam_so) - 1;
    if (flen < slen)
        return 0;
    return strcmp(filename + (flen - slen), k_ipc_cam_so) == 0;
}

void *dlopen(const char *filename, int flags)
{
    (void)flags;
    s_dlerror[0] = '\0';
    if (!path_is_ipc_cam(filename)) {
        snprintf(s_dlerror, sizeof(s_dlerror), "dlopen: no static module for %s",
                 filename ? filename : "(null)");
        return NULL;
    }
    s_ipc_open = 1;
    return (void *)(intptr_t)1;
}

void *dlsym(void *handle, const char *symbol)
{
    s_dlerror[0] = '\0';
    if (handle == NULL || !s_ipc_open || symbol == NULL) {
        snprintf(s_dlerror, sizeof(s_dlerror), "dlsym: bad handle");
        return NULL;
    }
    if (strcmp(symbol, "module_init") == 0)
        return (void *)(uintptr_t)module_init;
    if (strcmp(symbol, "module_start") == 0)
        return (void *)(uintptr_t)module_start;
    snprintf(s_dlerror, sizeof(s_dlerror), "dlsym: %s not in ipc_cam", symbol);
    return NULL;
}

int dlclose(void *handle)
{
    (void)handle;
    s_ipc_open = 0;
    s_dlerror[0] = '\0';
    return 0;
}

char *dlerror(void)
{
    if (s_dlerror[0] == '\0')
        return NULL;
    return s_dlerror;
}

int dladdr(const void *addr, Dl_info *info)
{
    (void)addr;
    if (info)
        memset(info, 0, sizeof(*info));
    return 0;
}

__attribute__((weak)) int sigaction(int signum, const struct sigaction *act,
                                  struct sigaction *oldact)
{
    (void)signum;
    (void)act;
    (void)oldact;
    return 0;
}

__attribute__((weak)) void app_entry(void)
{
    extern int main(int argc, char **argv);
    char *argv[] = { "main", NULL };

    (void)main(1, argv);
}
