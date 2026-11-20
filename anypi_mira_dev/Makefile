# SPDX-License-Identifier: Apache-2.0
# Final Aos user image. app_main objects come from the existing static build.
ANYPI_MIRA_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PROJECT_CONFIG_FILE ?= $(ANYPI_MIRA_DIR)/config.mk
include $(COMPILATION_RULES)
include $(PROJECT_CONFIG_FILE)

IMAGE_DIR ?= $(BUILD_DIR)/system/Sky39AV130/V1.01/image
APP_OBJS := $(wildcard $(BUILD_DIR)/application/app_main/*.o)
IPC_CAM_A := $(APPLICATION_INSTALL_DIR)/lib/libipc_cam_app.a
HARDWARE_A := $(HARDWARE_INSTALL_DIR)/lib/libhardware.a
SYSTEM_CORE_A := $(SYSTEM_CORE_INSTALL_DIR)/lib/libsystem_core.a
FRAMEWORK_A := $(sort $(wildcard $(FRAMEWORK_INSTALL_DIR)/lib/*.a))
NEBULA_A := $(FRAMEWORK_INSTALL_DIR)/lib/libnebula_protocol.a
CJSON_A := $(wildcard $(THIRD_PARTY_INSTALL_DIR)/cjson/lib/*.a)
INIPARSER_A := $(wildcard $(THIRD_PARTY_INSTALL_DIR)/iniparser/lib/*.a)
MBEDTLS_A := $(wildcard $(THIRD_PARTY_INSTALL_DIR)/mbedtls/lib/*.a)
ZXING_A := $(wildcard $(THIRD_PARTY_INSTALL_DIR)/zxing/lib/*.a)
# Aos POSIX additions built from this overlay (dlopen table, getifaddrs,
# netdb gaps, realpath/ftruncate); headers are platform/include/alios/compat.
POSIX_AOS_SRC := $(ANYPI_MIRA_DIR)/system/Sky39AV130/V1.01/platform/src/aos
POSIX_AOS_BUILD := $(BUILD_DIR)/platform/aos_posix
POSIX_AOS_OBJS := $(patsubst %.c,$(POSIX_AOS_BUILD)/%.o,$(notdir $(wildcard $(POSIX_AOS_SRC)/*.c)))
POSIX_AOS_A := $(POSIX_AOS_BUILD)/libaos_posix.a
SOC_PLATFORM_INSTALL_DIR ?= $(abspath $(ANYPI_MIRA_DIR)/../../out/$(notdir $(ANYPI_MIRA_DIR))/install/system/Sky39AV130/V1.01)
PLAT_A := $(wildcard $(SOC_PLATFORM_INSTALL_DIR)/lib/alios/*.a) \
	$(wildcard $(SOC_PLATFORM_INSTALL_DIR)/lib/lib*.a) \
	$(wildcard $(SOC_PLATFORM_DIR)/platform/lib/*.a) \
	$(wildcard $(SOC_PLATFORM_DIR)/platform/lib/*/*.a) \
	$(wildcard $(SOC_PLATFORM_DIR)/platform/dep_lib/*.a) \
	$(wildcard $(SOC_PLATFORM_DIR)/os/dep_lib/libakfat32fs.a) \
	$(wildcard $(SOC_PLATFORM_DIR)/os/dep_lib/libakfatmount.a)
USER_ELF := $(IMAGE_DIR)/user.elf
USER_STRIP := $(IMAGE_DIR)/user.strip.elf
USER_MAP := $(IMAGE_DIR)/user.map

# Match project config.mk / SDK rules.mk (enum ABI must match all .o + libgcc).
USER_LINK_FLAGS := -mcpu=arm926ej-s -mfloat-abi=soft -mlong-calls
USER_LINK_FLAGS += -nostdlib -nostartfiles -static
USER_LINK_FLAGS += -L$(ARM_LIBC_PATH) -L$(ARM_LIBGCC_PATH)
# Route Nebula/ipc_cam getifaddrs/gai_strerror past the SDK lwip_usyscall stubs
# to the implementations in platform/src/aos (libaos_posix.a).
USER_LINK_FLAGS += -Wl,--wrap=getifaddrs -Wl,--wrap=freeifaddrs -Wl,--wrap=gai_strerror

USER_LINKER := $(CC)
ifeq ($(CONFIG_APP_NEBULA),y)
ifeq ($(wildcard $(NEBULA_A)),)
$(error CONFIG_APP_NEBULA=y but missing $(NEBULA_A) — build framework gateway/nebula_protocol first)
endif
ifeq ($(ZXING_A),)
$(error CONFIG_APP_NEBULA=y but missing libzxing.a under $(THIRD_PARTY_INSTALL_DIR)/zxing/lib — build third_party zxing)
endif
# libzxing.a is C++; use the C++ driver for the final link.
USER_LINKER := $(CXX)
endif

FRAMEWORK_LINK := $(FRAMEWORK_A)
USER_LINK_ERR := $(IMAGE_DIR)/user.link.err

$(POSIX_AOS_BUILD)/%.o: $(POSIX_AOS_SRC)/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(POSIX_AOS_A): $(POSIX_AOS_OBJS)
	@mkdir -p $(POSIX_AOS_BUILD)
	$(AR) crs $@ $^

.PHONY: all user.strip.elf

all: user.strip.elf

user.strip.elf: $(USER_STRIP)

$(USER_STRIP): $(APP_OBJS) $(IPC_CAM_A) $(HARDWARE_A) $(SYSTEM_CORE_A) $(POSIX_AOS_A)
	@mkdir -p $(IMAGE_DIR)
	@test -n "$(APP_OBJS)" || { echo "ERROR: no app_main objects under $(BUILD_DIR)/application/app_main"; exit 1; }
	@test -f "$(IPC_CAM_A)" || { echo "ERROR: missing $(IPC_CAM_A)"; exit 1; }
	$(USER_LINKER) $(USER_LINK_FLAGS) \
		-Wl,-T,$(SOC_PLATFORM_DIR)/aos_user.ld -Wl,-Map,$(USER_MAP) -o $(USER_ELF) \
		-Wl,--whole-archive $(APP_OBJS) $(IPC_CAM_A) $(HARDWARE_A) -Wl,--no-whole-archive \
		-Wl,--start-group $(FRAMEWORK_LINK) $(SYSTEM_CORE_A) $(POSIX_AOS_A) $(CJSON_A) $(INIPARSER_A) $(MBEDTLS_A) $(ZXING_A) $(PLAT_A) -Wl,--end-group \
		-Wl,--start-group $(CLIB) -Wl,--end-group \
		-Wl,--gc-sections -Wl,--entry=app_entry 2>$(USER_LINK_ERR); \
	ret=$$?; if [ $$ret -ne 0 ]; then \
		echo "ERROR: user.elf link failed (exit $$ret). Last linker messages:"; \
		tail -n 40 $(USER_LINK_ERR); \
		grep -E 'undefined reference|overflow|does not fit|multiple definition|relocation' $(USER_LINK_ERR) 2>/dev/null | tail -n 20 || true; \
		exit $$ret; \
	fi
	$(STRIP) -o $(USER_STRIP) $(USER_ELF)
	@echo "Linked $(USER_STRIP)"
