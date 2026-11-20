# Open-source tiers in `project`

Source and config in this repository are **tier A, Apache-2.0**. See [LICENSE](LICENSE).

The prebuilt files listed in [NOTICE](NOTICE) are **tier C**. They stay in the tree so a product can boot, and they are not Apache-2.0. Owners and terms stay with Anyka or the commercial SDK vendor. Do not relicense them.

Tier C is the overlay under each product: `*.ko`, `*.so`, `*.a`, models (`model_*.bin`), bitmap fonts (`ak_font_16.bin`), and burn images (`*.img`, DDR init `*.bin`). The chip SDK itself (`system/AnyCloud*`, `system/Sky39AV130` at the workspace root) is **tier D** and is not in git.

Wi-Fi fields stay empty or `YOUR_WIFI_PSK`. Cloud ini files stay `YOUR_*` / `${VOLC_*}`.

本仓库源码和配置是 **A 级 Apache-2.0**。`NOTICE` 里列出的预编译文件是 **C 级**：留在树里，供产品启动，但不适用 Apache-2.0，也不能再许可成 Apache-2.0。工作区根上的芯片 SDK 是 **D 级**，不在 git 里。
