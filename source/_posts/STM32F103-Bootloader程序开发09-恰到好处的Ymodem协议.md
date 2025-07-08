---
title: STM32F103_Bootloader程序开发09 - 恰到好处的Ymodem协议
date: 2025-07-08 07:52:53
tags: [STM32, bootloader]
categories: [STM32]
description: 基于STM32F103ZET6的bootloader教程系列
---
# 导言
----
![STM32开发板](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250703230116.png)
本教程使用正点原子战舰板开发。

![Ymodem协议优势](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250624163017.png)
`Ymodem协议在功能、简易度和可靠性之间找到了一个绝佳的平衡点，非常适合资源受限的微控制器（MCU）通过串口进行固件升级的场景。`

下面我们从几个方面详细拆解为什么Ymodem如此受欢迎：
**1. 功能恰到好处，完美契合IAP需求**
与它的前辈Xmodem相比，Ymodem提供了几个对于固件升级至关重要的功能：
- 传输文件名和文件大小：这是Ymodem相对于Xmodem最关键的优势。
    - 文件名： Bootloader可以（虽然不常用）根据文件名判断是否是合法的固件。
    - 文件大小（File Size）：这是杀手级特性。在传输正式开始前，Ymodem会先发送一个包含文件名和文件大小的"头数据包"（0号数据包）。Bootloader接收到这个信息后，可以立即进行关键的预判断：
        - 空间检查：新固件的大小是否超过了Flash的可用空间？如果超过，可以直接拒绝本次升级，避免写入一半后失败。
        - 完整性校验：Bootloader知道了确切的文件大小，就可以在接收完成后，判断是否接收了完整的固件，防止因传输意外中断导致的问题。
- 批量传输（Batch Transfer）：Ymodem原生支持一次性发送多个文件。虽然在单固件升级中不常用，但这个能力在某些复杂产品（如需要同时更新字库、资源文件等）中非常有用。
- 可靠的错误校验：Ymodem使用16位CRC（循环冗余校验）进行数据校验，相比Xmodem-Checksum（8位和校验），CRC16的检错能力要强得多，这对于保证固件在传输过程中不出现位错误至关重要。一个位的错误就可能导致整个设备"变砖"。

**2. 实现简单，资源占用极低**
对于运行在MCU上的IAP Bootloader程序来说，资源（Flash和RAM）是极其宝贵的。
- 代码量小：Ymodem协议本身的状态机非常简单（等待启动、接收头数据包、接收数据、发送ACK/NAK等），实现起来代码量很小。一个精简的Ymodem接收端实现，可能只需要几百字节到一两KB的Flash空间。
- 内存（RAM）占用少：接收端只需要一个数据包缓冲区（通常是128字节或1024字节）和几个状态变量即可工作。这对于RAM只有几KB或几十KB的MCU来说是至关重要的。相比之下，一个完整的TCP/IP协议栈（如LwIP）需要几十KB的RAM和上百KB的Flash，对于一个Bootloader来说过于庞大。

**3. 历史惯性和生态系统**
- 技术传承：Ymodem诞生于上世纪80年代，在串口通信领域有着悠久的历史。许多早期的嵌入式开发者就是从这些协议开始学习的。当需要一个简单的、基于串口的文件传输协议时，Ymodem是一个自然而然的选择。
- 丰富的开源代码：网络上存在大量现成的、经过验证的Ymodem接收端和发送端代码（C语言实现）。开发者可以直接移植到自己的项目中，几乎不需要"重新造轮子"，这大大加快了IAP功能的开发速度。ST、NXP等各大MCU厂商提供的官方示例代码中，也常常包含Ymodem的IAP例程。


**Ymodem与其他协议的对比：**

|            |                               |                               |                          |
| ---------- | ----------------------------- | ----------------------------- | ------------------------ |
| 协议         | 优点                            | 缺点                            | 适用场景                     |
| **Xmodem** | 极其简单，资源占用最小                   | `无法传输文件名和大小`，检错能力弱 (Checksum) | 非常古老或资源极度受限的场景，现已很少用于IAP |
| **Ymodem** | **功能/资源/实现复杂度平衡**，传输元数据，CRC校验 | 速度不如Zmodem（停等协议），无内置安全机制      | **最经典的串口IAP场景**，资源受限的MCU |
| **Zmodem** | 速度快（流式传输，出错才重传），支持断点续传        | 实现比Ymodem复杂，资源占用稍多            | 对传输速度要求较高的场景             |

测试IAP升级：
![IAP升级演示](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/IAP_upgrade.gif)

项目地址：  
github: https://github.com/q164129345/MCU_Develop/tree/main/bootloader09_stm32f103_iap_protocol
gitee(国内): https://gitee.com/wallace89/MCU_Develop/tree/main/bootloader09_stm32f103_iap_protocol

# 一、Ymodem协议
---
## 1.1、帧结构
![Ymodem帧结构](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250614194647.png)
Ymodem协议的帧总长度由包头决定：
1. 包头=SOH(0x01)时，帧长度是128bytes + 5bytes（包头+包号+包号取反+CRC16）。
2. 同理，包头=STX(0x02)时，帧长度是1024bytes + 5bytes。

Ymodem协议的设计，有点像一个物流系统，可以选用不同尺寸的箱子来寄送货物。
- SOH (0x01): 代表一个"小箱子"，能装 128 字节的货物。
- STX (0x02): 代表一个"大箱子"，能装 1024 字节的货物。

在一次完整的"寄件"（文件传输）过程中，发送方和接收方可以协商决定主要使用哪种箱子。
1. `灵活策略（混合使用大小箱子）:`
发送方可以根据每批"货物"（数据块）的多少，来动态选择用大箱子还是小箱子。比如，大部分时候用1024字节的STX大箱子，但最后一批货物只有80字节，就可以换成128字节的SOH小箱子来装，这样更节省空间（传输带宽）。这是完全符合YMODEM协议规范的。
2. `简单策略（只用一种大箱子）`- (我的代码目前采用的策略):
类比: 为了简化流程，物流公司决定，无论货物多少，一律使用1024字节的STX大箱子。如果货物装不满，就用填充物（比如泡沫或旧报纸）把箱子塞满。

## 1.2、起始帧
![Ymodem起始帧](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250614200339.png)
我的IAP上位机统一使用STX，统一使用1024bytes的"大箱子"。另外，起始帧规定剩余的字节使用0x00填充。
"App_crc.bin"是升级的固件名称，"5284"是App_crc.bin的固件大小，表示5284bytes。

