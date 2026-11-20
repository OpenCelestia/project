# SPDX-License-Identifier: Apache-2.0
############################################################
## SOC and Board Configuration
############################################################
## anypi_nova: AK3918AV200 ActionCam 量产板（PDB_MBD_AK3918AV200_ACTCAM）。
## Hardware ground-truth is km02x_action_camera_yd (SDK1.04, verified booting):
##   OV8856 sensor / ST7262 800x480 RGB LCD / GT911 touch / ATBM6162 WiFi / single ADC MIC.
## SDK V1.04（与 km02x_action_camera_yd 一致）; overlay 目录 system/AnyCloud39AV200/V1.04/
## 双 DTB: 常启 / 快启见 board/config.mk（CONFIG_CELESTIA_FASTSYS）
# Target platform (AnyCloud39AV100, AnyCloud39EV330, AnyCloud37E, SkyAV100, Sky37Ev2)
# Corresponding directory: system/$CONFIG_SOC_PLATFORM/$CONFIG_SDK_VERSION
CONFIG_SOC_PLATFORM = AnyCloud39AV200

# SDK version (km02x_action_camera_yd / AnyCloud39AV200 SDK V1.04)
CONFIG_SOC_SDK_VERSION = V1.04

# Target OS (linux, rtt, aos)
CONFIG_OS_NAME = linux

# Target board
# Corresponding directory: system/$CONFIG_SOC_PLATFORM/$CONFIG_SDK_VERSION/board/$CONFIG_BOARD
CONFIG_BOARD = PDB_MBD_AK3918AV200_ACTCAM

# WiFi module (ATBM6162 SDIO → HAL wpa_supplicant backend, wlan0)
CONFIG_WIFI_TYPE = atbm6162

# LCD logical resolution (SSOT; mirrors app_globle_config.h LCD_*_RES_MAX fallback)
CONFIG_LCD_HOR_RES = 800
CONFIG_LCD_VER_RES = 480

# Board feature support
# ActionCam uses a single ADC MIC (not DMIC), and a 800x480 RGB LCD.
CONFIG_BOARD_SUPPORT_DMIC = n
CONFIG_BOARD_SUPPORT_LCD = y
# System fast boot (Celestia SPL fastsys)
CONFIG_CELESTIA_FASTSYS = y
# U-Boot / 内核 DTB 名见 board/.../config.mk（与 anypi_luna 相同，仅板级配置）

# Display driver: ST7262 fb0 stores B,G,R; LVGL outputs R,G,B → IPU must swap channels.
# Propagated to C code via generated config.h; app_globle_config.h uses it with fallback.
CONFIG_LV_PORT_IPU_FB_RGB_SWAP = 1
# luna-style display flags (not needed for AV200/IPU path)
CONFIG_LV_DISPLAY_RGB565_SWAPPED = n
CONFIG_LV_DISPLAY_PARTIAL_SW_FB = n
CONFIG_HW_DISPLAY_COLOR_SWIZZLE = 0

############################################################
## Application Layer Configuration
############################################################
# Application layer modules configuration

# ============================================================
# Main Application
# ============================================================
# App main: unified application entry point (application/app_main/), produces main executable
CONFIG_APP_MAIN_ENTRY = y
# Main executable name (read by app_main Makefile); deployed to /usr/sbin/nova_main.
# Process name in top follows this basename.
CONFIG_APP_MAIN_TARGET ?= nova_main
# Scheme B: omit -lmultimedia/-lnetwork from ipc_main; dlopen after Home first frame.
CONFIG_APP_MAIN_DEFER_HEAVY_SO = y
# Runtime .so deployment allowlist
# iconv: SDK needs libiconv.so.2
# freetype/libpng: deferred dlopen after Home (not DT_NEEDED). LVGL stays static in ipc_main
# (framework may still build liblvgl.so as byproduct — packaging must NOT ship it to SD).
# curl via mbedtls — no openssl / libwebsockets (WSS=n).
# jpeg: studio uses libjpeg for the fb->MJPEG channel (CONFIG_APP_STUDIO).
CONFIG_THIRD_PARTY_SO_ALLOWLIST = zxing cjson curl zlib iniparser iconv freetype libpng mbedtls jpeg

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
# studio: PC sync tool daemon (TCP 7777; docs/design/nova/anypi_nova_pc_studio.md)
CONFIG_APP_STUDIO = y

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
# USB Mass Storage (export SD to PC; settings tab for mode switch)
CONFIG_APP_USB_MSC_SUPPORT = y

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
# Storage mode tab (local SD vs USB disk); requires CONFIG_APP_USB_MSC_SUPPORT = y
CONFIG_APP_TABLET_LV_DEMO_STORAGE = y

