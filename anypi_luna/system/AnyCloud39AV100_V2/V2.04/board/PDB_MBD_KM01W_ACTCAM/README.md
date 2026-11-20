# PDB_MBD_KM01W_ACTCAM — board notes

## `rootfs/utils/etc/config/` inventory (Luna)

Installed flat to `/etc/config/` (`process_utils`). Do not add subfolders — HAL/framework hardcode filenames.

Split by **Product** (factory / board-defined) vs **Runtime** (user / mutable) **fields**. Naming stays `app_` / `fw_` / `hal_`.

### Product vs Runtime

| File | Class | Contents |
|------|-------|----------|
| `settings.json` | Product + Runtime (one SoT) | **Product/boot:** `program`, `launch_mode`, `modules`, `input` (`keys` / `power_key`). **Runtime (RMW):** `language`, `wifi` (ssid / enable / psk as `enc:v1:` / ability / mode / ap{}), `installed_apps`. `gui_luna.config_path` → `/etc/config/settings.json` |
| `fw_video_config.json` | Product | Framework video / OSD / `app_stream_usage` (camera & dashcam leave AI off) |
| `fw_audio_config.ini` | Product | Multimedia audio encode |
| `fw_ai_config.ini` | Product | Product-wide detector enables (`ai_object_enable`); all off for Luna wearable |
| `audio_config.ini` | Product | Chip/SDK `LoadConf` for `AK_MPI_*_LoadConf` (system/HAL path) — **not** framework `fw_audio` |
| `hal_audio_config.ini` | Product | HAL gains / buffers |
| `hal_camera_config.ini` | Product | ISP / mirror / AI model |
| `app.sh`, `app_02_load.sh`, `tft_st7789.sh` | Board / boot | Startup scripts |
| `ts.rgb.conf`, `ts_calibrate.rgb.conf` | Board / boot | tslib |

Writers of runtime fields (`language` / `wifi` / `installed_apps`) must **RMW**: load full JSON, modify only that subtree, write back — do not wipe `program` / `modules`.

### Keymap / power key

- LVGL keys: `settings.json` → `input.keys`; invalid/missing values use built-in defaults
- Power key: `settings.json` → `input.power_key`; invalid/missing values use built-in defaults
- Luna no longer deploys `gui_input_config.ini`, `app_input_config.ini`, or `luna_power_keyd.ini`

### Network note
- All WiFi config in `settings.json` → `wifi` (ssid, psk, enable, ability, mode, ap{})
- PSK is encrypted at write (`enc:v1:` + AES-128-CBC/base64 obfuscation in `wifi_cred_crypto`); plaintext legacy values still decrypt/pass-through
- Framework reads `settings.json` `wifi{}`; legacy fallback to `wifi_config.ini` `[station]` on old images
- HAL uses built-in defaults (ability=2, ap off) when no `wifi_config.ini` is present

### AI note
- `fw_ai_config.ini` is **product-wide** detector enable table (all 0 on Luna)
- Per-app runtime uses `multimedia_set_camera_ai_enabled` / `set_ai_enabled`; camera & dashcam keep AI off via `fw_video_config.json` `app_stream_usage`
- Do not split into per-app AI INI unless detector tables actually differ (they do not for Luna)

### Application note
- Language: `settings.json` → `language.id` (fallback: legacy INI `[language]` via `cfg_path` if present)
- Installed apps: `settings.json` → `installed_apps` (fallback: `installed_apps.json`)
- Wearable `app_lv_open` does not require `app_config.ini`; `gui_luna.config_path` points at `settings.json` (same SoT)

### Audio note
- `audio_config.ini` — Anyka SDK / HAL `AK_MPI_*_LoadConf` (system path under rootfs utils)
- `fw_audio_config.ini` / `hal_audio_config.ini` — framework multimedia / HAL gains respectively

### Removed
`app_runtime.json` (renamed to `settings.json`; readers still accept it), `app_user.json` (folded into `settings.json`), `app_config.ini` / `app_gui_config.ini` (language → `settings.json`), `gui_input_config.ini` / `app_input_config.ini` / `luna_power_keyd.ini` (keys and power key → `settings.json` `input`), `fw_osd_config.json`, `installed_apps.json`, `wifi_config.ini` (merged into `settings.json` wifi{}; HAL uses built-in defaults), `hal_wifi_config.ini`, `fw_wlan_config.ini`, `wpa_supplicant.conf`, `isp.ini`, `system.ini`, `media.ini`, `ak_ats.c`.