## 1.3、数据帧
![Ymodem数据帧](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250614200727.png)
包号从0x01开始，0x02、0x03.....直到，最后一帧数据。
包号取反即从0xFE开始，0xFD，0xFC....直到，最后一帧数据。

值得注意的是，最后一帧肯定没有1024bytes，剩余的内容使用0x1A填充（Ymodem协议规定）。

> 起始帧与结束帧使用0x00填充，数据帧使用0x1A填充。

## 1.4、结束帧
![Ymodem结束帧](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250614201741.png)
结束帧跟起始帧用一样的包号与包号取反，然后，内容全部用0x00填充。上位机发送结束帧，告诉下位机IAP升级正式结束。

## 1.5、其他功能帧
- ACK - 十六进制0x06 - 正确收到并确认(下位机回应上位机)
- C     - 十六进制0x43 - 开始接收文件（下位机告诉上位机）
- NAK - 十六进制0x15 - 数据错误，请重发(下位机要求上位机)
- CAN - 十六进制0x18 - 强制取消传输（下位机要求上位机，一般连续发送两次）
- EOT - 十六进制0x04 - 文件数据发送结束（上位机告诉下位机）

## 1.6、升级流程
![Ymodem升级流程](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250624095636.png)
**掌握'C'字符在YModem协议中的作用，才能更好地理解YModem协议。** 简单来说，'C' 字符在YModem协议中，是下位机（接收方）用来"催促"上位机（发送方）进行下一步操作的信号，意思是"我准备好了，请继续"。例如："收到EOT（文件传输结束）信号后"：
- 场景: 文件的所有数据包都已成功传输完毕。上位机发送一个EOT (End of Transmission) 字符，表示这个文件传完了。
- 目的: 这也是一个两段式的交流，正是我们之前修复的重点：
	1. 发送 ACK: 确认"我收到了你发的EOT信号"。
	2. 发送 C: 这是为了告诉上位机"好的，这个文件我收完了。现在我准备好接收下一个文件了。请把下一个文件的信息包（第0包）发给我。如果你没有更多文件了，就请发送一个空的结束包。"


# 二、代码
---
## 2.1、ymodem.h
```c
/**
 * @file    ymodem.h
 * @brief   YModem协议下位机实现头文件
 * @author  Wallace.zhang
 * @date    2025-06-20
 * @version 3.0.0
 * 
 * @note    这就像一个"纯粹的包裹处理专家"，完全独立于通信方式，
 *          只专注于解析YModem格式的数据包和管理固件写入流程
 *          
 *          v3.0.0 更新：完全解耦通信接口，支持任意数据源
 *          - YModem_Init() 不再需要通信接口参数
 *          - YModem_Run() 改为逐字节数据输入方式
 *          - 支持串口、网口、蓝牙、文件等任何数据源
 */

#ifndef __YMODEM_H
#define __YMODEM_H

#ifdef __cplusplus
extern "C" {
#endif

#include "main.h"
#include "flash_map.h"
#include "op_flash.h"
#include "soft_crc32.h"

/**
 * @brief YModem协议常量定义
 */
#define YMODEM_SOH              0x01    /**< 128字节数据包开始标记 */
#define YMODEM_STX              0x02    /**< 1024字节数据包开始标记 */
#define YMODEM_EOT              0x04    /**< 传输结束标记 */
#define YMODEM_ACK              0x06    /**< 应答，接收正确 */
#define YMODEM_NAK              0x15    /**< 否定应答，接收错误 */
#define YMODEM_CAN              0x18    /**< 取消传输 */
#define YMODEM_C                0x43    /**< ASCII 'C'，下位机告诉上位机，表示开始接收固件数据 */

#define YMODEM_PACKET_SIZE_128  128     /**< 128字节数据包大小 */
#define YMODEM_PACKET_SIZE_1024 1024    /**< 1024字节数据包大小 */
#define YMODEM_PACKET_HEADER_SIZE 3     /**< 包头大小：起始标记+包序号+包序号取反 */
#define YMODEM_PACKET_CRC_SIZE  2       /**< CRC校验大小 */

/**
 * @brief YModem协议状态机枚举
 */
typedef enum {
    YMODEM_STATE_IDLE = 0,              /**< 空闲状态，等待开始 */
    YMODEM_STATE_WAIT_START,            /**< 等待起始包 */
    YMODEM_STATE_WAIT_FILE_INFO,        /**< 等待文件信息包(第0包) */
    YMODEM_STATE_WAIT_DATA,             /**< 等待数据包 */
    YMODEM_STATE_RECEIVING_DATA,        /**< 正在接收数据 */
    YMODEM_STATE_WAIT_END,              /**< 等待结束包 */
    YMODEM_STATE_COMPLETE,              /**< 传输完成 */
    YMODEM_STATE_ERROR,                 /**< 错误状态 */
} YModem_State_t;

/**
 * @brief YModem数据包结构
 */
typedef struct {
    uint8_t header;                     /**< 包头标记(SOH/STX) */
    uint8_t packet_num;                 /**< 包序号 */
    uint8_t packet_num_inv;             /**< 包序号取反 */
    uint8_t data[YMODEM_PACKET_SIZE_1024]; /**< 数据部分 */
    uint16_t crc;                       /**< CRC校验值 */
} YModem_Packet_t;

/**
 * @brief YModem处理结果枚举
 */
typedef enum {
    YMODEM_RESULT_OK = 0,               /**< 处理成功 */
    YMODEM_RESULT_CONTINUE,             /**< 继续处理 */
    YMODEM_RESULT_NEED_MORE_DATA,       /**< 需要更多数据 */
    YMODEM_RESULT_ERROR,                /**< 处理错误 */
    YMODEM_RESULT_COMPLETE,             /**< 传输完成 */
} YModem_Result_t;

/**
 * @brief YModem协议处理器结构体
 * @note 完全独立的协议处理器，不依赖任何特定的通信接口
 */
typedef struct YModem_Handler {
    YModem_State_t state;               /**< 当前状态 */
    
    /* 接收缓冲区管理 */
    uint8_t rx_buffer[YMODEM_PACKET_SIZE_1024 + 5]; /**< 接收缓冲区：最大包+头尾 */
    uint16_t rx_index;                  /**< 接收缓冲区索引 */
    uint16_t expected_packet_size;      /**< 期望的包大小 */
    
    /* 数据包解析 */
    YModem_Packet_t current_packet;     /**< 当前解析的数据包 */
    uint16_t expected_packet_num;        /**< 期望的包序号 (修复：改为uint16_t支持更大包序号) */
    
    /* 文件信息 */
    char file_name[256];                /**< 文件名 */
    uint32_t file_size;                 /**< 文件大小 */
    uint32_t received_size;             /**< 已接收大小 */
    
    /* Flash写入管理 */
    uint32_t flash_write_addr;          /**< 当前Flash写入地址 */
    
    /* 错误处理 */
    uint8_t retry_count;                /**< 重试计数 */
    uint8_t max_retry;                  /**< 最大重试次数 */
    
    /* 响应数据缓冲区 */
    uint8_t response_buffer[16];        /**< 响应数据缓冲区 */
    uint8_t response_length;            /**< 响应数据长度 */
    uint8_t response_ready;             /**< 响应数据就绪标志 */
    
} YModem_Handler_t;

/* 函数声明 */

/**
 * @brief 初始化YModem协议处理器
 * @param handler: YModem处理器指针
 * @return YModem_Result_t: 初始化结果
 * 
 * @note 完全独立的初始化，不依赖任何通信接口
 *       就像准备一个纯粹的"包裹处理工作台"
 */
YModem_Result_t YModem_Init(YModem_Handler_t *handler);

/**
 * @brief YModem协议数据处理函数
 * @param handler: YModem处理器指针
 * @param data: 输入的数据字节
 * @return YModem_Result_t: 处理结果
 * 
 * @note 逐字节处理YModem协议数据，完全解耦数据来源
 *       数据可以来自串口、网口、蓝牙、文件等任何来源
 *       就像"包裹处理专家"逐个检查包裹内容
 */
YModem_Result_t YModem_Run(YModem_Handler_t *handler, uint8_t data);

/**
 * @brief 重置YModem协议处理器
 * @param handler: YModem处理器指针
 */
void YModem_Reset(YModem_Handler_t *handler);

/**
 * @brief 获取当前传输进度
 * @param handler: YModem处理器指针
 * @return uint8_t: 传输进度百分比(0-100)
 */
uint8_t YModem_Get_Progress(YModem_Handler_t *handler);

/**
 * @brief 检查是否有响应数据需要发送
 * @param handler: YModem处理器指针
 * @return uint8_t: 1-有响应数据，0-无响应数据
 * 
 * @note 检查YModem处理器是否产生了需要发送给上位机的响应数据
 */
uint8_t YModem_Has_Response(YModem_Handler_t *handler);

/**
 * @brief 获取响应数据
 * @param handler: YModem处理器指针
 * @param buffer: 存储响应数据的缓冲区
 * @param max_length: 缓冲区最大长度
 * @return uint8_t: 实际获取的响应数据长度
 * 
 * @note 获取YModem处理器产生的响应数据，用于发送给上位机
 *       获取后会自动清除响应数据缓冲区
 */
uint8_t YModem_Get_Response(YModem_Handler_t *handler, uint8_t *buffer, uint8_t max_length);

#ifdef __cplusplus
}
#endif

#endif /* __YMODEM_H */

```

