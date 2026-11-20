# SPDX-License-Identifier: GPL-2.0
# anypi_nova_dev ActionCam: only build the ACTION device tree.
# The board overlay ships km02x's dtsi set (ak_km02-common/norflash/ak_lcd/pinctrl),
# which is self-consistent with EVB_CBDM_KM02X_ACTION_*.dts. Other SDK dts are left
# unregistered to avoid mixing them with the overridden (ActionCam) dtsi.
# U-Boot keeps its own stock DTB (EVB_CBDM_KM02X_V1.0.0) via build_uboot.
dtb-$(CONFIG_SOC_ANYKA) += EVB_CBDM_KM02X_ACTION_V1.0.1.dtb
dtb-$(CONFIG_SOC_ANYKA) += EVB_CBDM_KM02X_ACTION_FASTSYS_V1.0.0.dtb
