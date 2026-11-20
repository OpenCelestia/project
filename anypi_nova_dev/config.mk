# SPDX-License-Identifier: Apache-2.0
############################################################
## SOC and Board Configuration
############################################################
# Target platform (AnyCloud39AV100, AnyCloud39EV330, AnyCloud37E, SkyAV100, Sky37Ev2)
# Corresponding directory: system/$CONFIG_SOC_PLATFORM/$CONFIG_SDK_VERSION
CONFIG_SOC_PLATFORM = AnyCloud39AV200

# SDK version
CONFIG_SOC_SDK_VERSION = V1.04

# Target OS (linux, rtt, aos)
CONFIG_OS_NAME = linux

# Target board
# Corresponding directory: system/$CONFIG_SOC_PLATFORM/$CONFIG_SDK_VERSION/board/$CONFIG_BOARD
CONFIG_BOARD = EVB_MBD_AK3918AV200

# Board feature support
CONFIG_BOARD_SUPPORT_DMIC = y
CONFIG_BOARD_SUPPORT_LCD = y

# LCD logical resolution (SSOT)
CONFIG_LCD_HOR_RES = 1024
CONFIG_LCD_VER_RES = 600
# System fast boot (only select one)
CONFIG_CELESTIA_FASTSYS = y

############################################################
## Application Layer Configuration
############################################################
# Application layer modules configuration

# ============================================================
# Main Application
# ============================================================
# App main: unified application entry point (application/app_main/), produces main executable
CONFIG_APP_MAIN_ENTRY = y
# Main executable name (read by app_main Makefile); deployed to /usr/sbin/
CONFIG_APP_MAIN_TARGET ?= nova_main
# Runtime .so deployment allowlist (other optimization flags use module defaults)
# iconv: SDK libhardware/libmultimedia need libiconv.so.2 at runtime (same as anypi_luna allowlist).
# libwebsockets: deploy .so only; ipc_main must not static-link libwebsockets.a (OpenSSL shim clash).
# curl/wss via mbedtls — drop openssl from rootfs (align Luna).
CONFIG_THIRD_PARTY_SO_ALLOWLIST = zxing cjson curl zlib iniparser iconv lvgl libwebsockets mbedtls

# ============================================================
# Cloud Services
# ============================================================
CONFIG_APP_CLOUD_TUYA = n
# Volc RTC sources stay under application/cloud/volc_engine as an integration
# reference and are not built. Set this and CONFIG_APP_TABLET_VOLC_ENGINE back
# to y to build them.
CONFIG_APP_CLOUD_VOLC = n
# Note: CONFIG_APP_CLOUD_ALIYUN is defined in cloud/aliyun/Makefile

# Cloud Link Support (for OTA encrypted firmware)
# CFG_CLOUD_LINK will be automatically generated if any cloud service is enabled
# Used in framework/runtime/ota/ota.c for mbedtls encryption support
CONFIG_FW_RUNTIME_OTA_CLOUD_LINK = n

# ============================================================
# Protocol Modules
# ============================================================
CONFIG_APP_RTSP = y
CONFIG_APP_NEBULA = y
CONFIG_APP_UVC = n
CONFIG_APP_WEATHER = y

# ============================================================
# GUI Applications
# ============================================================
CONFIG_APP_PACKAGES_TABLET = y
CONFIG_APP_PACKAGES_WEARABLE = n
CONFIG_APP_PACKAGES_IPCAMERA = n

# ============================================================
# Tablet GUI independent apps (enable/disable per app)
# ============================================================
CONFIG_APP_TABLET_IPC_CAMERA = y
CONFIG_APP_TABLET_CAMERA = y
CONFIG_APP_TABLET_AUDIO_ALGO = y
CONFIG_APP_TABLET_SETTING = y
# Tablet Volc app stays in the tree as an integration reference and is not built.
CONFIG_APP_TABLET_VOLC_ENGINE = n

# ============================================================
# Tablet demo modules in launcher (also reflected in app_globle_config.h)
# Setting to n here excludes the .c file from compilation (Makefile) AND guards
# the menu entry at runtime (app_globle_config.h #define).
# ============================================================
# Qwen AI chat: off (no server endpoint configured for this product).
CONFIG_APP_TABLET_LV_DEMO_QWEN = n
# Music / Video: not implemented; keep off.
CONFIG_APP_TABLET_LV_DEMO_MUSIC = n
CONFIG_APP_TABLET_LV_DEMO_VIDEO = n