## 2.2、ymodem.c
```c
/**
 * @file    ymodem.c
 * @brief   YModem协议下位机实现
 * @author  Wallace.zhang
 * @date    2025-06-20
 * @version 3.0.0
 * 
 * @note    YModem协议就像一个"纯粹的包裹处理专家"：
 *          1. 接收逐字节输入的数据（完全解耦数据来源）
 *          2. 检查包装是否完整（CRC校验）
 *          3. 按顺序整理内容（状态机管理）
 *          4. 存放到指定位置（写入Flash）
 *          5. 产生响应数据（供调用者发送给上位机）
 *          
 *          v3.0.0 更新：完全解耦通信接口，支持任意数据源
 *          - 移除所有通信接口依赖
 *          - 改为逐字节数据输入方式
 *          - 响应数据通过缓冲区输出
 */

#include "ymodem.h"
#include "retarget_rtt.h"
#include "op_flash.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

/* 私有函数声明 */
static YModem_Result_t YModem_Parse_Packet(YModem_Handler_t *handler);
static uint16_t YModem_Calculate_CRC16(const uint8_t *data, uint16_t length);
static YModem_Result_t YModem_Handle_FileInfo_Packet(YModem_Handler_t *handler);
static YModem_Result_t YModem_Handle_Data_Packet(YModem_Handler_t *handler);
static void YModem_Queue_Response(YModem_Handler_t *handler, uint8_t response);
static YModem_Result_t YModem_Write_To_Flash(YModem_Handler_t *handler, const uint8_t *data, uint16_t length);

/**
 * @brief 初始化YModem协议处理器
 * @param handler: YModem处理器指针
 * @return YModem_Result_t: 初始化结果
 * 
 * @note 就像准备一个纯粹的"包裹处理工作台"，完全独立于数据来源
 *       不依赖任何通信接口，只专注于协议处理
 */
YModem_Result_t YModem_Init(YModem_Handler_t *handler)
{
    if (handler == NULL) {
        return YMODEM_RESULT_ERROR;
    }
    
    // 初始化基本参数
    handler->state = YMODEM_STATE_IDLE;
    handler->max_retry = 3;  // 最大重试3次
    
    // 重置所有状态
    YModem_Reset(handler);
    
    log_printf("YModem: initialized successfully.\r\n");
    return YMODEM_RESULT_OK;
}

/**
 * @brief 重置YModem协议处理器
 * @param handler: YModem处理器指针
 * 
 * @note 就像清空收件箱，重新开始接收
 */
void YModem_Reset(YModem_Handler_t *handler)
{
    if (handler == NULL) return;
    
    // 重要：强制重置为等待文件信息状态，确保能接收新传输
    handler->state = YMODEM_STATE_WAIT_FILE_INFO;
    handler->rx_index = 0;
    handler->expected_packet_size = 0;
    handler->expected_packet_num = 0;
    handler->file_size = 0;
    handler->received_size = 0;
    handler->flash_write_addr = FLASH_DL_START_ADDR;
    handler->retry_count = 0;
    
    // 重置响应缓冲区
    handler->response_length = 0;
    handler->response_ready = 0;
    
    // 清空所有缓冲区
    memset(handler->rx_buffer, 0, sizeof(handler->rx_buffer));
    memset(handler->file_name, 0, sizeof(handler->file_name));
    memset(&handler->current_packet, 0, sizeof(handler->current_packet));
    memset(handler->response_buffer, 0, sizeof(handler->response_buffer));
    
    log_printf("YModem: reset successfully, ready for new transmission.\r\n");
}

/**
 * @brief YModem协议数据处理函数
 * @param handler: YModem处理器指针
 * @param data: 输入的数据字节
 * @return YModem_Result_t: 处理结果
 * 
 * @note 逐字节处理YModem协议数据，完全解耦数据来源
 *       数据可以来自串口、网口、蓝牙、文件等任何来源
 *       就像"包裹处理专家"逐个检查包裹内容
 */
YModem_Result_t YModem_Run(YModem_Handler_t *handler, uint8_t data)
{
    if (handler == NULL) {
        return YMODEM_RESULT_ERROR;
    }
    
    // 根据当前状态处理数据
    switch (handler->state) {
        case YMODEM_STATE_WAIT_FILE_INFO:
        case YMODEM_STATE_WAIT_DATA:
        case YMODEM_STATE_COMPLETE:  // 完成状态也要能接收新的传输请求
            // 检查是否是包头（只有在等待包头时才处理控制字符）
            if (handler->rx_index == 0) {
                if (data == YMODEM_STX) {
                    // 如果是完成状态收到新的传输请求，自动重置并开始新传输
                    if (handler->state == YMODEM_STATE_COMPLETE) {
                        log_printf("YModem: new transmission request in complete state, auto reset.\r\n");
                        YModem_Reset(handler);
                    }
                    handler->expected_packet_size = YMODEM_PACKET_SIZE_1024;
                    handler->rx_buffer[handler->rx_index++] = data;
                } else if (data == YMODEM_SOH) {
                    // 如果是完成状态收到新的传输请求，自动重置并开始新传输
                    if (handler->state == YMODEM_STATE_COMPLETE) {
                        log_printf("YModem: new transmission request in complete state, auto reset.\r\n");
                        YModem_Reset(handler);
                    }
                    handler->expected_packet_size = YMODEM_PACKET_SIZE_128;
                    handler->rx_buffer[handler->rx_index++] = data;
                } else if (data == YMODEM_EOT) {
                    // 在等待数据包时收到EOT，说明传输结束
                    log_printf("YModem: received EOT, transmission end.\r\n");
                    YModem_Queue_Response(handler, YMODEM_ACK);
                    // 修复：EOT后发送C字符，请求下一个文件（或结束包）
                    YModem_Queue_Response(handler, YMODEM_C);
                    handler->state = YMODEM_STATE_WAIT_END;
                    return YMODEM_RESULT_OK;
                } else if (data == YMODEM_CAN) {
                    // 在等待数据包时收到CAN，说明传输取消
                    log_printf("YModem: received CAN, transmission canceled.\r\n");
                    handler->state = YMODEM_STATE_ERROR;
                    return YMODEM_RESULT_ERROR;
                } else {
                    // 不是有效包头或控制字符，忽略
                    return YMODEM_RESULT_CONTINUE;
                }
            } else {
                // 正在接收数据包过程中，所有字节都当作数据处理，不检查控制字符
                if (handler->rx_index >= sizeof(handler->rx_buffer)) {
                    log_printf("YModem: rx buffer overflow, reset.\r\n");
                    handler->rx_index = 0;
                    return YMODEM_RESULT_ERROR;
                }
                
                handler->rx_buffer[handler->rx_index++] = data;
                
                // 检查是否接收完整个包
                uint16_t total_size = YMODEM_PACKET_HEADER_SIZE + 
                                    handler->expected_packet_size + 
                                    YMODEM_PACKET_CRC_SIZE;
                
                if (handler->rx_index >= total_size) {
                    return YModem_Parse_Packet(handler);
                }
            }
            break;
            
        case YMODEM_STATE_WAIT_END:
            // 等待结束包（空文件名包）或EOT
            if (handler->rx_index == 0) {
                if (data == YMODEM_EOT) {
                    log_printf("YModem: received EOT, transmission end.\r\n");
                    YModem_Queue_Response(handler, YMODEM_ACK);
                    // 修复：EOT后发送C字符，请求下一个文件（或结束包）
                    YModem_Queue_Response(handler, YMODEM_C);
                    return YMODEM_RESULT_OK;
                } else if (data == YMODEM_STX) {
                    handler->expected_packet_size = YMODEM_PACKET_SIZE_1024;
                    handler->rx_buffer[handler->rx_index++] = data;
                } else if (data == YMODEM_CAN) {
                    log_printf("YModem: received CAN, transmission canceled.\r\n");
                    handler->state = YMODEM_STATE_ERROR;
                    return YMODEM_RESULT_ERROR;
                } else {
                    // 忽略其他字符
                    return YMODEM_RESULT_CONTINUE;
                }
            } else {
                // 正在接收结束包过程中，所有字节都当作数据处理
                if (handler->rx_index >= sizeof(handler->rx_buffer)) {
                    log_printf("YModem: rx buffer overflow in end state, reset.\r\n");
                    handler->rx_index = 0;
                    return YMODEM_RESULT_ERROR;
                }
                
                handler->rx_buffer[handler->rx_index++] = data;
                
                uint16_t total_size = YMODEM_PACKET_HEADER_SIZE + 
                                    handler->expected_packet_size + 
                                    YMODEM_PACKET_CRC_SIZE;
                
                if (handler->rx_index >= total_size) {
                    // 解析结束包
                    YModem_Result_t result = YModem_Parse_Packet(handler);
                    if (result == YMODEM_RESULT_OK) {
                        log_printf("YModem: transmission completed! total received %u bytes.\r\n", handler->received_size);
                        handler->state = YMODEM_STATE_COMPLETE;
                        YModem_Queue_Response(handler, YMODEM_ACK);
                        return YMODEM_RESULT_COMPLETE;
                    }
                }
            }
            break;
            
        default:
            break;
    }
    
    return YMODEM_RESULT_CONTINUE;
}

/**
 * @brief 解析YModem数据包
 * @param handler: YModem处理器指针
 * @return YModem_Result_t: 解析结果
 * 
 * @note 就像拆开快递包装，检查内容是否完整正确
 */
static YModem_Result_t YModem_Parse_Packet(YModem_Handler_t *handler)
{
    // 提取包头信息
    handler->current_packet.header = handler->rx_buffer[0];
    handler->current_packet.packet_num = handler->rx_buffer[1];
    handler->current_packet.packet_num_inv = handler->rx_buffer[2];
    
    // 检查包序号的完整性
    if ((handler->current_packet.packet_num + handler->current_packet.packet_num_inv) != 0xFF) {
        log_printf("YModem: packet number verification failed.\r\n");
        YModem_Queue_Response(handler, YMODEM_NAK);
        handler->rx_index = 0;
        
        // 修复：增加重试计数和错误处理
        handler->retry_count++;
        if (handler->retry_count >= handler->max_retry) {
            log_printf("YModem: max retry count reached, abort.\r\n");
            handler->state = YMODEM_STATE_ERROR;
        }
        
        return YMODEM_RESULT_ERROR;
    }
    
    // 提取数据部分
    memcpy(handler->current_packet.data, 
           &handler->rx_buffer[YMODEM_PACKET_HEADER_SIZE], 
           handler->expected_packet_size);
    
    // 提取CRC校验值
    uint16_t crc_offset = YMODEM_PACKET_HEADER_SIZE + handler->expected_packet_size;
    handler->current_packet.crc = (handler->rx_buffer[crc_offset] << 8) | 
                                  handler->rx_buffer[crc_offset + 1];
    
    // 计算并验证CRC
    uint16_t calculated_crc = YModem_Calculate_CRC16(handler->current_packet.data, 
                                                    handler->expected_packet_size);
    
    if (calculated_crc != handler->current_packet.crc) {
        log_printf("YModem: CRC verification failed, calculated value=0x%04X, received value=0x%04X\r\n", 
                  calculated_crc, handler->current_packet.crc);
        YModem_Queue_Response(handler, YMODEM_NAK);
        handler->rx_index = 0;
        
        // 修复：增加重试计数和错误处理
        handler->retry_count++;
        if (handler->retry_count >= handler->max_retry) {
            log_printf("YModem: max retry count reached, abort.\r\n");
            handler->state = YMODEM_STATE_ERROR;
        }
        
        return YMODEM_RESULT_ERROR;
    }
    
    // 重置接收缓冲区
    handler->rx_index = 0;
    
    // 修复：成功处理包后重置重试计数
    handler->retry_count = 0;
    
    // 根据包序号处理不同类型的包
    if (handler->current_packet.packet_num == 0) {
        // 第0包：文件信息包
        return YModem_Handle_FileInfo_Packet(handler);
    } else {
        // 数据包
        return YModem_Handle_Data_Packet(handler);
    }
}

/**
 * @brief 计算CRC16校验值
 * @param data: 数据指针
 * @param length: 数据长度
 * @return uint16_t: CRC16校验值
 * 
 * @note 使用CRC-16/XMODEM算法，就像给包裹贴上防伪标签
 */
static uint16_t YModem_Calculate_CRC16(const uint8_t *data, uint16_t length)
{
    uint16_t crc = 0x0000;
    
    for (uint16_t i = 0; i < length; i++) {
        crc ^= (data[i] << 8);
        for (uint8_t j = 0; j < 8; j++) {
            if (crc & 0x8000) {
                crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
            } else {
                crc = (crc << 1) & 0xFFFF;
            }
        }
    }
    
    return crc;
}

/**
 * @brief 处理文件信息包（第0包）
 * @param handler: YModem处理器指针
 * @return YModem_Result_t: 处理结果
 * 
 * @note 就像查看快递单上的收件信息：文件名、大小等
 */
static YModem_Result_t YModem_Handle_FileInfo_Packet(YModem_Handler_t *handler)
{
    // 检查是否是结束包（空文件名）
    if (handler->current_packet.data[0] == 0) {
        log_printf("YModem: received end packet.\r\n");
        handler->state = YMODEM_STATE_COMPLETE;
        YModem_Queue_Response(handler, YMODEM_ACK);
        log_printf("YModem: transmission completed, returning YMODEM_RESULT_COMPLETE.\r\n");
        return YMODEM_RESULT_COMPLETE;
    }
    
    // 解析文件名
    char *filename_ptr = (char *)handler->current_packet.data;
    
    // 修复：检查文件名长度，防止缓冲区溢出
    // 手动实现strnlen功能，因为某些编译器不支持strnlen
    size_t filename_len = 0;
    const char *temp_ptr = filename_ptr;
    while (filename_len < handler->expected_packet_size && *temp_ptr != '\0') {
        filename_len++;
        temp_ptr++;
    }
    
    if (filename_len >= sizeof(handler->file_name)) {
        log_printf("YModem: filename too long (%u bytes), max allowed %u bytes.\r\n", 
                  (unsigned int)filename_len, (unsigned int)(sizeof(handler->file_name) - 1));
        YModem_Queue_Response(handler, YMODEM_CAN);
        handler->state = YMODEM_STATE_ERROR;
        return YMODEM_RESULT_ERROR;
    }
    
    strncpy(handler->file_name, filename_ptr, sizeof(handler->file_name) - 1);
    handler->file_name[sizeof(handler->file_name) - 1] = '\0';
    
    // 查找文件大小（在文件名后的第一个NULL之后）
    char *size_ptr = filename_ptr + strlen(filename_ptr) + 1;
    
    // 修复：检查size_ptr是否在有效范围内
    if (size_ptr >= (char*)handler->current_packet.data + handler->expected_packet_size) {
        log_printf("YModem: invalid file size field position.\r\n");
        YModem_Queue_Response(handler, YMODEM_CAN);
        handler->state = YMODEM_STATE_ERROR;
        return YMODEM_RESULT_ERROR;
    }
    
    handler->file_size = (uint32_t)atol(size_ptr);
    
    log_printf("YModem: file information - name: %s, size: %u bytes.\r\n", 
              handler->file_name, handler->file_size);
    
    // 检查文件大小是否超出Flash缓存区容量
    if (handler->file_size > FLASH_DL_SIZE) {
        log_printf("YModem: error! file size %u exceeds cache size %u.\r\n", 
                  handler->file_size, (uint32_t)FLASH_DL_SIZE);
        YModem_Queue_Response(handler, YMODEM_CAN);
        handler->state = YMODEM_STATE_ERROR;
        return YMODEM_RESULT_ERROR;
    }
    
    // 准备接收数据包
    handler->expected_packet_num = 1;
    handler->received_size = 0;
    handler->flash_write_addr = FLASH_DL_START_ADDR;
    handler->state = YMODEM_STATE_WAIT_DATA;
    
    // 发送ACK和'C'，表示准备接收数据
    YModem_Queue_Response(handler, YMODEM_ACK);
    YModem_Queue_Response(handler, YMODEM_C);
    
    return YMODEM_RESULT_OK;
}

/**
 * @brief 处理数据包
 * @param handler: YModem处理器指针
 * @return YModem_Result_t: 处理结果
 * 
 * @note 就像把快递内容按顺序整理存放到仓库
 */
static YModem_Result_t YModem_Handle_Data_Packet(YModem_Handler_t *handler)
{
    // 检查包序号是否正确
    if (handler->current_packet.packet_num != handler->expected_packet_num) {
        log_printf("YModem: packet number error, expected %u, received %u.\r\n", 
                  handler->expected_packet_num, handler->current_packet.packet_num);
        YModem_Queue_Response(handler, YMODEM_NAK);
        
        // 修复：增加重试计数和错误处理
        handler->retry_count++;
        if (handler->retry_count >= handler->max_retry) {
            log_printf("YModem: max retry count reached, abort.\r\n");
            handler->state = YMODEM_STATE_ERROR;
        }
        
        return YMODEM_RESULT_ERROR;
    }
    
    // 计算本包实际有效数据长度
    uint16_t valid_data_length = handler->expected_packet_size;
    uint32_t remaining_size = handler->file_size - handler->received_size;
    
    if (remaining_size < handler->expected_packet_size) {
        valid_data_length = (uint16_t)remaining_size;
    }
    
    // 写入Flash
    YModem_Result_t result = YModem_Write_To_Flash(handler, 
                                                  handler->current_packet.data, 
                                                  valid_data_length);
    
    if (result != YMODEM_RESULT_OK) {
        log_printf("YModem: Flash write failed.\r\n");
        YModem_Queue_Response(handler, YMODEM_CAN);
        handler->state = YMODEM_STATE_ERROR;
        return YMODEM_RESULT_ERROR;
    }
    
    // 更新状态
    handler->received_size += valid_data_length;
    handler->expected_packet_num++;

    // 打印进度（每收到1个包打印一次）
    uint8_t progress = YModem_Get_Progress(handler);
    log_printf("YModem: progress %d%% (%u/%u bytes).\r\n", 
              progress, handler->received_size, handler->file_size);

    // 发送ACK确认
    YModem_Queue_Response(handler, YMODEM_ACK);
    
    // 检查是否接收完成
    if (handler->received_size >= handler->file_size) {
        log_printf("YModem: data received completed, waiting for EOT.\r\n");
        handler->state = YMODEM_STATE_WAIT_END;
    }
    
    return YMODEM_RESULT_OK;
}

/**
 * @brief 将数据写入Flash（使用op_flash模块重构版本）
 * @param handler: YModem处理器指针
 * @param data: 要写入的数据
 * @param length: 数据长度
 * @return YModem_Result_t: 写入结果
 * 
 * @note 使用op_flash模块进行Flash操作，提高代码复用性和可维护性
 *       就像使用专业的"仓库管理系统"来存放货物，而不是直接操作货架
 */
static YModem_Result_t YModem_Write_To_Flash(YModem_Handler_t *handler, 
                                           const uint8_t *data, 
                                           uint16_t length)
{
    // 检查Flash地址范围
    if (handler->flash_write_addr + length > FLASH_DL_END_ADDR) {
        log_printf("YModem: Flash address out of range.\r\n");
        return YMODEM_RESULT_ERROR;
    }
    
    // 确保Flash写入地址4字节对齐
    if (handler->flash_write_addr % 4 != 0) {
        log_printf("YModem: Flash address not aligned to 4 bytes: 0x%08lX.\r\n", 
                  (unsigned long)handler->flash_write_addr);
        return YMODEM_RESULT_ERROR;
    }
    
    // 检查是否需要擦除Flash页面
    // 当写入地址是页面起始地址时，需要先擦除该页面
    uint32_t page_start = (handler->flash_write_addr / STM32_FLASH_PAGE_SIZE) * STM32_FLASH_PAGE_SIZE;
    if (handler->flash_write_addr == page_start) {
        log_printf("YModem: erase Flash page 0x%08X.\r\n", page_start);
        
        // 使用op_flash模块擦除页面
        OP_FlashStatus_t erase_result = OP_Flash_Erase(page_start, STM32_FLASH_PAGE_SIZE);
        if (erase_result != OP_FLASH_OK) {
            log_printf("YModem: Flash erase failed, op_flash error code=%d.\r\n", erase_result);
            return YMODEM_RESULT_ERROR;
        }
    }
    
    // 准备4字节对齐的数据缓冲区（使用固定大小缓冲区避免VLA问题）
    uint16_t aligned_length = (length + 3) & ~3;  // 向上对齐到4字节边界
    static uint8_t aligned_buffer[YMODEM_PACKET_SIZE_1024 + 4];  // 静态缓冲区，足够大
    
    // 检查缓冲区大小
    if (aligned_length > sizeof(aligned_buffer)) {
        log_printf("YModem: aligned data too large for buffer.\r\n");
        return YMODEM_RESULT_ERROR;
    }
    
    // 复制数据到对齐缓冲区，不足部分填充0xFF
    memcpy(aligned_buffer, data, length);
    if (aligned_length > length) {
        memset(aligned_buffer + length, 0xFF, aligned_length - length);
    }
    
    // 使用op_flash模块写入数据
    OP_FlashStatus_t write_result = OP_Flash_Write(handler->flash_write_addr, 
                                                  aligned_buffer, 
                                                  aligned_length);
    
    if (write_result != OP_FLASH_OK) {
        log_printf("YModem: Flash write failed, op_flash error code=%d.\r\n", write_result);
        return YMODEM_RESULT_ERROR;
    }
    
    log_printf("YModem: successfully written %d bytes to address 0x%04X%04X.\r\n", 
              length, (uint16_t)(handler->flash_write_addr >> 16), (uint16_t)(handler->flash_write_addr & 0xFFFF));
    
    // 更新Flash写入地址
    handler->flash_write_addr += aligned_length;
    
    return YMODEM_RESULT_OK;
}

/**
 * @brief 将响应数据加入队列
 * @param handler: YModem处理器指针
 * @param response: 响应字节
 * 
 * @note 就像把要寄出的回执信放进信箱，等待邮递员来取
 *       完全解耦发送方式，由调用者决定如何发送
 */
static void YModem_Queue_Response(YModem_Handler_t *handler, uint8_t response)
{
    if (handler == NULL) return;
    
    // 检查响应缓冲区是否还有空间
    if (handler->response_length < sizeof(handler->response_buffer)) {
        handler->response_buffer[handler->response_length++] = response;
        handler->response_ready = 1;
        
        log_printf("YModem: response data added to queue: 0x%02X.\r\n", response);
    } else {
        log_printf("YModem: warning! response buffer is full, discard response: 0x%02X.\r\n", response);
    }
}

/**
 * @brief 获取当前传输进度
 * @param handler: YModem处理器指针
 * @return uint8_t: 传输进度百分比(0-100)
 * 
 * @note 就像查看快递配送进度
 */
uint8_t YModem_Get_Progress(YModem_Handler_t *handler)
{
    if (handler == NULL || handler->file_size == 0) {
        return 0;
    }
    
    return (uint8_t)((handler->received_size * 100) / handler->file_size);
}

/**
 * @brief 检查是否有响应数据需要发送
 * @param handler: YModem处理器指针
 * @return uint8_t: 1-有响应数据，0-无响应数据
 * 
 * @note 检查信箱里是否有待发送的回执信
 */
uint8_t YModem_Has_Response(YModem_Handler_t *handler)
{
    if (handler == NULL) {
        return 0;
    }
    
    return handler->response_ready;
}

/**
 * @brief 获取响应数据
 * @param handler: YModem处理器指针
 * @param buffer: 存储响应数据的缓冲区
 * @param max_length: 缓冲区最大长度
 * @return uint8_t: 实际获取的响应数据长度
 * 
 * @note 从信箱取出所有待发送的回执信，取出后信箱就空了
 */
uint8_t YModem_Get_Response(YModem_Handler_t *handler, uint8_t *buffer, uint8_t max_length)
{
    if (handler == NULL || buffer == NULL || max_length == 0) {
        return 0;
    }
    
    if (!handler->response_ready || handler->response_length == 0) {
        return 0;
    }
    
    // 计算实际复制的长度
    uint8_t copy_length = (handler->response_length > max_length) ? 
                         max_length : handler->response_length;
    
    // 复制响应数据
    memcpy(buffer, handler->response_buffer, copy_length);
    
    // 清空响应缓冲区
    handler->response_length = 0;
    handler->response_ready = 0;
    memset(handler->response_buffer, 0, sizeof(handler->response_buffer));
    
    log_printf("YModem: successfully obtained %d bytes of response data.\r\n", copy_length);
    
    return copy_length;
}

```

