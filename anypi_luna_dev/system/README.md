# anypi_luna_dev `system/` overview

PDK base: repo root `system/AnyCloud39AV100_V2/V2.04/` (vendor SDK).  
Product overlay: `project/anypi_luna_dev/system/AnyCloud39AV100_V2/V2.04/`.

## Product deltas only

| Path | Role |
|------|------|
| `board/EVB_MBD_KM01A/config.mk` | `CONFIG_SENSOR_NAME=gc4053`, `CONFIG_WIFI_TYPE=atbm6032`, default DTB `EVB_CBDM_KM01A_V1.0.0` |
| `board/.../rootfs/utils/etc/config/` | `app.sh`, HAL/FW ini/json for headless ipcamera |
| `board/.../rootfs/utils/etc/isp_gc4053_*.conf` | Sensor ISP |
| `patch/rootfs/` | `gc4053.sh`, `sensor_gc4053.ko`, AI model, wifi tools (atbm) |
| `patch/os/kernel/` | Minimal netfilter / other non-LCD patches only |

**Not maintained here**: LCD fbtft、触摸、ACTCAM DTS、wearable sync 脚本。DTS 使用 SDK 默认 `EVB_CBDM_KM01A`。

## Build flow

`build_soc_system.sh`：解压 SDK → 覆盖 `board/*` → 覆盖 `patch/*` → `build_kernel.sh` / uboot / samples。