# C preprocessor: export config.mk switches to GUI compile (see application/packages/tablet/Makefile).
CONFIG_PROJECT_CFLAGS :=

############################################################
## Framework Layer Configuration
############################################################
# Framework layer modules configuration

# ============================================================
# Core Framework Modules
# ============================================================
CONFIG_FW_SYSTEM = y

# ============================================================
# Runtime Framework Submodules
# ============================================================
# Note: bootstrap, console, security, ota are currently always compiled
#       If selective compilation is needed, uncomment and use these configs:
# Runtime optional modules (recommended enabled for production, disable per product line)
CONFIG_FW_RUNTIME_BOOTSTRAP = y
CONFIG_FW_RUNTIME_CONSOLE = y
# CONFIG_FW_RUNTIME_SECURITY = y
# CONFIG_FW_RUNTIME_OTA = y
CONFIG_FW_RUNTIME_WATCHDOG = n
CONFIG_FW_RUNTIME_POWER_BUTTON = n
# ============================================================
# Multimedia Framework
# ============================================================
CONFIG_FW_MULTIMEDIA = y
CONFIG_FW_MULTIMEDIA_MEDIA_PLAYER = y
CONFIG_FW_MULTIMEDIA_MEDIA_RECORDER = y
CONFIG_FW_MULTIMEDIA_AUDIO_PLAYER = y
CONFIG_FW_MULTIMEDIA_AUDIO_RECORDER = y
CONFIG_FW_MULTIMEDIA_STREAM_PLAYER = y
CONFIG_FW_MULTIMEDIA_STREAM_RECORDER = y
# Nebula/call SW H.264 decode (no MPI VDEC on AV200); file demux excluded.
CONFIG_FRAMEWORK_MULTIMEDIA_FFMPEG_LINK_MODE = decode
# Play/Record master switch (for product trimming)
CONFIG_FW_MULTIMEDIA_PLAY = y
CONFIG_FW_MULTIMEDIA_RECORD = y
# Multimedia fine-grained switches (disable as needed for production)
CONFIG_FW_MULTIMEDIA_CAMERA = y
CONFIG_FW_MULTIMEDIA_CAMERA_AI = y
CONFIG_FW_MULTIMEDIA_CAMERA_OSD = y
CONFIG_FW_MULTIMEDIA_BROADCAST = y
# av_codec format capability switches (belongs to framework/multimedia, not third_party)
CONFIG_FW_MULTIMEDIA_FORMAT_AVI = y
CONFIG_FW_MULTIMEDIA_FORMAT_MP4 = y
CONFIG_FW_MULTIMEDIA_FORMAT_GIF = n
CONFIG_FW_MULTIMEDIA_FORMAT_MP3 = n

# ============================================================
# GUI Framework
# ============================================================
# GUI framework is split into sub-modules (graphics, lvgl, awtk)
CONFIG_FW_GUI_GRAPHICS = y
CONFIG_FW_GUI_LVGL = y
CONFIG_FW_GUI_AWTK = n

# GUI/LVGL Image Decoder Configuration
# Note: These are automatically enabled based on third_party library selection
# CONFIG_LV_PORT_TINYJPEG - enabled if CONFIG_THIRD_PARTY_JPEGDEC=y
# CONFIG_LV_PORT_LIBPNG - enabled if CONFIG_THIRD_PARTY_LIBPNG=y
# CONFIG_LV_PORT_LIBQOI - always available
# CONFIG_LV_PORT_STBIMAGE - always available

# GUI/LVGL Input Device Configuration
# Note: Currently all input is handled via CONFIG_HW_INPUT
#       These configs are used in code but not in Makefile:
# CONFIG_HW_INPUT_EVDEV_TOUCH - touch input (derived from CONFIG_HW_INPUT)
# CONFIG_HW_INPUT_EVDEV_KEYBOARD - keyboard input (derived from CONFIG_HW_INPUT)

