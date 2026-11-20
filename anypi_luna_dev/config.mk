# SPDX-License-Identifier: Apache-2.0
############################################################
## anypi_luna_dev - EVB_MBD_KM01A / ipcamera (no UI, no LCD)
## SoC: AnyCloud39AV100_V2 + V2.04; root must sync PDK system/AnyCloud39AV100_V2/V2.04/.
## This project does not maintain AV200 board/patch.
############################################################
## SOC and Board Configuration
############################################################

# ARM uClibc GCC 5.5.0: gcc -shared defaults to -shared-libgcc, leaving UNDEF __aeabi_*/__sync_*
# in every .so. The gcc driver flags (-static-libgcc / -shared-libgcc) are unreliable on this
# toolchain. Instead, pass libgcc.a as an explicit input file so the linker resolves all
# __aeabi_*/__sync_* symbols directly, avoiding "hidden symbol referenced by DSO".
LDFLAGS += $(shell $(CC) -print-file-name=libgcc.a)

CONFIG_SOC_PLATFORM = AnyCloud39AV100_V2

CONFIG_SOC_SDK_VERSION = V2.04

CONFIG_OS_NAME = linux

# Must match directory name under project/anypi_luna_dev/system/.../board/
CONFIG_BOARD = EVB_MBD_KM01A

# Board feature support
CONFIG_BOARD_SUPPORT_DMIC = n
# Headless ipcamera: no LCD
CONFIG_BOARD_SUPPORT_LCD = n
# No fastsys (AV100 SPL does not support fastsys)
CONFIG_CELESTIA_FASTSYS = n

# WiFi module (must match board .../board/$(CONFIG_BOARD)/config.mk and rootfs build).
# atbm* / rtl* / ssv* -> HAL wpa_supplicant backend (wlan0)
CONFIG_WIFI_TYPE = atbm6032

############################################################
## Application Layer Configuration
############################################################
# Application layer modules configuration

# ============================================================
# Main Application
# ============================================================
# App main: unified application entry point (application/app_main/), produces main executable
CONFIG_APP_MAIN_ENTRY = y
CONFIG_APP_WEARABLE_DEVICE = n
# Main executable name: anypi_<suffix> -> <suffix>_main (app_main Makefile / CONFIG_APP_MAIN_TARGET); /usr/sbin/
CONFIG_APP_MAIN_TARGET ?= luna_dev_main
# Dynamic-link framework/hardware/system_core .so; keeps luna_dev_main small.
# uClibc: LDFLAGS libgcc.a above fixes __aeabi_* in .so; libgcc_s + libstdc++.so.6 use BSP /lib (not usr/lib).
CONFIG_APP_MAIN_DYNAMIC_CORE_SO = y
# Runtime .so deployment allowlist (no GUI libs; curl uses mbedtls).
# zxing required at runtime by libipc_cam_app.so -> libnebula_protocol.so (CONFIG_APP_NEBULA=y)
CONFIG_THIRD_PARTY_SO_ALLOWLIST = zxing cjson curl zlib iniparser iconv mbedtls

# ============================================================
# Cloud Services
# ============================================================
CONFIG_APP_CLOUD_TUYA = n
CONFIG_APP_CLOUD_VOLC = n
# Note: CONFIG_APP_CLOUD_ALIYUN is defined in cloud/aliyun/Makefile

# Cloud Link Support (for OTA encrypted firmware)
# CFG_CLOUD_LINK will be automatically generated if any cloud service is enabled
# Used in framework/runtime/ota/ota.c for mbedtls encryption support
CONFIG_FW_RUNTIME_OTA_CLOUD_LINK = n

# ============================================================
# Protocol Modules
# ============================================================
# RTSP gateway (gateway/rtsp_protocol -> librtsp_protocol.so); required by dashcam sub stream.
CONFIG_APP_RTSP = y
CONFIG_APP_NEBULA = y
CONFIG_APP_UVC = n
CONFIG_APP_WEATHER = n

# ============================================================
# Application packages (morphology)
# ============================================================
CONFIG_APP_PACKAGES_TABLET = n
CONFIG_APP_PACKAGES_WEARABLE = n
# PACKAGES_IPCAMERA=y builds packages/ipcamera/ipc_cam -> libipc_cam_app.so
CONFIG_APP_PACKAGES_IPCAMERA = y

# USB Mass Storage: not supported on this board (no USB OTG peripheral)
CONFIG_APP_USB_MSC_SUPPORT = n

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
CONFIG_FW_RUNTIME_CONSOLE = n
CONFIG_FW_RUNTIME_WATCHDOG = n
CONFIG_FW_RUNTIME_POWER_BUTTON = n
# CONFIG_FW_RUNTIME_SECURITY = y
# CONFIG_FW_RUNTIME_OTA = y

