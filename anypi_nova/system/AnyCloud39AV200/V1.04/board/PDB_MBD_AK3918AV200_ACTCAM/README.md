# PDB_MBD_AK3918AV200_ACTCAM — board notes

## `rootfs/utils/etc/config/` inventory (Nova)

Installed flat to `/etc/config/` (`process_utils`). Do not add subfolders — HAL/framework/app code hardcode filenames.

This directory is the **single source of truth**. The old top-level `project/anypi_nova/config/`
mirror (`settings.json` / `installed_apps.json` / `weather.json`) has been removed — `build_rootfs.sh`
now deploys these three files straight from here (see "Build note" below), same as `process_utils`
already did for every other file in this folder.

### App runtime

| File | Class | Contents |
|------|-------|----------|
| `settings.json` | Product + Runtime (one SoT) | `program`, `launch_mode`, `language` (`id`), `wifi` (`enable`/`ssid`/`psk`/`auto_connect`/`ap`), `storage` (`mode`: **0**=local / **1**=usb_msc), `media` (`audio_path`/`video_path`), `device` (`id`), `dormancy` (`server_ip`/`server_port`), `modules` (per-app enable/type/config_path), `installed_apps` |
| `weather.json` | Runtime | Weather service API config (`modules.service_weather.config_path`) |
| `app_bailian_config.ini`, `app_volc_config.ini` | Product | Cloud module (Aliyun/VolcEngine) config, gated by `settings.json` → `modules.cloud_*` |

### Framework / HAL (not yet consolidated into `settings.json` — see note below)

| File | Class | Contents |
|------|-------|----------|
| `fw_video_config.json` | Product | Framework video / OSD (`osd_time`/`osd_text`/`osd_logo`) / stream usage |
| `fw_audio_config.ini` | Product | Multimedia audio encode |
| `fw_ai_config.ini` | Product | Product-wide detector enables |
| `audio_config.ini`, `hal_audio_config.ini`, `hal_camera_config.ini`, `hal_md_config.ini` | Product | Vendor SDK / HAL audio & camera & motion-detect config |
| `isp_ov8856_mipi_*lane_av200.conf` | Product | Sensor-specific ISP tuning blobs (path referenced by `hal_camera_config.ini` `[camera0] isp_config_path`) |
| `app.sh`/`app_01_start.sh`, `app_02_load.sh`, `net.sh` | Board / boot | Startup scripts |
| `ts.rgb.conf`, `ts_calibrate.rgb.conf` | Board / boot | tslib |
| `logo1.bmp`, `logo2.bmp`, `logo3.bmp` | Board | Boot logos |

### Build note
`build_rootfs.sh` (`install_scripts` → `process_utils`) already copies this entire directory into
`rootfs/etc/config/` verbatim. `settings.json` / `installed_apps.json` / `weather.json` no longer get
a second, separate copy from a top-level project `config/` folder — that duplicate source has been
deleted; keeping two copies in sync was the original source of drift risk.