# 三、YModem_README.md
---
## 概述
这是一个完全解耦的YModem协议下位机实现，专门为STM32F103系列微控制器设计。它就像一个"纯粹的包裹处理专家"，能够：

- 接收来自任何数据源的YModem格式数据（串口、网口、蓝牙、文件等）
- 验证数据包的完整性（CRC16校验）
- 将固件数据写入Flash存储器的指定区域
- 提供传输进度反馈
- 完全独立于通信接口，支持任意数据源

## 文件结构
```
IAP/
├── ymodem.h                    # YModem协议头文件
├── ymodem.c                    # YModem协议实现
├── YModem_README.md            # 本说明文件
└── (已删除旧版示例文件)
```

## 使用方法

### 1. 实际项目中的集成方式
根据当前项目的实际实现，YModem协议已经完全集成到`main.c`中：
```c
#include "ymodem.h"
#include "bsp_usart_hal.h"

// 全局变量声明
YModem_Handler_t gYModemHandler;
USART_Driver_t gUsart1Drv;

int main(void)
{
    // 系统初始化
    HAL_Init();
    SystemClock_Config();
    MX_GPIO_Init();
    MX_DMA_Init();
    MX_USART1_UART_Init();
    
    // USART1初始化
    USART_Config(&gUsart1Drv,
                 gUsart1RXDMABuffer, gUsart1RXRBBuffer, sizeof(gUsart1RXDMABuffer),
                 gUsart1TXDMABuffer, gUsart1TXRBBuffer, sizeof(gUsart1TXDMABuffer));
    
    // YModem协议处理器初始化（完全解耦版本）
    YModem_Init(&gYModemHandler);
    
    log_printf("Bootloader init successfully.\n");
    
    uint32_t fre = 0;
    while (1) {
        // 2ms周期执行YModem协议处理
        if (0 == fre % 2) {
            // YModem协议处理 - 逐字节从ringbuffer里拿出数据来解析
            while(USART_Get_The_Existing_Amount_Of_Data(&gUsart1Drv)) {
                uint8_t data;
                if (USART_Take_A_Piece_Of_Data(&gUsart1Drv, &data)) {
                    YModem_Result_t ymodem_result = YModem_Run(&gYModemHandler, data);
                    
                    // 检查YModem传输结果
                    if (ymodem_result == YMODEM_RESULT_COMPLETE) {
                        log_printf("YModem: 固件升级完成！准备校验和复制...\r\n");
                        // 这里可以触发固件校验和复制流程
                        // 重置YModem处理器，准备下次传输
                        YModem_Reset(&gYModemHandler);
                    } else if (ymodem_result == YMODEM_RESULT_ERROR) {
                        log_printf("YModem: 传输出错，重置协议处理器\r\n");
                        YModem_Reset(&gYModemHandler);
                    }
                }
            }
            
            // 检查是否有YModem响应数据需要发送
            if (YModem_Has_Response(&gYModemHandler)) {
                uint8_t response_buffer[16];
                uint8_t response_length = YModem_Get_Response(&gYModemHandler, 
                                                             response_buffer, 
                                                             sizeof(response_buffer));
                if (response_length > 0) {
                    // 将响应数据发送给上位机
                    USART_Put_TxData_To_Ringbuffer(&gUsart1Drv, response_buffer, response_length);
                }
            }
            
            USART_Module_Run(&gUsart1Drv); // Usart1模块运行
        }
        
        fre++;
        HAL_Delay(1);
    }
}
```