# ============================================================
# Device Framework
# ============================================================
CONFIG_FW_DRIVER = y
CONFIG_FW_DEVICE_BACKLIGHT = y
CONFIG_FW_DEVICE_PTZ = y
CONFIG_FW_DEVICE_IPCAMERA_NIGHTVISION = y
CONFIG_FW_DEVICE_LED = y
CONFIG_FW_DEVICE_POWER = y
# Note: CONFIG_FW_DRIVER_CONFIG is defined but not used in framework/Makefile
#       It may be used in other parts of the system
# Note: IRCut functionality has been merged into night_vision module
# Note: Input subsystem has been migrated to framework/notification/input

# ============================================================
# Network Framework
# ============================================================
CONFIG_FW_NETWORK = y
CONFIG_FW_NETWORK_WIFI = y
CONFIG_FW_NETWORK_ETHERNET = y
CONFIG_FW_NETWORK_RTSP_SERVER = y
# Note: NTP and Ping modules are always compiled (no config required)

# ============================================================
# Notification Framework
# ============================================================
CONFIG_FW_NOTIFICATION = y
CONFIG_FW_NOTIFICATION_INPUT = y
CONFIG_FW_NOTIFICATION_ALARM = y
# Note: CONFIG_FW_NOTIFICATION_DEVICE_STATUS is not currently used in Makefile

# ============================================================
# Storage Framework
# ============================================================
CONFIG_FW_STORAGE = y
CONFIG_FW_STORAGE_FLASH_UTILS = y
CONFIG_FW_STORAGE_TFCARD_UTILS = y
# Note: CONFIG_FW_STORAGE_FILE_UTILS is defined but not used in framework/storage/Makefile
#       File utilities are handled by system/core/file/

# Camera AI: SSOT is CONFIG_FW_MULTIMEDIA_CAMERA_AI (framework/services/multimedia/camera/ai/).
# Do not use CONFIG_FW_AI — not wired in framework/Makefile; Luna/Nova share the same gate.

# ============================================================
# Test and Debug
# ============================================================
CONFIG_FW_TESTS = y

############################################################
## Hardware Layer Configuration
############################################################
# Hardware abstraction layer configuration

# ============================================================
# Core Modules (Always Compiled)
# ============================================================
# Note: soc_platform/ is always compiled (required for platform abstraction)
#       This config is informational only, soc_platform/ is always built in hardware/Makefile
CONFIG_HW_SOC_PLATFORM = y

# ============================================================
# Multimedia Modules
# ============================================================
CONFIG_HW_AUDIO = y
CONFIG_HW_CAMERA = y
CONFIG_HW_DISPLAY = y
CONFIG_HW_GPU = y
CONFIG_HW_OSD = y

# ============================================================
# Vision Modules
# ============================================================
CONFIG_HW_VISION_ISP = y
CONFIG_HW_VISION_MOTION_DETECT = y

# ============================================================
# Network Modules
# ============================================================
CONFIG_HW_WIFI = y
CONFIG_HW_ETHERNET = y
# Note: network/net/ is automatically compiled when WiFi or Ethernet is enabled

# ============================================================
# Input Modules
# ============================================================
CONFIG_HW_INPUT_KEYBOARD = y
CONFIG_HW_INPUT_TOUCH = y

# ============================================================
# Driver Modules
# ============================================================
CONFIG_HW_DRIVER_GPIO = y
CONFIG_HW_DRIVER_ADC = y
CONFIG_HW_DRIVER_PWM = y
CONFIG_HW_DRIVER_MOTOR = y
CONFIG_HW_DRIVER_LED = y
CONFIG_HW_DRIVER_IR = y
CONFIG_HW_DRIVER_WDT = y
CONFIG_HW_DRIVER_EFUSE = y
CONFIG_HW_DRIVER_BLKDEV = y
CONFIG_HW_DRIVER_MMC = y

# ============================================================
# Build and Debug Options
# ============================================================
CONFIG_HW_TEST = y

############################################################
## Third Party Libraries Configuration
############################################################
# Third party libraries and their versions
# Third-party build target arch: arm / riscv
CONFIG_THIRD_PARTY_TARGET_ARCH = riscv

