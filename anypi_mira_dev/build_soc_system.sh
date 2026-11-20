#!/bin/bash
# Sky39AV130 BSP staging + build (aligned with SDK auto_build.sh).
# Vendor tree under system/Sky39AV130 is read-only; board/rules live in project/anypi_mira_dev.
set -e

_MIRA_SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=setup_toolchain.sh
. "$_MIRA_SCRIPT_DIR/setup_toolchain.sh"

SRC_DIR=$1
BUILD_SRC_DIR=$2
REL_SOC_PLATFORM_DIR=$3
REL_PROJECT_DIR=$4
CONFIG_BOARD=$5
SOC_PLATFORM_INSTALL_DIR=$6

DRIVER_INSTALL_DIR=./os/driver

copy_dir()
{
    src_dir=$1
    dest_dir=$2
    if test ! -d "$src_dir" ; then
        return 0
    fi
    mkdir -p "$dest_dir"
    cp -rf "$src_dir"/* "$dest_dir"
}

mira_restore_kernel_host_tools()
{
    local os_dir=$1
    local tgz=$2
    local kroot="$os_dir/kernel"
    mkdir -p "$os_dir"
    tar xzf "$tgz" -C "$os_dir" \
        kernel/build/cmd/linux64/dash \
        kernel/build/simplebuild/make.py \
        kernel/build/simplebuild/make.pyc 2>/dev/null || \
    tar xzf "$tgz" -C "$os_dir" \
        kernel/build/cmd/linux64/dash \
        kernel/build/simplebuild/make.py
    chmod +x "$kroot/build/cmd/linux64/dash" 2>/dev/null || true
}

mira_ensure_kernel_tree()
{
    local os_dir=$1
    local tgz=$2
    local kroot="$os_dir/kernel"
    if test -x "$kroot/build/cmd/linux64/dash" \
        && test -f "$kroot/build/simplebuild/make.py" ; then
        chmod +x "$kroot/build/cmd/linux64/dash" 2>/dev/null || true
        mira_patch_kernel_host_python "$kroot"
        mira_patch_kernel_build_scripts "$kroot"
        mira_patch_kernel_uspace "$kroot"
        mira_patch_kernel_memmaps "$kroot"
        return 0
    fi
    if test -d "$kroot" && test -f "$kroot/Makefile" ; then
        echo "Restoring kernel host build tools (dash/make.py) from $tgz"
        mira_restore_kernel_host_tools "$os_dir" "$tgz"
        mira_patch_kernel_host_python "$kroot"
        mira_patch_kernel_build_scripts "$kroot"
        mira_patch_kernel_uspace "$kroot"
        mira_patch_kernel_memmaps "$kroot"
        if test -x "$kroot/build/cmd/linux64/dash" ; then
            return 0
        fi
    fi
    echo "Ensuring full kernel tree from $tgz"
    rm -rf "$kroot"
    mkdir -p "$os_dir"
    tar xzf "$tgz" -C "$os_dir"
    if test ! -x "$kroot/build/cmd/linux64/dash" ; then
        echo "ERROR: kernel tree still incomplete after extract (missing dash)"
        exit 1
    fi
    chmod +x "$kroot/build/cmd/linux64/dash"
    mira_patch_kernel_host_python "$kroot"
    mira_patch_kernel_build_scripts "$kroot"
    mira_patch_kernel_uspace "$kroot"
    mira_patch_kernel_memmaps "$kroot"
}

mira_patch_kernel_out_bin_check()
{
    local kbs=$1
    test -f "$kbs" || return 0
    if grep -q 'MIRA_KERNEL_OUT_BIN' "$kbs" ; then
        sed -i -e 's|\${root_dir}/\.\./\.\./\.\./alios_kernel@|\${root_dir}/../../alios_kernel@|g' \
               -e 's|\${root_dir}/\.\./\.\./\.\./\.\./\.\./alios_kernel@|\${root_dir}/../../alios_kernel@|g' "$kbs"
        return 0
    fi
    if ! command -v python3 >/dev/null 2>&1 ; then
        echo "ERROR: python3 not found (required for mira_patch_kernel_out_bin_check)"
        return 1
    fi
    if ! python3 - "$kbs" <<'PY'
import sys

path = sys.argv[1]
with open(path, encoding="utf-8", errors="replace") as f:
    text = f.read().replace("\r\n", "\n").replace("\r", "\n")

text = text.replace(
    "${root_dir}/../../../alios_kernel@",
    "${root_dir}/../../alios_kernel@",
)

new_block = """# MIRA_KERNEL_OUT_BIN: kernel.bin is built into $SDK_BUILD (root_dir/../..), not kernel/out
_kbin="${root_dir}/out/alios_kernel@${board_name}-mkkernel/binary/alios_kernel@${board_name}-mk.kernel.bin"
_mira_alt="${root_dir}/../../alios_kernel@${board_name}-mkkernel/binary/alios_kernel@${board_name}-mk.kernel.bin"
if [ ! -f "$_kbin" ] && [ -f "$_mira_alt" ]; then
    mkdir -p "$(dirname "$_kbin")"
    cp -f "$_mira_alt" "$_kbin"
    cp -f "${_mira_alt%.bin}.elf" "${_kbin%.bin}.elf" 2>/dev/null || true
    cp -f "${_mira_alt%.bin}.map" "${_kbin%.bin}.map" 2>/dev/null || true
fi
if [ ! -f "$_kbin" ]; then
    echo -e "\\033[41;33mkernel build failed\\033[0m"
    exit 1
fi"""

needle = "alios_kernel@$board_name-mkkernel/binary/alios_kernel@$board_name-mk.kernel.bin"
lines = text.split("\n")
out = []
i = 0
replaced = False
while i < len(lines):
    line = lines[i]
    if (
        not replaced
        and needle in line
        and "if " in line
        and "! -f" in line
        and "${root_dir}/out/" in line
    ):
        j = i + 1
        while j < len(lines) and lines[j].strip() != "fi":
            j += 1
        if j < len(lines) and any("kernel build failed" in lines[k] for k in range(i + 1, j)):
            out.append(new_block.rstrip("\n"))
            i = j + 1
            replaced = True
            continue
    out.append(line)
    i += 1

if not replaced:
    print(
        "mira_patch_kernel_out_bin_check: kernel.bin check block not found in",
        path,
        file=sys.stderr,
    )
    sys.exit(1)

with open(path, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(out))
    if text.endswith("\n"):
        f.write("\n")
PY
    then
        echo "ERROR: failed to patch kernel build_kernel.sh (kernel.bin path check)"
        return 1
    fi
}

mira_patch_kernel_uspace()
{
    local kroot=$1
    local udc="$kroot/kernel/core/mk/uspace/include/u_default_config.h"
    local umd="$kroot/kernel/core/mk/uspace/src/umm/u_mm_debug.c"
    if test -f "$udc" && ! grep -q 'RHINO_CONFIG_APP_ENTRY_TASK_NAME' "$udc" ; then
        echo "Mira: patch kernel u_default_config.h (RHINO_CONFIG_APP_ENTRY_TASK_NAME)"
        if ! command -v python3 >/dev/null 2>&1 ; then
            echo "ERROR: python3 required for mira_patch_kernel_uspace"
            return 1
        fi
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
if "RHINO_CONFIG_APP_ENTRY_TASK_NAME" in text:
    sys.exit(0)
anchor = "#ifndef RHINO_CONFIG_APP_NAME\n#define RHINO_CONFIG_APP_NAME \"aos_app\"\n#endif"
if anchor in text:
    text = text.replace(anchor, anchor + "\n\n" + block, 1)
else:
    print("mira_patch_kernel_uspace: RHINO_CONFIG_APP_NAME anchor not found", file=sys.stderr)
    sys.exit(1)
with open(path, "w", encoding="utf-8", newline="\n") as f:
    f.write(text)
PY
    fi
    if test -f "$umd" && ! grep -q 'u_default_config.h' "$umd" ; then
        echo "Mira: patch kernel u_mm_debug.c (include u_default_config.h)"
        sed -i '/#include "k_api.h"/a #include "u_default_config.h"' "$umd"
    fi
    if test -f "$udc" && ! grep -q 'MIRA: aos_app ustack 64KB' "$udc" ; then
        echo "Mira: patch kernel u_default_config.h (aos_app ustack 64KB)"
        if ! command -v python3 >/dev/null 2>&1 ; then
            echo "ERROR: python3 required for mira_patch_kernel_uspace (ustack)"
            return 1
        fi
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
        print("mira_patch_kernel_uspace: USTACK_SIZE anchor not found", file=sys.stderr)
        sys.exit(1)
with open(path, "w", encoding="utf-8", newline="\n") as f:
    f.write(text)
PY
    fi
}

# Map the lazy post-load region statically at boot.
#
# g_memmaps only maps text/data/bss. The post-load region (lwip, usb, net, ...)
# is otherwise mapped dynamically by post_load_kernel() via k_mmap(), which uses
# the CURRENT asid (aos_pftask). Tasks running on any other page table (e.g. the
# process loader) then take a section translation fault when they touch a symbol
# that lives in the post region (e.g. the lwip "tcp/ip" task name). Adding the
# post region to g_memmaps maps it into the kernel table before any process page
# table is created, so every k_pgt_init() inherits it.
mira_patch_kernel_memmaps()
{
    local kroot=$1
    local soc="$kroot/vendor/anyka/soc/aos/soc_impl.c"
    if test -f "$soc" && ! grep -q 'MIRA_POST_MMAP' "$soc" ; then
        echo "Mira: patch kernel soc_impl.c (map post-load region in g_memmaps)"
        if ! command -v python3 >/dev/null 2>&1 ; then
            echo "ERROR: python3 required for mira_patch_kernel_memmaps"
            return 1
        fi
        python3 - "$soc" <<'PY'
import sys

path = sys.argv[1]
with open(path, encoding="utf-8", errors="replace") as f:
    text = f.read().replace("\r\n", "\n").replace("\r", "\n")

if "MIRA_POST_MMAP" in text:
    sys.exit(0)

ext_anchor = "extern void         *_mmu_bss_heap_len;\n"
ext_block = (
    "/* MIRA_POST_MMAP: post-load region symbols */\n"
    "extern void         *_mmu_post_text_start;\n"
    "extern void         *_mmu_post_text_len;\n"
    "extern void         *_mmu_post_data_start;\n"
    "extern void         *_mmu_post_data_len;\n"
)
map_anchor = (
    "    {(uintptr_t)&_mmu_data_start, (uintptr_t)&_mmu_data_start, "
    "(size_t)&_mmu_data_len, MMU_ATTR_DATA},  /* data */\n"
)
map_block = (
    "    /* MIRA_POST_MMAP: map lazy post-load region at boot (inherited by all procs) */\n"
    "    {(uintptr_t)&_mmu_post_text_start, (uintptr_t)&_mmu_post_text_start, "
    "(size_t)&_mmu_post_text_len, MMU_ATTR_DATA},  /* post text+rodata */\n"
    "    {(uintptr_t)&_mmu_post_data_start, (uintptr_t)&_mmu_post_data_start, "
    "(size_t)&_mmu_post_data_len, MMU_ATTR_DATA},  /* post data */\n"
)

