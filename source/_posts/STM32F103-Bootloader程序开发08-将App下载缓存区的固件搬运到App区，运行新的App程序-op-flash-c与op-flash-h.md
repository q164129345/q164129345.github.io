---
title: >-
  STM32F103_Bootloader程序开发08 -
  将App下载缓存区的固件搬运到App区，运行新的App程序(op_flash.c与op_flash.h)
date: 2025-07-08 07:42:15
tags: [STM32, bootloader]
categories: [STM32]
description: 基于STM32F103ZET6的bootloader教程系列
---

# 导言
---
![STM32开发板](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250703230116.png)
本教程使用正点原子战舰板开发。

![模块架构图](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250605152235.png)
如上所示，开始完成op_flash模块与fw_verify模块。

![Flash内存规划](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250530171925.png)
上一章节使用J-Flash将App_crc.bin下载到咱项目定义的"App下载缓存区"，起始地址0x08040000、大小0x30000。然后，通过soft_crc32.c的函数Calculate_Firmware_CRC32_SW()对App_crc.bin进行CRC32校验。详细请回头看上一章节[[STM32F103_Bootloader程序开发07 - 使用J-Flash将App_crc.bin烧录到App下载缓存区，再校验CRC32，确认固件完整性]]。

![CRC32校验结果](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250530172554.png)
CRC32校验成功，证明"App下载缓冲区"的固件完整性没有问题。接着将"App下载缓冲区"里的App_crc.bin搬运到App区运行，完成IAP升级。

![升级成功日志](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250605141154.png)
如上所示，从RTT打印看来，校验固件完整性成功，App升级成功。最后，顺利跳转App区运行新的App程序。

## 优化crc_add.bat脚本
![CRC32校验码输出](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250605144418.png)
`Keil Build Output增加在打印CRC32校验码的下一行新增App_crc.bin的尺寸大小：5284 bytes（如上所示）。`值得注意的是，App_crc.bin的固件大小总是比App.bin大4个bytes，因为CRC32校验码被添加在App.bin的结尾。
新的crc_add.bat脚本的内容放在本章的最后一节。

项目地址：  
github: https://github.com/q164129345/MCU_Develop/tree/main/bootloader08_stm32f103_op_flash
gitee(国内): https://gitee.com/wallace89/MCU_Develop/tree/main/bootloader08_stm32f103_op_flash

<br>

# 一、代码
---
## 1.1、op_flash.c
![op_flash.c代码1](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250605145725.png)
![op_flash.c代码2](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250605145902.png)
![op_flash.c代码3](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250605150039.png)
## 1.2、op_flash.h
![op_flash.h代码](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250605150522.png)

## 1.3、fw_verify.c
![fw_verify.c代码](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250605151050.png)

## 1.4、fw_verify.h
![fw_verify.h代码](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250605151212.png)

## 1.5、main.c
![main.c代码](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250605151838.png)
main.c代码只介绍本章节的重要部分，其他部分请阅读源码。

<br>

# 二、细节补充
---
## 2.1、新crc_add.bat脚本
可以基于这个版本修改其他玩法，比如App_crc.bin的名字改为实际的项目名称。比如，robot_vcu_crc.bin等
```sh
@echo off
rem -------------
rem  Add CRC32 to App.bin
rem -------------

setlocal enabledelayedexpansion

set INPUT_FILE=.\Output\App.bin
set OUTPUT_FILE=.\Output\App_crc.bin

rem ── 1. 计算原始 BIN 长度 ──
for %%i in ("%INPUT_FILE%") do set BIN_SIZE=%%~zi
echo App.bin size            : %BIN_SIZE% bytes

rem ── 2. 追加 CRC32（小端）到文件尾 ──
.\srec_cat.exe ^
    "%INPUT_FILE%" -Binary ^
    -crop 0 %BIN_SIZE% ^
    -crc32-l-e %BIN_SIZE% ^
    -o "%OUTPUT_FILE%" -Binary

if not exist "%OUTPUT_FILE%" (
    echo Failed to generate CRC32 bin file!
    goto :eof
)

rem ── 3. 获取追加 CRC32 后 BIN 长度 ──
for %%i in ("%OUTPUT_FILE%") do set BIN_SIZE_CRC=%%~zi

rem ── 4. 裁剪最后 4 字节并打印 CRC32 ──
set /a END_ADDR=%BIN_SIZE%+4

for /f "tokens=2-5" %%a in ('
    .\srec_cat.exe "%OUTPUT_FILE%" -Binary ^
        -crop %BIN_SIZE% !END_ADDR! ^
        -o - -hex-dump
') do (
    set CRC_B0=%%a
    set CRC_B1=%%b
    set CRC_B2=%%c
    set CRC_B3=%%d
    goto :PRINT_CRC
)

:PRINT_CRC
set CRC32=0x!CRC_B3!!CRC_B2!!CRC_B1!!CRC_B0!
echo CRC32 (little-endian stored): !CRC32!
echo App_crc.bin size        : !BIN_SIZE_CRC! bytes

echo CRC32 appended successfully: %OUTPUT_FILE%
endlocal
```

