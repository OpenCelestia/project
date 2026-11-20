# Mira overlay for Sky39AV130 V1.01 — do not edit vendor system/Sky39AV130.
_MIRA_RULES_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
_SDK_ROOT := $(_MIRA_RULES_DIR)/../../../../../system/Sky39AV130/V1.01
_SDK_RULES := $(_SDK_ROOT)/rules.mk
KERNEL_EXPORT_INC ?= $(_SDK_ROOT)/platform/include
include $(_SDK_RULES)

CROSS_COMPILE   ?= $(CROSS_PREFIX)
CROSS_TOOLCHAIN ?= $(CROSS_PATH)/bin/arm-none-eabi
BUILD_SHARED    ?= n

export CC CXX AS AR LD STRIP OBJCOPY OBJDUMP SIZE

# POSIX additions live inside this overlay's platform/include/alios/compat,
# next to the SDK's external/ headers; -I order: compat -> SDK external -> libc.
AOS_COMPAT_INC := $(abspath $(_MIRA_RULES_DIR)/platform/include/alios/compat)
# First -I: the same POSIX includes resolve to the Sky39AV130 compat additions on this product only.
INCLUDE := -I$(AOS_COMPAT_INC) $(filter-out -I$(AOS_COMPAT_INC),$(INCLUDE))
CFLAGS := -I$(AOS_COMPAT_INC) $(filter-out -I$(AOS_COMPAT_INC),$(CFLAGS))
# Celestia sources use KERNEL_AOS (see project config.mk).
CFLAGS += -DKERNEL_AOS
# ak_vpss_struct.h / ak_common_audio.h pick the AV130 layout from this macro.
CFLAGS += -D__CHIP_AK3918AV130_SERIES
# Aos motor ioctl headers (motor.c uses motor_ioctl.h when CONFIG_OS_LINUX is unset).
CFLAGS += -I$(_SDK_ROOT)/os/driver/include
