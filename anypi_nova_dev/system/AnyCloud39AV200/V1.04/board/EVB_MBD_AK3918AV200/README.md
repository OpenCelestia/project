# EVB_MBD_AK3918AV200 — board notes

## `rootfs/utils/etc/config/` inventory (Nova dev / EVB)

Installed flat to `/etc/config/` (`process_utils`). Do not add subfolders — HAL/framework/app code hardcode filenames.

`anypi_nova_dev` shares the same `application/` tablet code as `anypi_nova` (`CONFIG_APP_PACKAGES_TABLET=y`),
just built for the `EVB_MBD_AK3918AV200` bring-up board with a different `CONFIG_APP_MAIN_TARGET`
(`nova_main` vs `ipc_main`). Config layout mirrors Nova — see
`project/anypi_nova/system/AnyCloud39AV200/V1.04/board/PDB_MBD_AK3918AV200_ACTCAM/README.md` for the
full per-file table; only the differences are called out here.

This directory is the **single source of truth**. The old top-level `project/anypi_nova_dev/config/`
mirror (`settings.json` / `installed_apps.json` / `weather.json`) has been removed. `build_rootfs.sh`
now patches `settings.json`'s `"program"` field **in place** on this file (staged into `utils/etc/config/`
by the board overlay) instead of copying a separate top-level copy over it; `process_utils` deploys the
rest of this directory (including `installed_apps` inside `settings.json`, and `weather.json`) verbatim.

### Runtime
- `settings.json` → `installed_apps` holds the app list (folded in from the old standalone
  `installed_apps.json`, which has been deleted — `tablet_app_registry.c` already prefers `settings.json`).
- `settings.json` → `"program"` starts empty in the repo copy; `package.sh` / `build_rootfs.sh` fill it
  in with `/usr/sbin/$CONFIG_APP_MAIN_TARGET` at build time.

### Config consolidation (matching Nova)
Applied the same consolidation pass as `anypi_nova` (see its README for full rationale — only the
outcome is summarized here):
- **`app_gui_config.ini`** → deleted; `language.id` and WiFi credentials (`ssid`/`psk`/
  `auto_connect`) folded into `settings.json`. `modules.gui_tablet.config_path` now points at
  `settings.json` itself (`tablet_setting_wifi.c`/`tablet_common.c` already prefer `settings.json`
  over the ini, shared application code with Nova).
- **`hal_wifi_config.ini`** → deleted; only its `[station] enable` field was ever read (now
  `settings.json` `wifi.enable`). The dead `sta_ssid`/`sta_pwd`/`ap_ssid`/`ap_pwd`/`ability` fields
  were not carried forward (unread by any C code or `wifi_driver.sh`).
- **`fw_identity_config.ini`, `fw_dormancy_config.ini`** → deleted; `device.id` and
  `dormancy.server_ip`/`dormancy.server_port` folded into `settings.json` (read/written by the
  shared `framework/gateway/nebula_protocol/src/nebula_common.c`, which tries `settings.json` first
  and still supports the legacy ini names for boards that ship them — just not this one anymore).
- **`system.ini`, `isp.ini`** → deleted outright, unreferenced by any C source/Makefile/boot script.
- **`fw_wlan_config.ini`** → deleted, same treatment as Luna's `wifi_config.ini`. It was only a
  legacy fallback filename inside `network.c`/`network_compat.c`, both gated behind "no `wifi{}` in
  `settings.json`" (which has existed here since the first pass) — and neither fallback call site
  (`connect_from_config()` / `network_compat.c`'s API) is even reachable from the tablet code this
  board runs (wearable-only / zero application callers respectively).
- `media.ini` and `wpa_supplicant.conf` remain standalone (same reasons as Nova: actively
  read/written outside the `settings.json` path, or consumed directly by a non-JSON-aware binary).
- The now-unused `SYSTEM_CONFIG_FILE`/`SYSTEM_CONFIG_BACKLIGHT_SECTION`, `WLAN_CONFIG_FILE` (+
  section/key macros), and `ISP_CONFIG_FILE` macros were removed from both
  `include/app_product_config.h` and `include/app_globle_config.h` (the latter had its own
  duplicate, unguarded copies of these defines that Nova's already-cleaned header doesn't have).

`fw_osd_config.json` **was** folded into `fw_video_config.json` (`osd_time`/`osd_text`/`osd_logo` keys)
and deleted, matching Nova — `osd_manager.c` reads OSD exclusively from `fw_video_config.json`, so the
standalone file was unread dead weight.

### package.sh fix
`install_celestia_app_main()` in `package.sh` still pointed `rt_src` at the retired top-level
`anypi_nova_dev/config/settings.json` (deleted) instead of the board path. It was unreachable dead code
for this platform (AV200's real "program" patch happens in `build_rootfs.sh`, which already used the
board path), but has been corrected to use the same `runtime_config_dir_from_proj()` helper as
`anypi_luna_dev/package.sh` for consistency, in case this function is ever wired in.
