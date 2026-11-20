# alios/compat — POSIX header additions for Sky39AV130 V1.01

Header shims that fill POSIX gaps of the Sky39AV130 V1.01 SDK (closed-source
prebuilt libs under `platform/lib/alios/`) and the arm-alios-eabi toolchain,
so application/framework keep their original `#include <...>` untouched.

Included as the FIRST `-I` (project `config.mk` + overlay `rules.mk`); the
`#include_next` chain is: this dir -> SDK `alios/external/` -> toolchain libc.

## Rules

1. Header exists in SDK `alios/external/` with a working implementation?
   Do NOT add a shim here; use the SDK header directly (e.g. sys/prctl.h,
   sys/ioctl.h, sys/socket.h).
2. SDK implementation exists but the header lacks declarations/macros?
   Add a shim named after the standard header, `#include_next` the original,
   then add only what is missing (e.g. sys/mount.h MS_* macros, netdb.h
   gai_strerror declaration).
3. SDK has no such header at all? Add a self-contained header, no
   include_next (e.g. dlfcn.h, ifaddrs.h, sys/reboot.h).
4. No behavioral rewrites of standard functions from a header. The only
   exception is string.h's strncpy remap, kept until callers are audited.

Implementations live in `platform/src/aos/` (see the README there for the
__wrap rule). Symbol-to-archive mapping and maintenance rules:
docs/design/mira/anypi_mira_rtos_aos_review.md §3.

## SDK upgrade (e.g. V1.01 -> V1.02)

Move this dir and `platform/src/aos/` into the new overlay only after
re-checking each file against the new SDK/toolchain: headers the new SDK
ships natively must be deleted from here (shims shadow the originals),
stub replacements re-verified by disassembly. The mapping table in the
review doc §3 is the checklist.