# C preprocessor: export config.mk switches to GUI compile (see application/packages/tablet/Makefile).
# build.sh also auto-generates project/include/config.h (#define CONFIG_* for each =y line).
CONFIG_PROJECT_CFLAGS :=
ifeq ($(CONFIG_APP_USB_MSC_SUPPORT),y)
CONFIG_PROJECT_CFLAGS += -DCONFIG_APP_USB_MSC_SUPPORT
endif
ifeq ($(CONFIG_APP_TABLET_LV_DEMO_STORAGE),y)
CONFIG_PROJECT_CFLAGS += -DCONFIG_APP_TABLET_LV_DEMO_STORAGE
endif
# Explicit 0/1 so audio_algo SSL gate works even when =n is omitted from generated config.h.
ifeq ($(CONFIG_BOARD_SUPPORT_DMIC),y)
CONFIG_PROJECT_CFLAGS += -DCONFIG_BOARD_SUPPORT_DMIC=1
else
CONFIG_PROJECT_CFLAGS += -DCONFIG_BOARD_SUPPORT_DMIC=0
endif

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
# Nebula/call needs SW H.264 decode (AV200 has no MPI VDEC). Use decode mode:
# link trimmed FFmpeg into libmultimedia.so, keep file demux/play excluded.
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

# ============================================================
# AI Framework
# ============================================================
# Note: AI module is currently integrated in multimedia/camera/ai/
#       See framework/ai/AI_MODULE_INDEPENDENCE_ASSESSMENT.md for details
CONFIG_FW_AI = n

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
# Match Luna: minimal freetype shrinks footprint.
CONFIG_THIRD_PARTY_FREETYPE_MINIMAL = y
# Shared for Scheme B deferred dlopen (Home does not need FreeType at first frame).
CONFIG_THIRD_PARTY_FREETYPE_SHARED = y

# ============================================================
# Video/Audio Processing Libraries
# ============================================================
CONFIG_THIRD_PARTY_FFMPEG = y
CONFIG_THIRD_PARTY_FFMPEG_VERSION = 7.0
# ffmpeg minimal build (y=enable only common demux/decoder/protocol, significantly reduces libav* size)
CONFIG_THIRD_PARTY_FFMPEG_MINIMAL = y
# Decode-only overrides MINIMAL: H.264 parser/decoder only (no avformat/network).
# Keeps libmultimedia.so growth small for 16MB NOR Nebula video-call downlink.
CONFIG_THIRD_PARTY_FFMPEG_DECODE_ONLY = y

CONFIG_THIRD_PARTY_LIBH264 = n
CONFIG_THIRD_PARTY_LIBH264_VERSION =

# ============================================================
# Network Libraries
# ============================================================
CONFIG_THIRD_PARTY_CURL = y
CONFIG_THIRD_PARTY_CURL_VERSION = 8.3.0
# HTTPS via mbedtls (libwebsockets already uses mbedtls; avoids ~4MB libcrypto.so on rootfs).
CONFIG_THIRD_PARTY_CURL_USE_MBEDTLS = y

CONFIG_THIRD_PARTY_WSS = n
CONFIG_THIRD_PARTY_WSS_VERSION = 4.4

# ============================================================
# Security Libraries
# ============================================================
CONFIG_THIRD_PARTY_MBEDTLS = y
CONFIG_THIRD_PARTY_MBEDTLS_VERSION = 2.28.10
# Shared mbedtls for curl / volc HMAC (align Luna).
CONFIG_THIRD_PARTY_MBEDTLS_SHARED = y

# OpenSSL only needed when curl openssl backend is enabled.
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
