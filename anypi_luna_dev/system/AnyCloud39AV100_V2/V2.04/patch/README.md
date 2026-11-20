# anypi_luna_dev `V2.04/patch` overlay

Chip-wide deltas on top of vendor `system/AnyCloud39AV100_V2/V2.04/`.  
`build_soc_system.sh` copies `board/*` then `patch/*` onto the build tree.

## Keep (used by DEV)

| Path | Content |
|------|---------|
| `patch/rootfs/utils/usr/sbin/gc4053.sh` | Sensor load |
| `patch/rootfs/utils/usr/modules/sensor_gc4053.ko` | Sensor ko |
| `patch/rootfs/utils/usr/modules/ak_isp.ko` | ISP ko (if SDK build lacks it) |
| `patch/rootfs/utils/usr/model/` | AI model bin |
| `patch/rootfs/wifi/` | atbm6032 userland (wpa/hostapd/atbm_*) |
| `patch/rootfs/utils/usr/sbin/{main,service}.sh` | Boot helpers when needed |
| `patch/os/kernel/net/netfilter/` | Optional netfilter tweaks |

## Do not put here

- LCD `fbtft` / ST7789 drivers
- Touch `cst816x.ko`
- ACTCAM / KM01W custom DTS (use SDK `EVB_CBDM_KM01A`)
- Wearable sync scripts