### 2. 关键集成要点
1. **初始化顺序**：
   ```c
   // 1. 先初始化USART驱动
   USART_Config(&gUsart1Drv, ...);
   
   // 2. 再初始化YModem处理器
   YModem_Init(&gYModemHandler);
   ```

2. **数据处理流程**：
   ```c
   // 在2ms定时循环中处理
   while(USART_Get_The_Existing_Amount_Of_Data(&gUsart1Drv)) {
       uint8_t data;
       if (USART_Take_A_Piece_Of_Data(&gUsart1Drv, &data)) {
           YModem_Result_t result = YModem_Run(&gYModemHandler, data);
           // 处理结果...
       }
   }
   ```

3. **响应数据处理**：
   ```c
   if (YModem_Has_Response(&gYModemHandler)) {
       uint8_t response_buffer[16];
       uint8_t length = YModem_Get_Response(&gYModemHandler, response_buffer, sizeof(response_buffer));
       if (length > 0) {
           USART_Put_TxData_To_Ringbuffer(&gUsart1Drv, response_buffer, length);
       }
   }
   ```

### 3. 传输完成后的处理
当YModem传输完成后，您可以在代码中添加固件校验和复制逻辑：
```c
if (ymodem_result == YMODEM_RESULT_COMPLETE) {
    log_printf("YModem: 固件升级完成！准备校验和复制...\r\n");
    
    // 可选：添加固件校验和复制逻辑
    // if (HAL_OK == FW_Firmware_Verification(FLASH_DL_START_ADDR, FW_TOTAL_LEN)) {
    //     if (OP_FLASH_OK == OP_Flash_Copy(FLASH_DL_START_ADDR, FLASH_APP_START_ADDR, FLASH_APP_SIZE)) {
    //         log_printf("固件复制成功，准备跳转App\r\n");
    //         Delay_MS_By_NOP(500);
    //         IAP_Ready_To_Jump_App();
    //     }
    // }
    
    YModem_Reset(&gYModemHandler);
}
```

