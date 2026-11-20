# SPDX-License-Identifier: GPL-2.0
include $(PROJECT_CONFIG_FILE)


ifeq ($(CONFIG_CELESTIA_FASTSYS),y)
	ifeq ($(CONFIG_BOARD_SUPPORT_LCD),y)
		ifeq ($(CONFIG_BOARD_SUPPORT_DMIC),y)
			dtb-$(CONFIG_SOC_ANYKA) += EVB_CBDM_KM02X_FASTSYS_LCD_DMIC_V1.0.0.dtb
		else
		dtb-$(CONFIG_SOC_ANYKA) += EVB_CBDM_KM02X_FASTSYS_LCD_V1.0.0.dtb
		endif
	endif
else
	ifeq ($(CONFIG_BOARD_SUPPORT_LCD),y)
		ifeq ($(CONFIG_BOARD_SUPPORT_DMIC),y)
			dtb-$(CONFIG_SOC_ANYKA) += EVB_CBDM_KM02X_LCD_DMIC_V1.0.0.dtb
		else
			dtb-$(CONFIG_SOC_ANYKA) += EVB_CBDM_KM02X_LCD_V1.0.0.dtb
		endif
	else
		dtb-$(CONFIG_SOC_ANYKA) += EVB_CBDM_KM02X_V1.0.0.dtb
	endif
endif
