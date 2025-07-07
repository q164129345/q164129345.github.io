---
title: STM32F103_Bootloader程序开发01 - 什么是IAP？跟OTA有什么关系？
date: 2025-07-02 23:18:05
tags: [STM32, bootloader]
categories: [STM32]
description: 基于STM32F103ZET6的bootloader教程系列
---

# 导言
---
![硬件框架](https://github.com/q164129345/Obsidian_Repo/blob/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250703230116.png?raw=true)
本教程基于正点原子战舰板开发。


这是一个做bootloader程序开发经常会遇到的疑问。IAP 和 OTA 都和固件升级相关，但不是同一个概念，它们之间有交集，但又各自有特定的应用场景。

<br>

# 什么是IAP(In-Application Programming)？
---
**IAP，中文一般称为"应用程序内编程"或"在应用中自编程"。本质含义：MCU 在运行用户代码（App或Bootloader）时，通过自身的代码（而不是用外部编程器/仿真器）来擦写和更新片上 Flash 内容。** 典型的应用场景：在系统上线后，通过串口、CAN、USB、以太网等接口下载新固件，并写入指定Flash区，完成固件升级。

![IAP示意图](https://github.com/q164129345/Obsidian_Repo/blob/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250523105059.png?raw=true)

实际场景：工程师用串口工具将固件下载到MCU，MCU通过IAP代码将固件烧写到App区。

<br>

# 什么是OTA(Over-The-Air，空中下载/升级)？
---
**OTA，直译就是"空中下载"或者"远程升级"。本质含义：利用无线通信（如WiFi、蓝牙、NB-IoT、4G/5G等），将新固件从服务器下载到设备，再进行固件升级。** 

![OTA示意图](https://github.com/q164129345/Obsidian_Repo/blob/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250523093121.png?raw=true)

实际场景：产品上线后，用户用手机APP或者设备自己通过WiFi下载新固件，MCU下载完成后，通过IAP流程将固件写入App区。

<br>

# IAP跟OTA有什么关系？
---
- IAP 是一种升级机制/技术，它是固件升级的基础能力，让MCU可以自我更新程序。
- OTA 是一种升级方式/场景，它是一套"如何把新固件送到设备"+"触发升级流程"的完整解决方案，实现的底层依赖于IAP。

![IAP与OTA关系图](https://github.com/q164129345/Obsidian_Repo/blob/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250523105207.png?raw=true)

总的来说：
- OTA = 固件无线传输 + 本地IAP写入
- IAP 可以独立使用，比如通过串口/USB升级（有线IAP）。
- OTA 一定要依赖IAP，否则固件即使下载下来，MCU也无法自我刷新。

<br>

# Bootloader跟IAP又是什么关系？
----
## Bootloader是什么？

Bootloader（引导加载程序），是上电后第一个运行的程序，主要负责以下几个任务：

- 系统初始化（最小外设/时钟/内存等）
- 判断启动条件（决定启动App，还是进入升级模式）
- 稳定地加载、校验和跳转到主应用（App）
- 实现固件升级流程（IAP）
- 有时还提供如参数恢复、生产测试等功能

**它是设备"最后一道自救保险"。只要Bootloader没被破坏，哪怕App区彻底损坏，仍然能远程/本地恢复设备，防止"变砖"。** 在STM32系统里，Bootloader一般烧录在Flash的最前面一段区域（比如0x08000000~0x0800FFFF），具有独立的启动入口。

## 跟IAP的关系

**Bootloader是IAP机制的载体，IAP功能一般是由Bootloader来实现的。** 为什么不能在App上实现IAP？原因：

- 安全性：Bootloader天然具备更高的安全级别，避免因App异常导致升级流程失控。
- 健壮性：即使App区损坏，Bootloader仍可正常进入升级模式，保证设备可恢复。
- 一致性：升级校验（如CRC、签名）由Bootloader统一处理，避免不同版本App间实现差异导致升级不兼容。
- 启动机制：Bootloader能根据升级状态决定"升级 or 跳转App"，流程更清晰。