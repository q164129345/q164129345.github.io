---
title: STM32F103_Bootloader程序开发02 - Bootloader程序架构与STM32F103的Flash内存规划
date: 2025-07-03 00:10:34
tags: [STM32, bootloader]
categories: [STM32]
description: 基于STM32F103ZET6的bootloader教程系列
---

# 导言
![硬件框架](https://github.com/q164129345/Obsidian_Repo/blob/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250703230116.png?raw=true)
本教程基于正点原子战舰板开发。

![Bootloader程序架构图](https://github.com/q164129345/Obsidian_Repo/blob/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250531202718.png?raw=true)
在工业设备和机器人项目中，固件远程升级能力已成为提升设备维护性与生命周期的关键手段。本文将围绕STM32平台，系统性介绍一个简洁、可靠的Bootloader程序设计思路。
我们将Bootloader核心流程划分为六大功能模块：
1. 启动入口与升级模式判断
2. 通讯协议与指令解析
3. 固件接收与缓存
4. Flash操作
5. App跳转
6. 校验CRC32

每个模块各司其职，既保证了流程的清晰、易维护，又为后续功能拓展（如安全保护、异常处理）预留了接口。通过模块化设计，能够高效实现与上位机的安全固件升级，显著提升系统的可靠性和可维护性。

# Flash内存规划

![STM32F103 Flash内存分区图](https://github.com/q164129345/Obsidian_Repo/blob/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250525112656.png?raw=true)

1. **bootloader区**
	- 起始地址：0x08000000
	- 结束地址：0x0800FFFF
	- 大小：64KB，64KB 对于STM32F1系列的Bootloader来说很充裕，哪怕实现了自检、协议解析、升级管理、App校验等功能，也有足够空间。典型的Bootloader通常只用16~32KB就够了，这里预留较大，是为了后续扩展或协议变化更灵活，属于稳健做法。

2. **App区**
	-  起始地址：0x08010000
	- 结束地址：0x0803FFFF
	- 大小：192KB，192KB 足够一般工业/机器人App使用（一般完整功能带RTOS、通信协议、复杂逻辑都能放下）。保证了App区块独立、可整体擦写与升级，方便Bootloader进行管理。

3. **App缓存区（固件下载区）**
	- 起始地址：0x08040000
	- 结束地址：0x0806FFFF
	- 大小：192KB
    - 下载新固件时，通常Bootloader先将完整固件文件存入缓存区，校验无误后再整体拷贝到App区，这样升级失败不会影响当前运行的App。
    - 192KB 与App区同样大小，保证可下载“完整体积的App”，合理且安全。避免了外部Flash，采用片上Flash空间做双区，适合资源有限的场合。

4. **参数区（自由使用）**
	- 起始地址：0x08070000
	- 结束地址：0x0807FFFF
	- 大小：64KB，64KB 远大于通常的参数/配置/校准区需求（实际很多项目1~~2页即8~~16KB即可），你这里留足余量，方便后续做历史数据、日志、频繁参数备份等。参数区建议采用“页擦写+参数备份+断电校验”策略，提高可靠性。

![Flash分区详细布局图](https://github.com/q164129345/Obsidian_Repo/blob/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528145633.png?raw=true)

# 代码

## flash_map.h

将上面的分区细节，落实到代码flash_map.h。
```c
/**
 * @file    flash_map.h
 * @brief   STM32F103ZET6 Flash分区地址与大小常量定义
 * @author  Wallace.zhang
 * @date    2025-05-25
 * @version 1.0.0
 * @copyright
 * (C) 2025 Wallace.zhang. 保留所有权利.
 * @license SPDX-License-Identifier: MIT
 */

#ifndef __FLASH_MAP_H
#define __FLASH_MAP_H

#ifdef __cplusplus
extern "C" {
#endif

/** 
 * @brief STM32F103ZET6 Flash 基础参数
 */
#define STM32_FLASH_BASE_ADDR      0x08000000U      /**< Flash起始基地址 */
#define STM32_FLASH_SIZE           (512 * 1024U)    /**< Flash总大小（字节） */
#define STM32_FLASH_PAGE_SIZE      (2 * 1024U)      /**< Flash单页大小（字节） */

/**
 * @brief Bootloader区
 */
#define FLASH_BOOT_START_ADDR      0x08000000U      /**< Bootloader起始地址 */
#define FLASH_BOOT_END_ADDR        0x0800FFFFU      /**< Bootloader结束地址 */
#define FLASH_BOOT_SIZE            (FLASH_BOOT_END_ADDR - FLASH_BOOT_START_ADDR + 1) /**< Bootloader区大小 */

/**
 * @brief 主程序App区
 */
#define FLASH_APP_START_ADDR       0x08010000U      /**< App起始地址 */
#define FLASH_APP_END_ADDR         0x0803FFFFU      /**< App结束地址 */
#define FLASH_APP_SIZE             (FLASH_APP_END_ADDR - FLASH_APP_START_ADDR + 1)   /**< App区大小 */

/**
 * @brief App缓存区（新固件下载区）
 */
#define FLASH_DL_START_ADDR        0x08040000U      /**< 下载区起始地址 */
#define FLASH_DL_END_ADDR          0x0806FFFFU      /**< 下载区结束地址 */
#define FLASH_DL_SIZE              (FLASH_DL_END_ADDR - FLASH_DL_START_ADDR + 1)     /**< 下载区大小 */

/**
 * @brief 参数区（用户参数、历史数据等）
 */
#define FLASH_PARAM_START_ADDR     0x08070000U      /**< 参数区起始地址 */
#define FLASH_PARAM_END_ADDR       0x0807FFFFU      /**< 参数区结束地址 */
#define FLASH_PARAM_SIZE           (FLASH_PARAM_END_ADDR - FLASH_PARAM_START_ADDR + 1) /**< 参数区大小 */

#ifdef __cplusplus
}
#endif

#endif /* __FLASH_MAP_H */

```

# Keil配置

## bootloader程序的Keil配置

![Bootloader程序Keil配置截图](https://github.com/q164129345/Obsidian_Repo/blob/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250525184402.png?raw=true)

## App程序的Keil配置

![App程序Keil配置截图](https://github.com/q164129345/Obsidian_Repo/blob/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250525184622.png?raw=true)

# 细节补充

## STM32F103ZET6的Flash布局

![STM32F103ZET6 Flash页面布局](https://github.com/q164129345/Obsidian_Repo/blob/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250525185104.png?raw=true)
**STM32F103ZET6属于大容量产品，内存块划分为256个2K字节页。** 从这个知识可以得到如下信息：
1. Bootloader：第0页到第31页（共32页）
2. App：第32页到第127页（共96页）
3. App缓存区：第128页到第223页（共96页）
4. 参数区：第224页到第255页（共32页）
![STM32F103ZET6 Flash页面分配详情](https://github.com/q164129345/Obsidian_Repo/blob/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250525185852.png?raw=true)