# ============================================================
# GUI Libraries
# ============================================================
CONFIG_THIRD_PARTY_AWTK = n
CONFIG_THIRD_PARTY_AWTK_VERSION = 1.7.1

CONFIG_THIRD_PARTY_LVGL = y
export CONFIG_THIRD_PARTY_LVGL_VERSION = 9.3.0

# ============================================================
# Image Processing Libraries
# ============================================================
CONFIG_THIRD_PARTY_JPEG = y
CONFIG_THIRD_PARTY_JPEG_VERSION = 9e

CONFIG_THIRD_PARTY_JPEGDEC = y
CONFIG_THIRD_PARTY_JPEGDEC_VERSION = 1.4.2

CONFIG_THIRD_PARTY_LIBPNG = y
CONFIG_THIRD_PARTY_LIBPNG_VERSION = 1.6.43

CONFIG_THIRD_PARTY_FREETYPE = y
CONFIG_THIRD_PARTY_FREETYPE_VERSION = 2.12.0

# ============================================================
# Video/Audio Processing Libraries
# ============================================================
CONFIG_THIRD_PARTY_FFMPEG = y
CONFIG_THIRD_PARTY_FFMPEG_VERSION = 7.0
# ffmpeg minimal build (y=enable only common demux/decoder/protocol, significantly reduces libav* size)
CONFIG_THIRD_PARTY_FFMPEG_MINIMAL = y
# Decode-only overrides MINIMAL: H.264 only (no avformat/network) for call downlink size.
CONFIG_THIRD_PARTY_FFMPEG_DECODE_ONLY = y

CONFIG_THIRD_PARTY_LIBH264 = n
CONFIG_THIRD_PARTY_LIBH264_VERSION =

# ============================================================
# Network Libraries
# ============================================================
CONFIG_THIRD_PARTY_CURL = y
CONFIG_THIRD_PARTY_CURL_VERSION = 8.3.0
# HTTPS via mbedtls (align Luna / anypi_nova).
CONFIG_THIRD_PARTY_CURL_USE_MBEDTLS = y

CONFIG_THIRD_PARTY_WSS = y
CONFIG_THIRD_PARTY_WSS_VERSION = 4.4

# ============================================================
# Security Libraries
# ============================================================
CONFIG_THIRD_PARTY_MBEDTLS = y
CONFIG_THIRD_PARTY_MBEDTLS_VERSION = 2.28.10
CONFIG_THIRD_PARTY_MBEDTLS_SHARED = y

CONFIG_THIRD_PARTY_OPENSSL = n
CONFIG_THIRD_PARTY_OPENSSL_VERSION = 3.1.5
CONFIG_THIRD_PARTY_OPENSSL_MINIMAL = y

# ============================================================
# Data Format Libraries
# ============================================================
CONFIG_THIRD_PARTY_CJSON = y
CONFIG_THIRD_PARTY_CJSON_VERSION = 1.7.15

CONFIG_THIRD_PARTY_INIPARSER = y
CONFIG_THIRD_PARTY_INIPARSER_VERSION = 1.0.0

CONFIG_THIRD_PARTY_XMLPARSER = n
CONFIG_THIRD_PARTY_XMLPARSER_VERSION =

CONFIG_THIRD_PARTY_ZLIB = y
CONFIG_THIRD_PARTY_ZLIB_VERSION = 1.3.1

# ============================================================
# System Libraries
# ============================================================
CONFIG_THIRD_PARTY_ICONV = y
CONFIG_THIRD_PARTY_ICONV_VERSION = 1.15

CONFIG_THIRD_PARTY_TSLIB = y
CONFIG_THIRD_PARTY_TSLIB_VERSION = 1.22

# ============================================================
# Utility Libraries
# ============================================================
CONFIG_THIRD_PARTY_ZXING = y
CONFIG_THIRD_PARTY_ZXING_VERSION =

# ============================================================
# Scripting Engines (Optional)
# ============================================================
CONFIG_THIRD_PARTY_JERRYSCRIPT = n
CONFIG_THIRD_PARTY_JERRYSCRIPT_VERSION = 2.4.0

CONFIG_THIRD_PARTY_ASRIB = n
CONFIG_THIRD_PARTY_ASRIB_VERSION =
