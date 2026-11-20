<p align="right"><a href="README.en.md">English</a> | <b>中文</b></p>

# Celestia · project

各产品的工程配置与打包入口。

| 产品 | SoC / SDK | 形态 |
|------|-----------|------|
| `anypi_nova` | AnyCloud39AV200 / V1.04 | TABLET |
| `anypi_nova_dev` | AnyCloud39AV200 / V1.04 | TABLET（EVB） |
| `anypi_luna` | AnyCloud39AV100_V2 / V2.05 | WEARABLE |
| `anypi_luna_dev` | AnyCloud39AV100_V2 / V2.04 | IOTCamera |
| `anypi_mira_dev` | Sky39AV130 / V1.01 | IOTCamera（AOS） |

每个产品目录包含 `config`、`config.mk`、`include`、`build_soc_system.sh`、`package.sh` 等构建与打包配置。

## 构建

由顶层 `repo` 工程统一构建，使用工程根目录的 `build.sh` 选择对应产品目标。

## 许可

以 **Apache License 2.0** 授权，详见 [LICENSE](LICENSE) 与 [NOTICE](NOTICE)。

> 源码和配置是 **A 级 Apache-2.0**。各产品 overlay 里的 `.ko` / `.so` / `.a`、模型、字库和烧录镜像是 **C 级**：留在本仓库，供板级启动，但不受 Apache-2.0 覆盖，也不能再许可成 Apache-2.0。名单见 [NOTICE](NOTICE)。芯片 SDK（`system/AnyCloud*`、`system/Sky39AV130`）是 **D 级**，不在本仓库。Wi-Fi 口令保持空白或 `YOUR_WIFI_PSK`。详见 [docs/open-source.md](https://github.com/OpenCelestia/docs/blob/main/open-source.md)。

## 贡献

见 [CONTRIBUTING.md](CONTRIBUTING.md)（采用 DCO，提交需 `-s` 签名）。
