---
title: STM32F103_Bootloader程序开发04 - App跳转模块(app_jump.c与app_jump.h)
date: 2025-07-06 09:53:11
tags: [STM32, bootloader]
categories: [STM32]
description: 基于STM32F103ZET6的bootloader教程系列
---
# 导言
---
![STM32F103启动流程图](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250703230116.png)
本教程使用正点原子战舰板开发。

![Bootloader跳转模块架构图](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250706093753.png)
本章节的目的是`实现Bootloader程序顺利跳转App程序，App程序能正常执行（中断回调正常等）。`

上一章节《[[STM32F103_Bootloader程序开发03 - 启动入口与升级模式判断(boot_entry.c与boot_entry.h)]]》学会使用"C/C++的构造函数（constructor）机制"让我们自己编写的函数`_SystemStart()`在main()之前先运行。

**"无须deinit"是现代bootloader设计的推荐实践。** 本章节将结合上一章节的代码，梳理"无须deinit"的实现过程。
![无须deinit设计示意图](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250527110136.png)
如上所示，摘自bootloader开源项目[mOTA](https://gitee.com/DinoHaw/mOTA)。

项目地址：
github: https://github.com/q164129345/MCU_Develop/tree/main/bootloader04_stm32f103_jump_app
gitee(国内): https://gitee.com/wallace89/MCU_Develop/tree/main/bootloader04_stm32f103_jump_app

<br>

# 一、Keil设置Flash与RAM
---
## 1.2、App程序

![App程序Flash设置](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250527105242.png)
Flash区域按照《[[STM32F103_Bootloader程序开发02 - Bootloader程序架构与STM32F103的Flash内存规划]]》的规划进行设置，如上所示。
RAM分成两部分：
- IRAM1给程序使用。
- IRAM2的大小刚好是8个字节，这里定义了一个全局变量`update_flag`，记得勾选`No Init`。

## 1.3、bootloader程序

![Bootloader程序Flash设置](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250527105959.png)
Flash区域按照《[[STM32F103_Bootloader程序开发02 - Bootloader程序架构与STM32F103的Flash内存规划]]》的规划进行设置，如上所示。
RAM分成两部分：
- IRAM1给程序使用。
- IRAM2的大小刚好是8个字节，这里定义了一个全局变量update_flag，记得勾选`No Init`。

<br>

# 二、代码
---

## 2.1、App程序

### 2.1.1、main.c
![App程序main.c代码](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528100644.png)
App代码只需要在main()设置中断向量表与开启全局中断即可。其他，跟普通程序一样。
![App程序功能示意](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528100612.png)
App代码很简单，如果App能正常运行的话。电脑的串口助手会每个500ms收到一段来自STM32发出来的字符串"012345678"。接着，心跳LED灯会持续闪烁。

## 2.2、Bootloader程序

### 2.2.1、app_jump.c

源码如下：
```c
#include "app_jump.h"
#include "stm32f1xx.h"      /**< 根据芯片型号修改 */
#include "flash_map.h"      /**< Flash分区宏定义 */
#include "usart.h"
#include "retarget_rtt.h"
#include "bootloader_define.h"


#if defined(__IS_COMPILER_ARM_COMPILER_5__)
volatile uint64_t update_flag __attribute__((at(FIRMWARE_UPDATE_VAR_ADDR), zero_init));

#elif defined(__IS_COMPILER_ARM_COMPILER_6__)
    #define __INT_TO_STR(x)     #x
    #define INT_TO_STR(x)       __INT_TO_STR(x)
    volatile uint64_t update_flag __attribute__((section(".bss.ARM.__at_" INT_TO_STR(FIRMWARE_UPDATE_VAR_ADDR))));

#else
    #error "variable placement not supported for this compiler."
#endif

/**
  * @brief  去初始化Bootloader已用外设，避免影响App运行
  * @note
  *   - 复位系统时钟为默认HSI
  *   - 关闭全局中断与SysTick
  *   - 去初始化USART1及其DMA
  *   - 清除所有NVIC中断和挂起标志
  *   - 跳转App前必须调用本函数
  */
//void IAP_DeInitHardware(void)
//{
//    /*! 系统时钟复位为默认状态（使用HSI） */
//    HAL_RCC_DeInit();
//   
//    /*! 关闭SysTick定时器 */
//    SysTick->CTRL = 0;
//    SysTick->LOAD = 0;
//    SysTick->VAL  = 0;

//    /*! bootloader程序初始化的外设，全部都要DeInit，否则会影响App的运行 */
//    /*! 本实例的bootloader只用到DMA与USART1 */
//    /*! 串口去初始化 */
//    HAL_UART_DeInit(&huart1);

//    /*! DMA去初始化 */
//    HAL_DMA_DeInit(huart1.hdmarx);
//    HAL_DMA_DeInit(huart1.hdmatx);

//    /*! NVIC中断彻底关闭和清挂起 */
//    for (uint8_t i = 0; i < 8; ++i) {
//        NVIC->ICER[i] = 0xFFFFFFFF;
//        NVIC->ICPR[i] = 0xFFFFFFFF;
//    }

//    //__enable_irq();   /*!< 重新打开中断（跳转前可不使能） */
//}

/**
  * @brief  跳转到指定应用程序入口（不返回）
  * @param  app_addr  应用程序向量表地址（通常为App分区起始地址）
  * @note
  *   - 跳转前自动去初始化所有已用外设与中断
  *   - 自动设置MSP，切换特权级模式
  *   - 重定位中断向量表SCB->VTOR到App起始地址
  *   - 跳转后本函数不返回，若跳转失败将死循环
  */
static void IAP_JumpToApp(uint32_t app_addr)
{
    void (*AppEntry)(void);           /**< 应用入口函数指针 */
    __IO uint32_t AppAddr = app_addr; /**< 跳转目标地址 */
    
    /*! 关闭全局中断 */
    __disable_irq();
    
    /*! 不需要deinit外设了，本实例使用"无deinit方案，核心是"软复位 + 标志再入跳转。一切资源全部归零，极大简化维护，提高可靠性
     *  这是现代Bootloader设计的推荐实践
     */
    /*! 跳转App前，将外设复位。为App提供一个干净的环境 */
    //IAP_DeInitHardware();

    /*! 获取App复位向量（入口地址） */
    AppEntry = (void (*)(void)) (*((uint32_t *) (AppAddr + 4)));

    /*! 设置主堆栈指针MSP */
    __set_MSP(*(uint32_t *)AppAddr);

    /*! 切换为特权级模式（使用MSP），RTOS场景下尤为重要 */
    __set_CONTROL(0);

    /*! 告诉CPU，App的中断向量表地址 */
    SCB->VTOR = AppAddr;
    
    /*! 跳转至应用程序入口，函数不再返回 */
    AppEntry();
    
    /*!
      @attention 若跳转失败，可在此增加错误处理（一般不会执行到这里）
    */
    while (1)
    {
        /*! 错误保护 */
    }
}

/**
  * @brief  获取固件升级标志位
  * @note   读取保存于指定RAM地址的升级标志变量（通常用于判断bootloader的运行状态）
  * @retval uint64_t 固件升级标志的当前值
  */
uint64_t IAP_GetUpdateFlag(void)
{
    return update_flag;
}

/**
  * @brief  设置固件升级标志位
  * @param  flag 需要设置的标志值
  * @note   修改指定RAM地址的升级标志变量
  * @retval 无
  */
void IAP_SetUpdateFlag(uint64_t flag)
{
    update_flag = flag;
}

/**
  * @brief  准备跳转到App程序
  * @note   判断当前升级标志，第一次调用时先设置标志并复位MCU，第二次调用时清除标志并跳转到App
  * @retval 无
  * @attention 
  *          - 此函数用于bootloader到应用程序的跳转流程控制。
  *          - 必须保证FLASH_APP_START_ADDR为合法的应用程序入口地址。
  *          - 跳转前应正确清理MCU相关外设状态，防止异常影响应用程序。
  */
void IAP_Ready_To_Jump_App(void)
{
    /*! 第二次进入，跳转至App */
    if (IAP_GetUpdateFlag() == BOOTLOADER_RESET_MAGIC_WORD) {
        log_printf("The second time enter this function, clean the flag and then Jump to Application.\n");
        
        /*! 保证RTT打印完log(延迟约1ms) */
        Delay_MS_By_NOP(1);
        
        /*! 清除固件更新标志位 */
        IAP_SetUpdateFlag(0);
        
        /*! 跳转App */
        IAP_JumpToApp(FLASH_APP_START_ADDR);
    } else {
        log_printf("The first time enter this function, clean up the MCU environment.\n");
        
        /*! 保证RTT打印完log(延迟约1ms) */
        Delay_MS_By_NOP(1);
        
        /*! 设置标志位 */
        IAP_SetUpdateFlag(BOOTLOADER_RESET_MAGIC_WORD);
        
        /*! 系统复位，重新进入bootloader */
        HAL_NVIC_SystemReset();
    }
}


```
![全局变量update_flag定义](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528112051.png)
定义一个关键的全局变量update_flag。通过它，实现`"软复位+再入"方案（无deinit方案)`。下面会详细讲解。

![安富莱教程封面](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528112708.png)
安富莱教程：《[实战技能分享，一劳永逸的解决BOOT跳转APP失败问题，含MDK AC5，AC6和IAR，同时制作了一个视频操作说明](https://www.armbbs.cn/forum.php?mod=viewthread&tid=109595)》
![安富莱教程截图1](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528113700.png)
![安富莱教程截图2](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528115420.png)

### 2.2.2、app_jump.h

```c
/**
  ******************************************************************************
  * @file    app_jump.h
  * @brief   Bootloader → App 跳转接口声明
  * @note    仅负责"检测 + 跳转"核心流程，便于后续复用
  * @author  Wallace
  * @date    2025-05-26
  ******************************************************************************
  */

#ifndef __APP_JUMP_H
#define __APP_JUMP_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdbool.h>
#include "main.h"

/**
  * @brief  获取固件升级标志位
  */
uint64_t IAP_GetUpdateFlag(void);

/**
  * @brief  设置固件升级标志位
  */
void IAP_SetUpdateFlag(uint64_t flag);

/**
  * @brief  准备跳转到App程序
  */
void IAP_Ready_To_Jump_App(void);

#ifdef __cplusplus
}
#endif

#endif /* __APP_JUMP_H */


```

### 2.2.3、boot_entry.c
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
    uint64_t flag = IAP_GetUpdateFlag();
    Retarget_RTT_Init(); //! RTT重定向printf
    
    log_printf("System Start!\n");
    
    /*! 检查复位更新标志 */
    if (flag == BOOTLOADER_RESET_MAGIC_WORD) {
        IAP_Ready_To_Jump_App(); //! 清理MCU环境，准备跳转App程序
    }

    /*! 后续添加升级模式判断 */
    
    
    /*! 清除固件更新标志 */
    IAP_SetUpdateFlag(0);
}
```
![boot_entry.c关键代码](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528115903.png)

### 2.2.4、boot_entry.h

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

### 2.2.5、main.c
![bootloader的main.c代码](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528120209.png)

<br>

# 三、测试
---
## 3.1、编译、烧录App
![编译烧录App截图](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528135412.png)
如上所示，先编译、烧录App到STM32F103ZET6上。

## 3.2、编译、烧录bootloader
![编译烧录bootloader截图](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528135725.png)
如上所示，编译、烧录bootloader程序到STM32F103ZET6上。

## 3.3、观察bootloader程序的RTT打印
![bootloader RTT日志](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/bootloader_rtt_log.gif)
如上，是MCU上电到跳转App之前的RTT log打印。

![RTT日志截图](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528140706.png)
如上所示，当变量fre递增到5000(时间大概5S)时，调用函数`IAP_Read_To_Jump_App()`开始清理MCU环境，准备再入bootloader程序跳转App程序。

## 3.4、观察串口助手
![串口助手截图](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528141153.png)
如上所示，从电脑的串口助手收到的消息看来，App程序正在执行！

<br>

# 四、细节补充
---
## 4.1、本章节最关键的函数IAP_Ready_To_Jump_App()

### 4.1.1、赋值 BOOTLOADER_RESET_MAGIC_WORD 的目的

![MAGIC_WORD赋值说明](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528141459.png)
代码**IAP_SetUpdateFlag(BOOTLOADER_RESET_MAGIC_WORD)** 的作用是给全局变量update_flag赋值BOOTLOADER_RESET_MAGIC_WORD，目的是只是用来做"一次性信号"，告知系统下次上电或软复位后，bootloader判断此标志，执行清理环境、跳转APP等操作。

`为什么需要"再入"+"软复位"？`软复位后，MCU的所有外设、全局状态、堆栈、时钟都会回到初始上电状态，防止"脏环境"跳转导致APP运行异常。可以彻底避免外设未关闭、DMA未关、未解初始化、IRQ未关等问题，保证APP启动环境干净。

`一句话总结:`
> "赋值为 BOOTLOADER_RESET_MAGIC_WORD，只是为了通过一次软复位，让MCU以最干净的环境跳转到APP，没有别的用途。"


## 4.2、App程序为什么要重新设置一遍SCB->VTOR?
`App初始化又把VTOR"改回去了"` 。App的启动代码（如startup_stm32f1xx.s）在执行时，很多IDE/库/工具链生成的启动代码默认会重新设置SCB->VTOR为0x08000000，即"复位地址"。所以，App程序必须手动再设置一遍中断向量表。
![VTOR设置说明](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528144703.png)

## 4.3、App程序为什么要打开全局中断__enable_irq()?
`bootloader程序在跳转App之前关闭了全局中断__disable_irq()。`App初始化不会自动打开全局中断。
![全局中断设置说明](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250528144911.png)