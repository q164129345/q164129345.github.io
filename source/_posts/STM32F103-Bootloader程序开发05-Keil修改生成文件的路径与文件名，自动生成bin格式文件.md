---
title: STM32F103_Bootloader程序开发05 - Keil修改生成文件的路径与文件名，自动生成bin格式文件
date: 2025-07-06 10:46:40
tags: [STM32, bootloader]
categories: [STM32]
description: 基于STM32F103ZET6的bootloader教程系列
---
# 导言
---
![STM32F103启动流程图](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250703230116.png)
本教程使用正点原子战舰板开发。

通过Keil的相关配置，可以灵活地修改输出文件的保存路径及文件名称。在Bootloader程序开发过程中，合理配置输出文件对于后续固件升级和自动化脚本处理至关重要。完成路径和文件名配置后，还可以借助Keil自带的fromelf.exe工具，将生成的axf文件转换为bin格式文件，便于后续烧录和升级操作。

<br>

# 一、修改生成文件的路径
---
![创建Outputs文件夹](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528164207.png)
![Outputs文件夹位置](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528164251.png)
如上所示，在MDK-ARM文件夹里创建Ouputs文件夹，这个文件夹用于存放Keil自动生成的文件。
![Keil项目设置](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528164607.png)
![输出路径设置1](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528164819.png)
![输出路径设置2](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528164904.png)
![输出路径设置3](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528165002.png)
![输出路径设置4](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528165058.png)

<br>

# 二、修改生成的文件名
---
![文件名设置入口](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528165215.png)
![文件名设置界面](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528165429.png)

<br>

# 三、让Keil调用fromelf.exe生成升级用的bin文件
---
## 3.1、什么是fromelf.exe？
这是 ARM Keil 自带的一个命令行工具，用于将编译生成的目标文件（axf/elf格式）转换为其他格式（比如 bin、hex）。
![fromelf工具说明](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528170718.png)

## 3.2、生成App.bin
![配置fromelf命令1](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528170853.png)
![配置fromelf命令2](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528171042.png)
```sh
C:\Keil_v5\ARM\ARMCC\bin\fromelf.exe --bin --output .\Output\App.bin .\Outputs\App.axf
```
意思是：
1. C:\Keil_v5\ARM\ARMCC\bin\fromelf.exe
	- 这是 ARM Keil 自带的一个命令行工具，用于将编译生成的目标文件（axf/elf格式）转换为其他格式（比如 bin、hex）。
2. --bin
	- 这是 fromelf 的参数，意思是将输入的 axf 文件（即你的可执行文件）转换成二进制（.bin）格式。
	- 这种 bin 格式是裸数据，没有任何调试信息，适合直接烧录进 MCU Flash，用于 bootloader、IAP、量产等场景。
3. --output .\Output\App.bin
	- --output 是 fromelf 工具的参数，用来指定输出文件名和路径。
	- .\Output\App.bin 是在当前工程目录下的Output文件夹下生成App.bin二进制文件。
4. .\Outputs\App.axf
	- 指定输入的 axf 文件，它在工程目录下的Outputs文件夹下，名字是App.axf。

![生成的App.bin文件](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528172042.png)
如上所示，得到了我们IAP升级需要的App程序的二进制文件App.bin了。