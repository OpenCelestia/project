# EVB_MBD_KM01A — board notes

## `rootfs/utils/etc/config/` inventory (anypi_luna_dev — headless ipcamera)

Installed flat to `/etc/config/` (`process_utils`). Do not add subfolders — HAL/framework/app code hardcode filenames.

**Not the Luna wearable product.** `anypi_luna_dev` builds `luna_dev_main` with only
`CONFIG_APP_PACKAGES_IPCAMERA=y` (headless, no UI/LCD, no `installed_apps.json`/GUI ini) — it links
`packages/ipcamera/ipc_cam` directly, not `packages/wearable`. See `project/anypi_luna_dev/config`
(now removed) / `config.mk` for capability flags.

This directory is the **single source of truth**. The old top-level `project/anypi_luna_dev/config/`
mirror (`settings.json` only) has been removed — `package.sh`'s `install_celestia_app_main` now reads
`settings.json` from here (via `runtime_config_dir_from_proj`, same helper Luna uses) and only patches
the `"program"` field before staging it into the build output; it no longer falls back to a top-level
project `config/` copy unless this board directory is missing.

### App runtime
| File | Class | Contents |
|------|-------|----------|
| `settings.json` | Product + Runtime | `program` (patched at package time to `/usr/sbin/luna_dev_main`), `launch_mode=ipcamera`, `modules.ipc_cam` → `/usr/lib/libipc_cam_app.so`, config `fw_video_config.json` |
| `fw_video_config.json` | Product | Framework video / OSD / stream usage |
| `fw_audio_config.ini` | Product | Multimedia audio encode |
| `fw_ai_config.ini` | Product | Product-wide detector enables |
| `fw_wlan_config.ini` | Product | `network.c` legacy WiFi fallback |
| `hal_wifi_config.ini`, `wpa_supplicant.conf` | Product | WiFi HAL / supplicant (no settings UI package here to read `settings.json` wifi{} the way Luna's wearable does) |
| `audio_config.ini`, `hal_audio_config.ini`, `hal_camera_config.ini` | Product | Vendor SDK / HAL audio & camera |
| `isp.ini`, `system.ini`, `media.ini` | Product | ISP tuning / system / media — no reader package linked into this headless build today, kept for parity with the AV100 SDK's expected file set |
| `app_dashcam_config.json` | Product | Dashcam stream config (if `ipc_cam` dashcam mode enabled) |
| `app.sh` | Board / boot | Startup script |

### Not yet consolidated
No `installed_apps`/`input`/`wifi{}` merge was needed or done here — this build has no launcher UI, no
physical keys, and no settings app reading `settings.json` beyond `program`/`launch_mode`/`modules`.