### Second consolidation pass (this change)
Building on the pass above, the following were folded into `settings.json` and their standalone
files deleted:
- **`app_gui_config.ini`** → `settings.json` `language.id` (already the *primary* source read by
  `gui_common.c`/`tablet_common.c`'s `app_lv_read_config()`; the ini was only ever the legacy
  fallback) and `settings.json` `wifi.ssid`/`wifi.psk`/`wifi.auto_connect` (the "remember this
  network" credentials the Settings WiFi screen used to persist in the ini's `[wifi]` section).
  `tablet_setting_wifi.c`'s `wifi_load_saved_credentials()`/`wifi_save_credentials()` now
  read/write `settings.json` directly, encrypting `psk` with the same `wifi_psk_encrypt`/
  `wifi_psk_decrypt` (`enc:v1:` AES-128-CBC+Base64) helpers Luna's `network.c` uses — that header
  (`wifi_cred_crypto.h`) is now installed publicly by `framework/services/network/Makefile` so
  application code can include it, and `packages/tablet/Makefile` links `libnetwork.so` into
  `libsetting_app.so` explicitly (a real symbol reference now, not just an ops-struct function
  pointer, so it cannot rely on `app_main`'s deferred/lazy `dlopen(libnetwork.so)` having already
  happened by the time Settings is opened).
- **`hal_wifi_config.ini`** → deleted. Its only actually-read field across all of
  application/framework/scripts was `[station] enable` (gates `wifi_station_ensure_init()`); that
  is now `settings.json` `wifi.enable` (primary), with the ini kept as a fallback code path in
  `tablet_setting_wifi.c` for boards that still ship the file. The other fields
  (`ability`, `sta_ssid`/`sta_pwd`, `ap_ssid`/`ap_pwd`) were never read by any C code or by
  `wifi_driver.sh` (which starts wpa with a minimal runtime `wpa_supplicant.conf` stub;
  STA ssid/psk come from `settings.json`; HAL rewrites the conf on connect / AP from
  `hostapd.conf` instead) — pure dead weight, not carried forward.
- **`fw_identity_config.ini`, `fw_dormancy_config.ini`** → `settings.json` `device.id` and
  `dormancy.server_ip`/`dormancy.server_port` respectively. This is framework-shared code
  (`framework/gateway/nebula_protocol/src/nebula_common.c`), so both reads now try `settings.json`
  first and fall back to the legacy ini files (which stay supported, just no longer shipped for
  Nova) — no other product is affected.
- **`isp.ini`, `system.ini`** → deleted outright (not merged anywhere). Neither file, nor any of
  their keys/macros (`ISP_CONFIG_FILE`, `SYSTEM_CONFIG_FILE`, `SYSTEM_CONFIG_BACKLIGHT_SECTION`),
  was ever referenced by any C source, Makefile, or boot script in `application`/`framework`/
  `project`. `isp.ini`'s `flip_mode`/`isp_path` are dead duplicates of the fields actually used —
  `hal_camera_config.ini`'s `[camera0]` `mirror`/`flip`/`isp_config_path` (that file even has a
  code comment: "VPSS tuning binary ... not isp.ini"). `system.ini`'s `[backlight] level` has no
  reader either — the framework `backlight_ops_t` device exists but nothing in `application` calls
  `->backlight->set_value()` gated by this file.

### Third consolidation pass (this change)
- **`fw_wlan_config.ini`** → deleted outright, same treatment as Luna's `wifi_config.ini`. It was
  only ever a *legacy fallback* filename inside `network.c` (`WIFI_CONFIG_FILE_FALLBACK`) and
  `network_compat.c` (`WLAN_CONFIG_FILE_FALLBACK`), both gated behind "no `wifi{}` object found in
  `settings.json`" — and `settings.json` `wifi{}` has existed for Nova since the first consolidation
  pass above. On top of that, neither fallback's call site is even reachable from Nova's tablet code:
  `network.c`'s `connect_from_config()` is only invoked by `wearable_clock.c` (wearable/Luna), and
  `network_compat.c`'s `network_init`/`network_enable`/`network_set_connect`/`network_is_connected`
  have zero callers anywhere in `application`. So the file's real `[station] ssid`/`psk` values were
  already dead on Nova before this change; they were not ported anywhere. The unused
  `WLAN_CONFIG_FILE`/`WLAN_CONFIG_STATION_SECTION`/`WLAN_CONFIG_SSID`/`WLAN_CONFIG_PSK` macros were
  also removed from `app_product_config.h` (they were never referenced outside their own
  definition). The `network.c`/`network_compat.c` fallback code paths themselves are left in place
  unchanged — they are shared framework code still needed by Luna/other boards that may ship the
  file.

### Still not consolidated (intentionally left as-is)
Remaining HAL/framework INI/JSON under this folder (`fw_*`, `hal_*`, `audio_config.ini`, ISP
blobs) stay standalone. `storage_mode.ini` and `media.ini` were folded into `settings.json`
(`storage.mode` 0/1, `media.audio_path`/`video_path`) and deleted; readers keep a short legacy
fallback for old images that still ship those files. `wpa_supplicant.conf` is no longer shipped
(STA creds in `settings.json` `wifi{}`; runtime stub + HAL rewrite). `installed_apps.json` /
`fw_osd_config.json` were folded earlier.