## API参考

### 主要函数

#### `YModem_Init()`
```c
YModem_Result_t YModem_Init(YModem_Handler_t *handler);
```
- **功能**: 初始化YModem协议处理器
- **参数**: `handler`: YModem处理器指针
- **返回**: 初始化结果
- **说明**: 完全独立的初始化，不依赖任何通信接口
- **新增**: 自动设置最大重试次数为3次

#### `YModem_Run()`
```c
YModem_Result_t YModem_Run(YModem_Handler_t *handler, uint8_t data);
```
- **功能**: 逐字节处理YModem协议数据
- **参数**: 
  - `handler`: YModem处理器指针
  - `data`: 输入的数据字节
- **返回**: 处理结果
- **说明**: 完全解耦数据来源，支持任何数据源

#### `YModem_Reset()`
```c
void YModem_Reset(YModem_Handler_t *handler);
```
- **功能**: 重置YModem处理器状态
- **参数**: `handler`: YModem处理器指针

#### `YModem_Get_Progress()`
```c
uint8_t YModem_Get_Progress(YModem_Handler_t *handler);
```
- **功能**: 获取传输进度
- **参数**: `handler`: YModem处理器指针
- **返回**: 进度百分比（0-100）

#### `YModem_Has_Response()`
```c
uint8_t YModem_Has_Response(YModem_Handler_t *handler);
```
- **功能**: 检查是否有响应数据需要发送
- **参数**: `handler`: YModem处理器指针
- **返回**: 1-有响应数据，0-无响应数据