# ============================================================
# Multimedia Framework
# ============================================================
CONFIG_FW_MULTIMEDIA = y
# KM01W (MemTotal ~25MB): static ffmpeg in libmultimedia.so adds ~17MB BSS (ff_tx_tab_*)
# and ld.so fails with "can't map libmultimedia.so". Camera/record do not need file/stream player.
CONFIG_FW_MULTIMEDIA_MEDIA_PLAYER = n
CONFIG_FW_MULTIMEDIA_MEDIA_RECORDER = y
CONFIG_FW_MULTIMEDIA_AUDIO_PLAYER = y
CONFIG_FW_MULTIMEDIA_AUDIO_RECORDER = y
CONFIG_FW_MULTIMEDIA_STREAM_PLAYER = n
CONFIG_FW_MULTIMEDIA_STREAM_RECORDER = y
# Play/Record master switch (for product trimming)
CONFIG_FW_MULTIMEDIA_PLAY = y
CONFIG_FW_MULTIMEDIA_RECORD = y
# Multimedia fine-grained switches (disable as needed for production)
CONFIG_FW_MULTIMEDIA_CAMERA = y
CONFIG_FW_MULTIMEDIA_CAMERA_AI = y
# Align with anypi_luna / wearable dashcam: AI on, framework+HAL OSD off
CONFIG_FW_MULTIMEDIA_CAMERA_OSD = n
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
CONFIG_FW_GUI_GRAPHICS = n
CONFIG_FW_GUI_LVGL = n
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
CONFIG_FW_DEVICE_BACKLIGHT = n
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
CONFIG_FW_NOTIFICATION_INPUT = n
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
# Do not use CONFIG_FW_AI ??not wired in framework/Makefile; Luna/Nova share the same gate.
# Align with tablet_lite which has the explicit key:
CONFIG_FW_AI = n

# ============================================================
# Test and Debug
# ============================================================
# Product image: skip framework unit-test binaries
CONFIG_FW_TESTS = n

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
CONFIG_HW_DISPLAY = n
CONFIG_HW_GPU = y
# Align with anypi_luna: do not build HAL OSD (dashcam/AI do not require it)
CONFIG_HW_OSD = n

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
# Input Modules (no LCD/touch)
# ============================================================
CONFIG_HW_INPUT_KEYBOARD = y
CONFIG_HW_INPUT_TOUCH = n

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
# Must match current toolchain.
CONFIG_THIRD_PARTY_TARGET_ARCH = arm

# ============================================================
# GUI Libraries (disabled: no LCD / no UI)
# ============================================================
CONFIG_THIRD_PARTY_AWTK = n
CONFIG_THIRD_PARTY_AWTK_VERSION = 1.7.1

CONFIG_THIRD_PARTY_LVGL = n
export CONFIG_THIRD_PARTY_LVGL_VERSION = 9.3.0

# ============================================================
# Image Processing Libraries (disabled: LVGL / UI only)
# ============================================================
CONFIG_THIRD_PARTY_JPEG = n
CONFIG_THIRD_PARTY_JPEG_VERSION = 9e

CONFIG_THIRD_PARTY_JPEGDEC = n
CONFIG_THIRD_PARTY_JPEGDEC_VERSION = 1.4.2

CONFIG_THIRD_PARTY_LIBPNG = n
CONFIG_THIRD_PARTY_LIBPNG_VERSION = 1.6.43

CONFIG_THIRD_PARTY_FREETYPE = n
CONFIG_THIRD_PARTY_FREETYPE_VERSION = 2.12.0
# LVGL only loads .ttf ??trim font drivers; static .a only (no libfreetype.so on rootfs).
CONFIG_THIRD_PARTY_FREETYPE_MINIMAL = y
CONFIG_THIRD_PARTY_FREETYPE_SHARED = n

# ============================================================
# Video/Audio Processing Libraries
# ============================================================
CONFIG_THIRD_PARTY_FFMPEG = y
CONFIG_THIRD_PARTY_FFMPEG_VERSION = 7.0
# ffmpeg minimal build (y=enable only common demux/decoder/protocol, significantly reduces libav* size)
CONFIG_THIRD_PARTY_FFMPEG_MINIMAL = y

CONFIG_THIRD_PARTY_LIBH264 = n
CONFIG_THIRD_PARTY_LIBH264_VERSION =

# ============================================================
# Network Libraries
# ============================================================
CONFIG_THIRD_PARTY_CURL = y
CONFIG_THIRD_PARTY_CURL_VERSION = 8.3.0
# HTTPS via mbedtls (libwebsockets already uses mbedtls; avoids ~4MB libcrypto.so on rootfs).
CONFIG_THIRD_PARTY_CURL_USE_MBEDTLS = y

CONFIG_THIRD_PARTY_WSS = y
CONFIG_THIRD_PARTY_WSS_VERSION = 4.4

# ============================================================
# Security Libraries
# ============================================================
CONFIG_THIRD_PARTY_MBEDTLS = y
CONFIG_THIRD_PARTY_MBEDTLS_VERSION = 2.28.10
CONFIG_THIRD_PARTY_MBEDTLS_SHARED = y

# OpenSSL only needed when volc cloud or curl openssl backend is enabled.
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
# Touchscreen disabled (no LCD)
CONFIG_THIRD_PARTY_ICONV = y
CONFIG_THIRD_PARTY_ICONV_VERSION = 1.15

# Touchscreen (disabled: no LCD)
CONFIG_THIRD_PARTY_TSLIB = n
CONFIG_THIRD_PARTY_TSLIB_VERSION = 1.22

# ============================================================
# Utility Libraries
# ============================================================
# QR (UVC/UI); unused on headless ipc_cam
# Required by framework/gateway/nebula_protocol (nebula_pair.c -> zxing_scan.h)
CONFIG_THIRD_PARTY_ZXING = y
CONFIG_THIRD_PARTY_ZXING_VERSION =

# ============================================================
# Scripting Engines (Optional)
# ============================================================
CONFIG_THIRD_PARTY_JERRYSCRIPT = n
CONFIG_THIRD_PARTY_JERRYSCRIPT_VERSION = 2.4.0

CONFIG_THIRD_PARTY_ASRIB = n
CONFIG_THIRD_PARTY_ASRIB_VERSION =
