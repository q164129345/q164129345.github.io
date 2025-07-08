---
title: STM32F103_Bootloader程序开发06 - IAP升级用的App.bin增加CRC32校验码，确保固件完整性，防止'变砖'
date: 2025-07-06 11:13:00
tags: [STM32, bootloader]
categories: [STM32]
description: 基于STM32F103ZET6的bootloader教程系列
---

# 导言
---
![STM32开发板](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250703230116.png)
本教程使用正点原子战舰板开发。

[[STM32F103_Bootloader程序开发05 - Keil修改生成文件的路径与文件名，自动生成bin格式文件]]上一章节成功让Keil生成App.bin二进制文件，用于IAP升级。

![CRC32校验示意图](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250706093821.png)
`为了保障IAP升级过程中的固件完整性，避免因损坏文件导致设备"变砖"，为App.bin添加CRC32校验码是一项关键措施。`在实际产品中，IAP（在应用程序中编程）升级机制极大地提升了设备远程维护与功能迭代的效率。然而，一旦升级过程中出现传输异常、存储错误或数据被篡改，App.bin中的固件内容若无有效校验机制，将可能导致"程序跳转失败"或"设备变砖"的严重问题。为避免此类风险，我们在本篇中将介绍如何在生成的App.bin文件末尾添加一个CRC32校验码，并在Bootloader中进行验证。通过这一机制，系统能在启动前准确判断固件的完整性，拒绝加载损坏固件，从而提升系统的可靠性与安全性。

![App.bin与App_crc.bin对比](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250530092955.png)
`总的来说，本章节的目的是在App.bin的结尾增加4个字节的CRC32，OTA（IAP）升级的时候使用App_crc.bin。注意不要使用App.bin。`


项目地址：
github: https://github.com/q164129345/MCU_Develop/tree/main/bootloader06_stm32f103_compile_bin_iap_file
gitee(国内): https://gitee.com/wallace89/MCU_Develop/tree/main/bootloader06_stm32f103_compile_bin_iap_file

<br>

# 一、让Keil编译完代码后，自动生成App_crc.bin
----
## 1.1、准备工具
1. srec_cat.exe（也可以去官网下载）
2. crc_add.bat(我已经编写好了，拿来用就好)
![工具文件](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250529114543.png)
如上所示，这两个工具已经在App的MDK-ARM文件夹里，自行领取即可。

## 1.2、让Keil编译完之后，自动调用crc_add.bat脚本，生成App_crc.bin文件
![Keil编译配置](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250529120215.png)

## 1.3、编译一次，看看效果
![编译后生成文件](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/After%20Build.gif)
如上所示，编译完成之后，顺利生成两个bin文件。

![生成的bin文件](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250529134116.png)
如上所示：
1. Run #1 的指令用于生成App.bin。
2. Run #2 的指令（其实就是调用crc_add.bat）用于生成App_crc.bin。

<br>

# 二、对比App.bin与App_crc.bin
---
## 2.1、对比文件结尾
![文件对比](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250529134502.png)
如上所示，左边是App_crc.bin文件，右边是App.bin文件。可见，App_crc.bin文件比App.bin文件在尾部多了一个CRC32校验码。
在下一章节，将编写一个代码，计算App_crc.bin的整包的CRC32码（当然，最后四个字节除外），用STM32计算出来的CRC32码跟文件最后的CRC32码做对比。如果它们相同，即整个固件的完整性是没有问题的。如果它们不相同，那整个固件的完整性有问题，IAP升级失败。等待上位机的下一次OTA升级。

## 2.2、对比文件内容（App_crc.bin的最后4个字节除外）
crc_add.bat脚本有没有将改动固件的内容呢？让ChatGPT帮我检查一下。
![ChatGPT检查结果1](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250529135519.png)
![ChatGPT检查结果2](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250529135610.png) 