if ext_anchor not in text or map_anchor not in text:
    print("mira_patch_kernel_memmaps: anchors not found", file=sys.stderr)
    sys.exit(1)

text = text.replace(ext_anchor, ext_anchor + ext_block, 1)
text = text.replace(map_anchor, map_anchor + map_block, 1)

with open(path, "w", encoding="utf-8", newline="\n") as f:
    f.write(text)
PY
    fi
}

mira_patch_kernel_build_scripts()
{
    local kroot=$1
    local gac="$kroot/build/scripts/gen_auto_code.py"
    if test -f "$gac" ; then
        sed -i 's/open(os.path.join(root, include), "r")/open(os.path.join(root, include), "r", encoding="latin-1")/g' "$gac"
        sed -i 's/open(os.path.join(root, source), "r")/open(os.path.join(root, source), "r", encoding="latin-1")/g' "$gac"
        sed -i 's/open(sys.argv\[1\], "r")/open(sys.argv[1], "r", encoding="latin-1")/g' "$gac"
    fi
    local kbs="$kroot/build/scripts/build_kernel.sh"
    if test -f "$kbs" && ! grep -q 'MIRA_PATCH_USPACE_TREES' "$kbs" ; then
        local _tmp
        _tmp=$(mktemp)
        {
            head -n 1 "$kbs"
            echo "# MIRA_PATCH_USPACE_TREES"
            echo "bash $_MIRA_SCRIPT_DIR/mira_patch_kernel_uspace_trees.sh || true"
            tail -n +2 "$kbs"
        } > "$_tmp"
        mv "$_tmp" "$kbs"
    fi
    if test -f "$kbs" && grep -q 'buildtool distclean' "$kbs" ; then
        sed -i 's/^\$buildtool distclean; \$buildtool/\$buildtool/' "$kbs"
    fi
    mira_patch_kernel_out_bin_check "$kbs"
    if test -f "$kbs" ; then
        chmod +x "$kbs"
    fi
    local mpg="$kroot/build/scripts/map_parse_gcc.py"
    if test -f "$mpg" ; then
        if grep -q 'reduce(' "$mpg" && ! grep -q 'functools import reduce' "$mpg" ; then
            sed -i '1a from functools import reduce' "$mpg"
        fi
        sed -i 's/reduce(lambda x,y:x+y, map(ram_size_def, sections))/reduce(lambda x,y:x+y, map(ram_size_def, sections), 0)/g' "$mpg"
        sed -i 's/reduce(lambda x,y:x+y, map(rom_size_def, sections))/reduce(lambda x,y:x+y, map(rom_size_def, sections), 0)/g' "$mpg"
    fi
}

