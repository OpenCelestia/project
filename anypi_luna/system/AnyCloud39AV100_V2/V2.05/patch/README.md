# Luna `V2.05/patch` overlay

Chip-wide deltas from Luna SDK work (`V2.04_luna` vs vendor `V2.04`, the historical source tree), checked in under `board/` and `patch/` here. Ported to the V2.05 SDK baseline when anypi_luna moved to `CONFIG_SOC_SDK_VERSION = V2.05` (2026-09). Edit those trees directly when updating overlay content.

`build_soc_system.sh` copies `board/*` then `patch/*` onto the SDK build tree (same as anypi_nova `V1.03`).

## Layout

| Path | Content (from V2.04_luna diff) |
|------|--------------------------------|
| `patch/rootfs/utils/usr/sbin/` | `main.sh`, `os05a20.sh`, `ov02b10.sh`, … |
| `patch/rootfs/scripts/flash/rc.local.nor` | Early GPIO2 power-hold before `/usr` mount |
| `patch/os/kernel/drivers/pinctrl/anyka/ak_3918av100_pinctrl.c` | Register GPIO range before `gpiochip_add` (fixes pwr-hold hog) + re-latch GPIO2 after retention clear. Based on vendor V2.05 (retention rework + pin-mux table updates kept) |
| `patch/os/kernel/arch/arm/boot/dts/` | `anycloud_km01a.dtsi`, `Makefile` (ACTCAM dtb; V2.05 vendor board entries kept) |
| `patch/os/kernel/drivers/staging/fbtft/` | ST7789 LCD fbtft driver |
| `patch/scripts/` | Celestia `build_rootfs.sh` hooks (when added) |

Board-specific files live under `../board/PDB_MBD_KM01W_ACTCAM/` (DTS ACTCAM, `config.mk`, burntool, `rootfs/utils/etc/config/`).

`platform/include/` is not used for AV100 V2.05 (SDK already has `ak_svp2.h`, `ak_npu.h`). Do not copy nova AV200 headers here.
