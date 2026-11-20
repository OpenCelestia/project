# platform/src/aos — POSIX implementation additions for Sky39AV130 V1.01

Source files that provide POSIX symbols missing from (or stubbed in) the
SDK's closed-source prebuilt libs (`platform/lib/alios/usyscall.a`,
`uspace_posix.a`, ...). Compiled by the product Makefile with a wildcard
into `libaos_posix.a`, linked inside `--start-group` before the SDK
archives. Dropping a new .c here is enough; no Makefile change needed.

## Rules

1. Symbol missing from every SDK archive? Define it directly under its
   standard name (dlopen table, realpath, ftruncate, string_strncpy).
   Check first with `nm platform/lib/alios/*.a`.
2. SDK defines the symbol as a stub (lwip_usyscall.o getifaddrs/freeifaddrs/
   gai_strerror)? Name the real implementation `__wrap_<name>` and add
   `-Wl,--wrap=<name>` to USER_LINK_FLAGS in the project Makefile. A same-name
   strong definition would collide with lwip_usyscall.o at link time.
3. Declarations go into the matching header under
   `platform/include/alios/compat/` (see the README there).

## Current files

- aos_dl.c          static dlopen/dlsym table (no SDK symbol)
- aos_ifaddrs.c     __wrap_getifaddrs/freeifaddrs (SDK stubs replaced)
- aos_netdb.c       __wrap_gai_strerror (SDK printf stub replaced)
- aos_compat_posix.c realpath, ftruncate, __sync_synchronize,
                    string_strncpy (no SDK symbols; __sync_synchronize also
                    exists in usyscall.a -- if a future link reports a
                    duplicate, convert it to the __wrap pattern too)

Symbol-to-archive mapping and maintenance rules:
docs/design/mira/anypi_mira_rtos_aos_review.md §3.
