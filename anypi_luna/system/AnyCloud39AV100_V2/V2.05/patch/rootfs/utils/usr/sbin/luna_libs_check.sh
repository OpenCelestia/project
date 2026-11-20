#!/bin/sh
# Quick dependency check for luna_main / libmultimedia.so (run on device shell).
set -u

echo "=== luna_libs_check ==="
echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-<unset>}"

check_file() {
    f="$1"
    if [ -e "$f" ]; then
        sz=$(wc -c < "$f" 2>/dev/null || echo 0)
        echo "OK   $f ($sz bytes)"
    else
        echo "MISS $f"
    fi
}

for f in \
    /lib/libstdc++.so.6 \
    /lib/libgcc_s.so.1 \
    /usr/lib/libsystem_core.so \
    /usr/lib/libhardware.so \
    /usr/lib/libruntime.so \
    /usr/lib/libnotification.so \
    /usr/lib/libstorage.so \
    /usr/lib/libnetwork.so \
    /usr/lib/libmultimedia.so \
    /usr/lib/libiconv.so.2 \
    /usr/lib/libiconv.so.2.6.0 \
    /usr/lib/libz.so.1 \
    /usr/lib/libz.so.1.3.1 \
    /usr/lib/libiniparser.so \
    /usr/lib/libcjson.so
do
    check_file "$f"
done

echo "--- stray C++ copies under /usr/lib (should be absent) ---"
for f in /usr/lib/libstdc++.so* /usr/lib/libgcc_s.so*; do
    [ -e "$f" ] || continue
    echo "WARN $f"
done

echo "--- LD_TRACE luna_main ---"
export LD_LIBRARY_PATH="/usr/bin/tslib/lib:/lib:/usr/lib"
LD_TRACE_LOADED_OBJECTS=1 /usr/sbin/luna_main 2>&1 | head -45
