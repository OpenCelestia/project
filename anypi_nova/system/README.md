# anypi_nova_dev system overlay

平台：`AnyCloud39AV200` / SDK 版本：**V1.04**（与 `km02x_action_camera_yd`、SDK `AnyCloud39AV200_SDK_V1.04` 一致）。

板级：`board/PDB_MBD_AK3918AV200_ACTCAM`（KM02X ACTION 运动相机板）。

目录：`project/anypi_nova_dev/system/AnyCloud39AV200/V1.04/`（`board/` + `patch/`）。

## 硬件基准

以 `km02x_action_camera_yd` 为准：OV8856 / ST7262 800×480 / GT911 / 单 MIC / NOR / NORMAL 启动。

## 设备树与烧录（与 km02x burntool 一致）

| 阶段 | 名称 | 说明 |
|------|------|------|
| DTS 源 | `EVB_CBDM_KM02X_ACTION_V1.0.1.dts` | `board/.../boot/dts/anyka/` |
| 内核编译 | `EVB_CBDM_KM02X_ACTION_V1.0.1.dtb` | `anyka/Makefile` 仅注册此项 |
| 烧录 | 同上 `.dtb` | `patch/tools/burntool/burn.ini` → `config_av200_256MB_action_camera_spinor.txt` → `download_to_nand4` |
| U-Boot 编译 | `EVB_CBDM_KM02X_V1.0.0` | `board/config.mk` 的 `CONFIG_DTB_NAME`，**不要**改成 ACTION |

DTB 仅在 `board/PDB_MBD_AK3918AV200_ACTCAM/config.mk` 配置（与 anypi_luna 一致）：`CONFIG_DTB_NAME`（U-Boot）、`CONFIG_KERN_DTB_NAME`（内核/烧录）。

## 目录

- `board/PDB_MBD_AK3918AV200_ACTCAM/`：板级 config、ACTION DTS+dtsi、rootfs。
- `patch/`：OV8856 脚本与模块、burntool（含 900MHz DDR bin）、平台库等。
- 快启工程使用 `patch_fastsys/`（SPL、env、burntool **16MB** 分区、快启 rootfs 覆盖）。

## usr.sqsh4 / install/ 分离（U 盘外挂库）

为缩小烧录到 Flash 的 `usr.sqsh4`（避免 APP 分区过大导致下载失败）：

1. **打包**：`prepare_install_pack_and_exclude_list`（`patch/scripts/build_rootfs.sh`）将 `utils/usr` 下 `.so` 收集到 `install/lib/`，`stage_tslib_to_install` 将 `libts.so` 与插件打入 `install/lib/ts/`，`utils/usr/model` 打入 `install/model/`（设备上 `/mnt/install/model/`），并将 `rootfs/ipc_main` 拷入 `install/ipc_main`；生成 `install.exclude` 供 `usr.sqsh4` 排除。`create_squashfs.sh` 生成 `install/`；若已打入 install，则 **不再** 把 `ipc_main` 写入 `data.sqsh4` / `usr.sqsh4`。
2. **发布**：`install/` 复制到 `image/` 供拷到 **SD 卡根目录**，**不写入 burntool/Flash**（16MB NOR 无 install 分区）。
3. **启动**：`main.sh` 挂 `/mnt` → loop 挂 `/mnt/install/` 到 `/mnt/install`，设置 `LD_LIBRARY_PATH`、`TSLIB_PLUGINDIR=/mnt/install/lib/ts` 与 `PATH`。`settings.json` 中 `program` 为 `/mnt/install/ipc_main`。触屏配置 `ts.rgb.conf` / `ts_calibrate.rgb.conf` 仍在 Flash `/etc/config/`。
4. **字库**：OSD `ak_font_16.bin` 放在 `board/.../rootfs/utils/usr/gui/font/`，打进 `usr.sqsh4` → 设备路径 `/usr/gui/font/ak_font_16.bin`（与 Luna/Nova 一致；不进 `/etc/config`，也不进 install）。
