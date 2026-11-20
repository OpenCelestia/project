# SPDX-License-Identifier: Apache-2.0
include $(COMPILATION_RULES)

PROJ = $(PROJECT_NAME)

MODULE_ROOT ?= $(shell pwd)

# BUILD_DIR can be passed from build.sh (e.g., out/build/project)
# If not provided, use local build directory
BUILD_DIR ?= $(MODULE_ROOT)/build

SRC_DIR = $(shell find $(MODULE_ROOT)/src -maxdepth 3 -type d)

CSRCS = $(foreach d, $(SRC_DIR), $(wildcard $d/*.c))
CXXSRCS = $(foreach d, $(SRC_DIR), $(wildcard $d/*.cpp))

OBJS = $(patsubst %.c, %.o, $(CSRCS))
OBJS += $(patsubst %.cpp, %.o, $(CXXSRCS))

TARGET :=

ifeq ($(CONFIG_OS_NAME), linux)
CFLAGS += -DOS_NAME_LINUX=1
TARGET += $(BUILD_DIR)/$(PROJ)
else
STATIC_LIB := lib$(PROJ).a
TARGET += $(BUILD_DIR)/$(STATIC_LIB)
endif

CFLAGS += -D$(CONFIG_SOC_PLATFORM)

INCLUDE += -I$(SOC_PLATFORM_DIR)/platform/include
INCLUDE += -I$(MODULE_ROOT)/include
LIBS += $(shell find $(SOC_PLATFORM_DIR)/platform/lib/ -maxdepth 1 -name *.a)

HARDWARE_INCLUDE := $(HARDWARE_INSTALL_DIR)/include
INCLUDE += -I$(HARDWARE_INCLUDE)
LIBS += $(shell find $(HARDWARE_INSTALL_DIR)/lib/ -maxdepth 1 -name *.a)

# related to system_core (needed for iniparser_extend, circular_buffer, log, time_utils functions)
INCLUDE += -I$(SYSTEM_CORE_INSTALL_DIR)/include
LIBS += $(shell find $(SYSTEM_CORE_INSTALL_DIR)/lib/ -maxdepth 1 -name libsystem_core.a)

FRAMEWORK_COMMON_INSTALL_DIR := $(FRAMEWORK_INSTALL_DIR)/common
INCLUDE += -I$(FRAMEWORK_COMMON_INSTALL_DIR)/include
LIBS += $(shell find $(FRAMEWORK_COMMON_INSTALL_DIR)/lib -maxdepth 1 -name *.a)

# related to backlight
BACKLIGHT_INSTALL_DIR := $(FRAMEWORK_INSTALL_DIR)/backlight
INCLUDE += -I$(BACKLIGHT_INSTALL_DIR)/include
LIBS += $(shell find $(BACKLIGHT_INSTALL_DIR)/lib/ -maxdepth 1 -name lib*.a)

# related to freetype
FREETYPE_INSTALL_DIR := $(THIRD_PARTY_INSTALL_DIR)/freetype
INCLUDE += -I$(FREETYPE_INSTALL_DIR)/include/freetype2
LIBS += $(shell find $(FREETYPE_INSTALL_DIR)/lib/ -maxdepth 1 -name lib*.a)

# related to lvgl
LVGL_INSTALL_DIR := $(THIRD_PARTY_INSTALL_DIR)/lvgl
INCLUDE += -I$(LVGL_INSTALL_DIR)/include
INCLUDE += -I$(LVGL_INSTALL_DIR)/include/src/libs/freetype
LIBS += $(shell find $(LVGL_INSTALL_DIR)/lib/ -maxdepth 1 -name lib*.a)

# related to lv-drivers
LV_DRIVERS_INSTALL_DIR := $(FRAMEWORK_INSTALL_DIR)/lv-drivers
INCLUDE += -I$(LV_DRIVERS_INSTALL_DIR)/include
LIBS += $(shell find $(LV_DRIVERS_INSTALL_DIR)/lib/ -maxdepth 1 -name lib*.a)

# related to tslib
TSLIB_INSTALL_DIR := $(THIRD_PARTY_INSTALL_DIR)/tslib
INCLUDE += -I$(TSLIB_INSTALL_DIR)/include
LIBS += $(shell find $(TSLIB_INSTALL_DIR)/lib/ -maxdepth 1 -name lib*.a)


# related to zlib
ZLIB_INSTALL_DIR := $(THIRD_PARTY_INSTALL_DIR)/zlib
INCLUDE += -I$(ZLIB_INSTALL_DIR)/include
LIBS += $(shell find $(ZLIB_INSTALL_DIR)/lib/ -maxdepth 1 -name lib*.a)

# related to libpng
LIBPNG_INSTALL_DIR := $(THIRD_PARTY_INSTALL_DIR)/libpng
INCLUDE += -I$(LIBPNG_INSTALL_DIR)/include
LIBS += $(shell find $(LIBPNG_INSTALL_DIR)/lib/ -maxdepth 1 -name lib*.a)

# related to iniparser
INIPARSER_INSTALL_DIR := $(THIRD_PARTY_INSTALL_DIR)/iniparser
INCLUDE += -I$(INIPARSER_INSTALL_DIR)/include
LIBS += $(shell find $(INIPARSER_INSTALL_DIR)/lib/ -maxdepth 1 -name lib*.a)

# related to application
INCLUDE += -I$(APPLICATION_INSTALL_DIR)/include
LIBS += $(shell find $(APPLICATION_INSTALL_DIR)/lib/ -maxdepth 1 -name lib*.a)

FRAMEWORK_INPUT_INSTALL_DIR := $(FRAMEWORK_INSTALL_DIR)/input
INCLUDE += -I$(FRAMEWORK_INPUT_INSTALL_DIR)/include
LIBS += $(shell find $(FRAMEWORK_INPUT_INSTALL_DIR)/lib -maxdepth 1 -name *.a)

# related to project
INCLUDE += -I$(PROJECT_DIR)/include

#CFLAGS += -Werror -lstdc++ -lc -lpthread
#CFLAGS += $(INCLUDE)

XFLAGS := -lstdc++ -lc -lpthread
#XFLAGS += -std=c99 -mlittle-endian -fno-builtin -O2 $(DEFINE) $(INCLUDE) $(GLB_INCLUDE)

#LD_FLAGS = -Xlinker "-(" $(LIBS) -Xlinker "-)" -L$(LIB_DIR)
LD_FLAGS = -Xlinker "-(" $(LIBS) -Xlinker "-)"

$(shell mkdir -p $(BUILD_DIR))
	
##build rule
.PHONY: all target clean

all: target

target: $(TARGET)
ifeq ($(CONFIG_OS_NAME), linux)
$(TARGET): $(OBJS)
	$(CC) $(OBJS) $(XFLAGS) $(LD_FLAGS) -o $@
	$(STRIP) $(TARGET)
else
$(TARGET): $(OBJS)
	$(AR) -rsv $(TARGET) $(OBJS)
endif

ifeq ($(CONFIG_OS_NAME), linux)
	cp $(BUILD_DIR)/$(PROJ) $(PLATFORM_INSTALL_DIR)/bin/
else
	cp $(BUILD_DIR)/$(STATIC_LIB) $(PLATFORM_INSTALL_DIR)/bin/
endif

clean:
	@echo "Cleaning project build files..."
	$(RM) -rf $(BUILD_DIR)
	@# Clean any leftover files in source directory
	@find $(MODULE_ROOT)/src -name "*.o" -type f -delete 2>/dev/null || true
	@find $(MODULE_ROOT)/src -name "*.d" -type f -delete 2>/dev/null || true
	@find $(MODULE_ROOT)/src -name "*.a" -type f -delete 2>/dev/null || true