#### `YModem_Get_Response()`
```c
uint8_t YModem_Get_Response(YModem_Handler_t *handler, uint8_t *buffer, uint8_t max_length);
```
- **功能**: 获取响应数据
- **参数**: 
  - `handler`: YModem处理器指针
  - `buffer`: 存储响应数据的缓冲区
  - `max_length`: 缓冲区最大长度
- **返回**: 实际获取的响应数据长度
- **说明**: 获取后会自动清除响应数据缓冲区

## 协议流程
### 1. 上位机发送流程
```
上位机 → 第0包（文件信息）→ 下位机
下位机 → ACK + 'C' → 上位机
上位机 → 第1包（数据）→ 下位机
下位机 → ACK → 上位机
...（重复数据包传输）
上位机 → EOT → 下位机
下位机 → ACK → 上位机
上位机 → 结束包（空文件名）→ 下位机
下位机 → ACK → 上位机
```

### 2. 数据包格式
```
STX(0x02) | 包序号 | 包序号取反 | 1024字节数据 | CRC16高字节 | CRC16低字节
```

## 内存映射
根据`flash_map.h`的定义：
```c
#define FLASH_DL_START_ADDR    0x08040000U  // App下载缓存区起始地址
#define FLASH_DL_END_ADDR      0x0806FFFFU  // App下载缓存区结束地址
#define FLASH_DL_SIZE          (192 * 1024) // 缓存区大小：192KB
```