mira_patch_kernel_host_python()
{
    local kroot=$1
    local f
    for f in "$kroot/build/cmd/python"/*.py "$kroot/build/scripts"/*.py ; do
        test -f "$f" || continue
        if grep -qE '^[[:space:]]*print[[:space:]]+[^=(]' "$f" 2>/dev/null ; then
            sed -i -E 's/^([[:space:]]*)print[[:space:]]+(.+)$/\1print(\2)/' "$f"
        fi
        if grep -qE '\bfile\(' "$f" 2>/dev/null ; then
            sed -i 's/\bfile(/open(/g' "$f"
        fi
    done
}

mira_fix_kernel_defconfig()
{
    local def="$1"
    if test ! -f "$def" ; then
        return 0
    fi
    if ! grep -q '^AOS_BOARD_SKY3918AV130_MK=y' "$def" ; then
        echo "Patch kernel defconfig: enable AOS_BOARD_SKY3918AV130_MK"
        printf '\nAOS_BOARD_SKY3918AV130_MK=y\n' >> "$def"
    fi
}

mira_patch_kernel_skip_sdk_uspace_libs()
{
    local kroot=$1
    local bks="$kroot/build/scripts/build_kernel.sh"
    test -f "$bks" || return 0
    if grep -q 'MIRA_SKIP_SDK_USPACE_LIBS' "$bks" ; then
        return 0
    fi
    echo "Mira: skip SDK build_uspace.sh alios_libs (user app is Celestia user.strip.elf)"
    sed -i '/^\.\/build_uspace\.sh alios_libs/s/^/# MIRA_SKIP_SDK_USPACE_LIBS: /' "$bks"
}

tar_gz_dir()
{
    src_file=$1
    dest_dir=$2
    if test ! -f "$src_file" ; then
        echo "ERROR: missing $src_file"
        exit 1
    fi
    rel_tar_dir=$(tar -tf "$src_file" | head -n 1 | xargs | sed 's|/*$||')
    need_extract=0
    if test ! -e "$dest_dir/$rel_tar_dir" ; then
        need_extract=1
    elif test "$rel_tar_dir" = "kernel" ; then
        if test ! -x "$dest_dir/kernel/build/cmd/linux64/dash" \
            || test ! -f "$dest_dir/kernel/build/simplebuild/make.py" ; then
            echo "Warning: incomplete kernel tree, re-extract $src_file"
            rm -rf "$dest_dir/kernel"
            need_extract=1
        fi
    elif test "$rel_tar_dir" = "uboot" && test ! -f "$dest_dir/uboot/Makefile" ; then
        echo "Warning: incomplete uboot tree, re-extract $src_file"
        rm -rf "$dest_dir/uboot"
        need_extract=1
    fi
    if test "$need_extract" -eq 1 ; then
        echo "$src_file -> $dest_dir"
        mkdir -p "$dest_dir"
        tar xfz "$src_file" -C "$dest_dir"
    fi
}

process_wifi_driver() {
    rm -rf "$DRIVER_INSTALL_DIR"/link/*wifi* 2>/dev/null || true
    if test -z "$CONFIG_WIFI_TYPE" || test "$CONFIG_WIFI_TYPE" = "NO_WIFI" ; then
        return 0
    fi
    if test "$CONFIG_WIFI_TYPE" = rtl8188ftv ; then
        cp -f "$DRIVER_INSTALL_DIR"/libdrv_wifi_*"$CONFIG_WIFI_TYPE"*.a "$DRIVER_INSTALL_DIR"/link
    else
        cp -f "$DRIVER_INSTALL_DIR"/libdrv_wifi_*"$CONFIG_WIFI_TYPE".a "$DRIVER_INSTALL_DIR"/link
    fi
}

process_sensor_driver() {
    OLD_IFS="$IFS"
    IFS=","
    # shellcheck disable=SC2206
    sensor_list=($CONFIG_CIS_TYPE)
    IFS=$OLD_IFS
    rm -rf "$DRIVER_INSTALL_DIR"/link/libdrv_sensor_*.a
    for var in "${sensor_list[@]}" ; do
        cp -f "$DRIVER_INSTALL_DIR"/libdrv_sensor_"$var".a "$DRIVER_INSTALL_DIR"/link
    done
}

process_driver_lib()
{
    if test ! -f "$CONFIG_TOP_DIR/configs/$CONFIG_DRIVER_FILE" ; then
        echo "ERROR: driver defconfig missing: $CONFIG_TOP_DIR/configs/$CONFIG_DRIVER_FILE"
        exit 1
    fi
    cp -f "$CONFIG_TOP_DIR/configs/$CONFIG_DRIVER_FILE" "$DRIVER_INSTALL_DIR/.config"
    (
        cd "$DRIVER_INSTALL_DIR"
        rm -rf link
        mkdir -p link
        make link_intall || exit 1
    )
    process_wifi_driver
    process_sensor_driver
}

SDK_SRC="$SRC_DIR/$REL_SOC_PLATFORM_DIR"
SDK_BUILD="$BUILD_SRC_DIR/$REL_SOC_PLATFORM_DIR"
PROJ_BOARD="$SRC_DIR/$REL_PROJECT_DIR/$REL_SOC_PLATFORM_DIR/board/$CONFIG_BOARD"
PROJ_RULES="$SRC_DIR/$REL_PROJECT_DIR/$REL_SOC_PLATFORM_DIR/rules.mk"

mkdir -p "$SDK_BUILD"
cd "$SDK_BUILD"

if test ! -f "$PROJ_BOARD/config.mk" ; then
    echo "ERROR: board config missing: $PROJ_BOARD/config.mk"
    exit 1
fi
cp -f "$PROJ_BOARD/config.mk" "$SDK_BUILD/config.mk"
tr -d '\r' < "$SDK_BUILD/config.mk" > "$SDK_BUILD/config.mk.lf"
mv -f "$SDK_BUILD/config.mk.lf" "$SDK_BUILD/config.mk"

tar_gz_dir "$SDK_SRC/os/kernel.tar.gz" "$SDK_BUILD/os"
tar_gz_dir "$SDK_SRC/os/uboot.tar.gz" "$SDK_BUILD/os"
tar_gz_dir "$SDK_SRC/rootfs/rootfs.tar.gz" "$SDK_BUILD/rootfs"

copy_dir "$SDK_SRC/rootfs" "$SDK_BUILD/rootfs"
copy_dir "$SDK_SRC/scripts" "$SDK_BUILD/scripts"
copy_dir "$SDK_SRC/tools" "$SDK_BUILD/tools"
copy_dir "$SDK_SRC/configs" "$SDK_BUILD/configs"
PROJ_CONFIGS="$SRC_DIR/$REL_PROJECT_DIR/$REL_SOC_PLATFORM_DIR/configs"
if test -d "$PROJ_CONFIGS" ; then
    copy_dir "$PROJ_CONFIGS" "$SDK_BUILD/configs"
fi
copy_dir "$SDK_SRC/os/driver" "$SDK_BUILD/os/driver"
copy_dir "$SDK_SRC/os/dep_lib" "$SDK_BUILD/os/dep_lib"
copy_dir "$SDK_SRC/os/dtc" "$SDK_BUILD/os/dtc"
copy_dir "$SDK_SRC/platform" "$SDK_BUILD/platform"

cp -f "$SDK_SRC/rules.mk" "$SDK_BUILD/rules.mk"
if test -f "$PROJ_RULES" ; then
    cp -f "$PROJ_RULES" "$SDK_BUILD/rules.mk"
fi
cp -f "$SDK_SRC/aos_user.ld" "$SDK_BUILD/aos_user.ld"
cp -f "$SDK_SRC/Makefile" "$SDK_BUILD/Makefile"
mkdir -p "$SDK_BUILD/image"

cp -rf "$PROJ_BOARD"/* "$SDK_BUILD/"

if test -d "$PROJ_BOARD/dts" && ls "$PROJ_BOARD"/dts/*.dts >/dev/null 2>&1 ; then
    mkdir -p "$SDK_BUILD/os/dtc/dts"
    cp -f "$PROJ_BOARD"/dts/*.dts "$SDK_BUILD/os/dtc/dts/"
fi

mira_ensure_kernel_tree "$SDK_BUILD/os" "$SDK_SRC/os/kernel.tar.gz"

tr -d '\r' < "$SDK_BUILD/config.mk" > "$SDK_BUILD/config.mk.lf"
mv -f "$SDK_BUILD/config.mk.lf" "$SDK_BUILD/config.mk"
# shellcheck disable=SC1091
source "$SDK_BUILD/config.mk"

mira_setup_toolchain "$SRC_DIR" || exit 1
if grep -q '^CONFIG_TOOLCHAIN_PATH=' "$SDK_BUILD/config.mk" ; then
    sed -i "s|^CONFIG_TOOLCHAIN_PATH=.*|CONFIG_TOOLCHAIN_PATH=$MIRA_TOOLCHAIN_ROOT|" "$SDK_BUILD/config.mk"
else
    echo "CONFIG_TOOLCHAIN_PATH=$MIRA_TOOLCHAIN_ROOT" >> "$SDK_BUILD/config.mk"
fi
export CONFIG_TOOLCHAIN_PATH="$MIRA_TOOLCHAIN_ROOT"

mkdir -p "$SOC_PLATFORM_INSTALL_DIR"
cp -rf "$SDK_BUILD/platform"/* "$SOC_PLATFORM_INSTALL_DIR/"

echo "Building uboot CONFIG_FAST_LAUNCH=${CONFIG_FAST_LAUNCH} MAKEFLAGS=-j${MIRA_UBOOT_JOBS:-1}..."
_uboot_makeflags=${MAKEFLAGS:-}
export MAKEFLAGS=-j"${MIRA_UBOOT_JOBS:-1}"
if test "$CONFIG_FAST_LAUNCH" = y ; then
    ./scripts/build_uboot.sh spl
else
    ./scripts/build_uboot.sh normal
fi
export MAKEFLAGS="${_uboot_makeflags}"

echo "Linking kernel driver libraries..."
process_driver_lib

echo "Re-staging kernel tree for compile..."
rm -rf "$SDK_BUILD/os/kernel"
tar xzf "$SDK_SRC/os/kernel.tar.gz" -C "$SDK_BUILD/os"
mira_ensure_kernel_tree "$SDK_BUILD/os" "$SDK_SRC/os/kernel.tar.gz"
mira_patch_kernel_uspace "$SDK_BUILD/os/kernel"
mira_patch_kernel_memmaps "$SDK_BUILD/os/kernel"
mira_patch_kernel_skip_sdk_uspace_libs "$SDK_BUILD/os/kernel"
mira_fix_kernel_defconfig "$SDK_BUILD/os/kernel/vendor/anyka/configs/anyka_ak3918av130_defconfig"

if ! command -v python3 >/dev/null 2>&1 ; then
    echo "ERROR: python3 is required for the kernel host scripts"
    exit 1
fi
export PYTHON=python3

if test ! -x "$SDK_BUILD/os/kernel/build/cmd/linux64/dash" ; then
    echo "ERROR: kernel host tool dash missing after staging"
    exit 1
fi

echo "Building kernel..."
bash "$_MIRA_SCRIPT_DIR/mira_patch_kernel_uspace_trees.sh" || true
set +e
# Point the Aos mk build at $SDK_BUILD: its out tree (alios_kernel@...-mkkernel)
# then sits beside image/ instead of buried under os/kernel/out or at $BUILD_SRC_DIR.
env BUILD_DIR="$SDK_BUILD" ./scripts/build_kernel.sh all
_kr=$?
set -e
if test "$_kr" -ne 0 ; then
    _kb="$SDK_BUILD/alios_kernel@sky3918av130-mkkernel/binary/alios_kernel@sky3918av130-mk.kernel.bin"
    if test -f "$_kb" ; then
        echo "Mira: kernel.bin under SDK_BUILD; installing images and uImage..."
        cp -f "$_kb" "$SDK_BUILD/image/aos.bin"
        cp -f "${_kb%.bin}.elf" "$SDK_BUILD/image/aos.elf" 2>/dev/null || true
        cp -f "${_kb%.bin}.map" "$SDK_BUILD/image/aos.map" 2>/dev/null || true
        env BUILD_DIR="$SDK_BUILD" ./scripts/build_kernel.sh image || exit 1
    else
        exit 1
    fi
fi

echo "Building DTB..."
./scripts/build_dtb.sh all
