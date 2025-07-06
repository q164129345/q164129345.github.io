---
title: STM32F103_Bootloader程序开发03 - 启动入口与升级模式判断(boot_entry.c与boot_entry.h)
date: 2025-07-06 09:40:24
tags: [STM32, bootloader]
categories: [STM32]
description: 基于STM32F103ZET6的bootloader教程系列
---

# 导言

![STM32F103启动流程图](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250703230116.png)
本教程使用正点原子战舰板开发。

这个章节的重点是`"怎样让一个自己编写的函数比main()先运行，完成一些初始化操作。"`
![Bootloader模块架构图](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250706093729.png)
我暂时将bootloader程序分别五个模块，先从"启动入口与升级模式判断"模块开始吧。代码分别是boot_entry.c与boot_entry.h。项目刚开始，boot_entry.c与boot_entry.h会随着项目的推进会增加一些代码。

> 我的bootloader程序开发参考优秀的bootloader开源项目：[mOTA](https://gitee.com/DinoHaw/mOTA) ，强烈建议大家去学习一下这个优秀的开源项目。

项目地址：
github: https://github.com/q164129345/MCU_Develop/tree/main/bootloader03_stm32f103_boot_entry
gitee(国内): https://gitee.com/wallace89/MCU_Develop/tree/main/bootloader03_stm32f103_boot_entry

# 代码

## 1.1、boot_entry.c
```c
#include "boot_entry.h"
#include "flash_map.h"
#include "app_jump.h"

/**
  * @brief  上电，系统早期初始化回调（main()前自动调用）
  * @note
  *   - 本函数通过 GCC/ARMCC 的 @c __attribute__((constructor)) 属性修饰，系统启动后、main()执行前自动运行。
  *   - 适用于进行早期日志重定向、环境检测、固件完整性校验、启动标志判断等全局初始化操作。
  *   - 随项目进展，可逐步完善本函数内容，建议仅放置不依赖外设初始化的关键代码。
  *
  * @attention
  *   - 使用 @c __attribute__((constructor)) 机制要求工程链接脚本/启动文件正确支持 .init_array 段。
  *   - 若编译器或启动脚本不支持该机制，请将该函数内容手动放入 main() 最前面调用。
  *
  * @see    Retarget_RTT_Init(), log_printf()
  */
__attribute__((constructor))
static void _SystemStart(void)
{
    Retarget_RTT_Init(); //! RTT重定向printf
    
    log_printf("System Start!\n");
    
    /*! 检查复位更新标志 */

    /*! 后续添加升级模式判断 */
    /*! 增加检测一个按键，强制进入Bootloader升级模式等等 */
    /*！退出该函数之后，将会运行大家非常非常熟悉的main() */
}


```

## boot_entry.h

```c
#ifndef __BOOT_ENTRY_H
#define __BOOT_ENTRY_H

#ifdef __cplusplus
extern "C" {
#endif

#include "main.h"



#ifdef __cplusplus
}
#endif

#endif /* __BOOT_ENTRY_H */

```

## 代码编译、下载

![编译结果截图](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250526200242.png)
错误0,警告0

## 运行代码

![运行结果截图](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250526200442.png)
从RTT Viewer打印的log看来，**boot_entry.c的函数`_SystemStart()`居然比main.c的函数`main()`更早运行。** 怎样做到的？什么原理？

# 新知识点 - C/C++的构造函数（constructor）机制

## STM32F103上电后的启动流程

标准的启动流程如下：
1. 上电/复位
2. 从0x08000000（Bootloader首地址）开始执行
3. 启动文件（startup_stm32f103xx.s）
	- 设置SP（堆栈指针）为Bootloader的起始堆栈
	- 跳转到Reset_Handler
4. Reset_Handler 里会调用 SystemInit，然后进入 main()
也就是说，按标准流程，**应该是 main() 才是C代码入口点。**

## 为什么_SystemStart()会先执行？

**凡是被加了__attribute__((constructor))的函数，在main()之前被自动调用一次。** 这里的__attribute__((constructor))是GCC/ARMCC/KEIL等编译器的一个特殊拓展属性。这是编译器层面的"静态初始化"机制，与C++里的全局对象构造类似。

**这个不是STM32硬件的行为，而是编译器"加的钩子"。** STM32启动顺序没有变，主入口依然是main()。`_SystemStart()`之所以`main()`之前执行，是编译器__attribute_((constructor))机制帮你做的。

![构造函数机制示意图](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250526202203.png)

## 为什么要让_SystemStart()比main()先执行？

![无需deinit示意图](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250526202651.png)
**为实现"无须deinit"，才需要让_SystemStart()比main()先执行。** 如上图摘自[mOTA](https://gitee.com/DinoHaw/mOTA) 项目，当我看到bootloader程序可以实现"无须deinit"时，我真的非常激动。要把复杂的bootloader程序要把环境清理干净，真的折腾、调试死你。而且，STM32只有HAL库才有官方编写deinit()函数，高效的、优雅的LL库居然没有。

## 如果编译器/链接器不支持，怎么办？

![替代方案示意图](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250526203723.png)