## 错误处理
### 1. CRC校验失败
- 发送NAK给上位机
- 要求重传当前包
- **新增**：自动重试计数，达到最大次数后终止传输

### 2. 包序号错误
- 发送NAK给上位机
- 要求重传当前包
- **新增**：智能重试机制，防止无限重试

### 3. Flash写入失败
- 发送CAN取消传输
- 进入错误状态

### 4. 地址超出范围
- 发送CAN取消传输
- 记录错误日志

### 5. 缓冲区溢出保护
- 文件名长度检查，防止缓冲区溢出
- 数据指针有效性验证
- 自动错误恢复机制

### 扩展到其他数据源的方法
如果需要支持其他数据源，只需要：

```c
// 示例：从CAN总线接收YModem数据
while(CAN_Get_Received_Data_Count() > 0) {
    uint8_t data;
    if (CAN_Get_One_Byte(&data)) {
        YModem_Result_t result = YModem_Run(&gYModemHandler, data);
        // 处理结果...
    }
}

// 示例：从网口接收YModem数据  
while(Ethernet_Has_Data()) {
    uint8_t data;
    if (Ethernet_Read_Byte(&data)) {
        YModem_Result_t result = YModem_Run(&gYModemHandler, data);
        // 处理结果...
    }
}
```

## 常见问题排查
如果遇到问题，请按以下顺序检查：

1. **串口通信**：
   - 确认USART1配置正确（波特率、数据位、停止位等）
   - 检查DMA配置是否正常
   - 验证ringbuffer是否正常工作

2. **YModem协议**：
   - 检查上位机发送的YModem格式是否正确
   - 确认CRC16校验算法一致
   - 验证数据包大小设置（1024字节）

3. **Flash操作**：
   - 确认Flash地址映射配置正确
   - 检查Flash擦除和写入权限
   - 验证地址范围是否在有效区域内

4. **调试信息**：
   - 确保RTT配置正确，能正常输出日志
   - 检查log_printf函数是否正常工作
   - 观察YModem传输过程中的详细日志


# 四、细节补充
----
## 4.1、运行IAP上位机，开始IAP升级
![main.c代码](https://raw.githubusercontent.com/q164129345/Obsidian_Repo/master/%E9%99%84%E4%BB%B6%E5%AD%98%E6%94%BE/Pasted%20image%2020250624190653.png)
