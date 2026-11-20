# 1、Board
为同一个项目不同板级的支持，主要包含以下几个内容：
## 1.1、板级DTS：
    os\kernel\arch\riscv\boot\dts
    os\kernel\arch\riscv\configs

## 1.2、板级Config
    config.mk

## 1.3、启动信息
    rootfs\utils\etc\config

# 2、patch
## 2.1 正常patch
    非快启的patch；
## 2.2 快启patch
    在非快启patch上增加的快启patch文件；

# 3、打patch流程
  见 ../../../build_soc_system.sh