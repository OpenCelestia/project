<p align="right"><b>English</b> | <a href="README.md">中文</a></p>

# Celestia · project

Per-product configuration and packaging.

| Product | SoC / SDK | Form factor |
|---------|-----------|-------------|
| `anypi_nova` | AnyCloud39AV200 / V1.04 | TABLET |
| `anypi_nova_dev` | AnyCloud39AV200 / V1.04 | TABLET (EVB) |
| `anypi_luna` | AnyCloud39AV100_V2 / V2.05 | WEARABLE |
| `anypi_luna_dev` | AnyCloud39AV100_V2 / V2.04 | IOTCamera |
| `anypi_mira_dev` | Sky39AV130 / V1.01 | IOTCamera (AOS) |

Each product directory has `config.mk`, headers, and the board overlay used by the package scripts.

## Build

Select the product from the workspace root:

```bash
./build.sh --product-name anypi_nova
```

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).

Sources and config are **tier A, Apache-2.0**. Overlay `.ko` / `.so` / `.a` files, models, fonts, and burn images are **tier C**: they stay in this repository so a board can boot, they are not covered by Apache-2.0, and they must not be relicensed as Apache-2.0. The list is in [NOTICE](NOTICE). The chip SDK (`system/AnyCloud*`, `system/Sky39AV130`) is **tier D** and is not in this repository. Wi-Fi passphrases stay empty or `YOUR_WIFI_PSK`. See [open-source risks](https://github.com/OpenCelestia/docs/blob/main/open-source.en.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Commits use the DCO (`git commit -s`).
