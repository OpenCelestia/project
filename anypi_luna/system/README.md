# KM01W project: `system/` directory overview

PDK base: `system/AnyCloud39AV100_V2/V2.05/` (vendor SDK, same as anypi_luna_mi). Luna deltas: `V2.04_luna` (historical source tree) → project overlay under `V2.05/` (ported from `V2.04/` when the project moved to V2.05, 2026-09).

## Layout (same idea as anypi_nova `V1.03/`)

| Path | Role |
|------|------|
| `V2.05/board/PDB_MBD_KM01W_ACTCAM/` | Board `config.mk`, `README.md` (Product vs Runtime fields in one app JSON), `rootfs/utils/etc/config/*` (`settings.json`, `hal_*` / `fw_*`, boot), `app_01_start.sh`, …) |
| `V2.05/patch/` | Celestia overlay copied by `build_soc_system.sh` (`scripts/`, `rootfs/`, `platform/`, …) |
| `V2.04/` | Previous overlay baseline (kept for reference; no longer used by the build) |
| `scripts_temp/` | Reference SDK scripts for this chip (source for `patch/scripts/`) |

## Rootfs config flow

1. `SOC_PATCH_DIR` → `board/.../rootfs/utils` (INI/JSON and app scripts)
2. `PROJECT_PATCH_UTILS` → `patch/rootfs/utils` (`main.sh`, `service.sh`, …)
3. `build_rootfs.sh` `process_utils` → `cp utils/* rootfs/` → `/etc/config/` on device

### Product vs Runtime (all under `/etc/config`)

| Class | Files | Mutable at runtime? |
|-------|-------|---------------------|
| Product fields | `settings.json` (`program`, `launch_mode`, `modules`, `wifi`), `fw_*`, `hal_*` | Prefer leave as board defaults |
| Runtime fields | Same `settings.json` (`language`, `wifi`, `installed_apps`) | Yes — apps / framework RMW (must not wipe product/boot keys) |

See `V2.05/board/PDB_MBD_KM01W_ACTCAM/README.md` for the full inventory. See `V2.05/patch/README.md` for the patch tree.
