#!/bin/bash
# Apply RHINO uspace header fixes to staged + out/ kernel trees (incremental builds).
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")" && pwd)
while test ! -f "$REPO_ROOT/build.sh" && test "$REPO_ROOT" != / ; do
    REPO_ROOT=$(dirname "$REPO_ROOT")
done
# out/ subdir follows the project directory name (rename-safe).
PRODUCT_DIR_NAME=$(basename "$(cd "$(dirname "$0")" && pwd)")

patch_udc_entry_task_name() {
    local udc=$1
    test -f "$udc" || return 0
    grep -q 'RHINO_CONFIG_APP_ENTRY_TASK_NAME' "$udc" && return 0
    python3 - "$udc" <<'PY'
import sys
path = sys.argv[1]
with open(path, encoding="utf-8", errors="replace") as f:
    text = f.read().replace("\r\n", "\n").replace("\r", "\n")
block = (
    "#ifndef RHINO_CONFIG_APP_ENTRY_TASK_NAME\n"
    "#define RHINO_CONFIG_APP_ENTRY_TASK_NAME RHINO_CONFIG_APP_NAME\n"
    "#endif\n"
)
anchor = '#ifndef RHINO_CONFIG_APP_NAME\n#define RHINO_CONFIG_APP_NAME "aos_app"\n#endif'
if anchor not in text:
    sys.exit(0)
text = text.replace(anchor, anchor + "\n\n" + block, 1)
with open(path, "w", encoding="utf-8", newline="\n") as f:
    f.write(text)
PY
}

# 64KB aos_app user stack: RHINO_CONFIG_APP_ENTRY_TASK_USTACK_SIZE * sizeof(cpu_stack_t)
patch_udc_aos_app_ustack_64k() {
    local udc=$1
    test -f "$udc" || return 0
    grep -q 'MIRA: aos_app ustack 64KB' "$udc" && return 0
    python3 - "$udc" <<'PY'
import re
import sys

path = sys.argv[1]
marker = "MIRA: aos_app ustack 64KB"
with open(path, encoding="utf-8", errors="replace") as f:
    text = f.read().replace("\r\n", "\n").replace("\r", "\n")

if marker in text:
    sys.exit(0)

old = "#define RHINO_CONFIG_APP_ENTRY_TASK_USTACK_SIZE 1024"
new = "#define RHINO_CONFIG_APP_ENTRY_TASK_USTACK_SIZE 8192  /* MIRA: aos_app ustack 64KB (8192*8) */"
if old in text:
    text = text.replace(old, new, 1)
else:
    text, n = re.subn(
        r"(#define\s+RHINO_CONFIG_APP_ENTRY_TASK_USTACK_SIZE\s+)\d+",
        r"\g<1>8192  /* MIRA: aos_app ustack 64KB (8192*8) */",
        text,
        count=1,
    )
    if n == 0:
        sys.exit(0)

with open(path, "w", encoding="utf-8", newline="\n") as f:
    f.write(text)
PY
}

patch_udc() {
    patch_udc_entry_task_name "$1"
    patch_udc_aos_app_ustack_64k "$1"
}

patch_umd() {
    local umd=$1
    test -f "$umd" || return 0
    grep -q 'u_default_config.h' "$umd" && return 0
    sed -i '/#include "k_api.h"/a #include "u_default_config.h"' "$umd"
}

while IFS= read -r udc; do
    patch_udc "$udc"
    uspace=$(dirname "$(dirname "$udc")")
    patch_umd "$uspace/src/umm/u_mm_debug.c"
done < <(find "$REPO_ROOT/out/$PRODUCT_DIR_NAME/build" -path '*/uspace/include/u_default_config.h' 2>/dev/null)

STAGED="$REPO_ROOT/out/$PRODUCT_DIR_NAME/build/system/Sky39AV130/V1.01/os/kernel"
if test -f "$STAGED/kernel/core/mk/uspace/include/u_default_config.h"; then
    patch_udc "$STAGED/kernel/core/mk/uspace/include/u_default_config.h"
    patch_umd "$STAGED/kernel/core/mk/uspace/src/umm/u_mm_debug.c"
fi
for kroot in "$STAGED" $(find "$REPO_ROOT/out/$PRODUCT_DIR_NAME/build" -maxdepth 1 -type d -name 'alios_kernel@*' 2>/dev/null); do
    test -d "$kroot/os/kernel" && kroot="$kroot/os/kernel"
    bks="$kroot/build/scripts/build_kernel.sh"
    test -f "$bks" || continue
    if grep -q 'build_uspace.sh alios_libs' "$bks" && ! grep -q 'MIRA_SKIP_SDK_USPACE_LIBS' "$bks"; then
        sed -i '/^\.\/build_uspace\.sh alios_libs/s/^/# MIRA_SKIP_SDK_USPACE_LIBS: /' "$bks"
    fi
done

echo "mira_patch_kernel_uspace_trees: done"
