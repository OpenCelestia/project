#!/bin/bash
# Aos arm-none-eabi toolchain for anypi_mira_dev only (not sourced from scripts/build.sh).
# Prefer CONFIG_TOOLCHAIN_PATH or /opt/arm-alios-eabi; otherwise extract SDK tarball under out/<project dir>/toolchain.

_mira_default_toolchain=/opt/arm-alios-eabi
_mira_toolchain_tgz_rel=system/Sky39AV130/V1.01/tools/toolchain/arm-alios-eabi-2022-10-18.tar.gz

mira_setup_toolchain()
{
    local repo_root=$1
    # out/ subdir follows the project directory name (rename-safe).
    local self_dir; self_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    local product_name; product_name=$(basename "$self_dir")
    local prefer=${CONFIG_TOOLCHAIN_PATH:-$_mira_default_toolchain}

    if test -x "$prefer/bin/arm-none-eabi-gcc" ; then
        MIRA_TOOLCHAIN_ROOT="$prefer"
    else
        local cache="$repo_root/out/$product_name/toolchain/arm-alios-eabi"
        local tgz="$repo_root/$_mira_toolchain_tgz_rel"
        if test ! -x "$cache/bin/arm-none-eabi-gcc" ; then
            if test ! -f "$tgz" ; then
                echo "ERROR: Aos toolchain missing."
                echo "  Install SDK tarball to $_mira_default_toolchain, or keep"
                echo "  $_mira_toolchain_tgz_rel in the repo for auto-extract to:"
                echo "  $cache"
                return 1
            fi
            echo "Extracting Aos toolchain to $cache ($product_name local cache)..."
            mkdir -p "$cache"
            tar -xzf "$tgz" -C "$cache" --strip-components=1
        fi
        MIRA_TOOLCHAIN_ROOT="$cache"
    fi

    export MIRA_TOOLCHAIN_ROOT
    export PATH="$MIRA_TOOLCHAIN_ROOT/bin:$PATH"
    export ANYKA_TOOLCHAIN_PATH="$MIRA_TOOLCHAIN_ROOT"
    export CONFIG_TOOLCHAIN_PATH="$MIRA_TOOLCHAIN_ROOT"
}
