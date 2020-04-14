//
//  KJBleSDK.h
//  KJBleSDK
//
//  Created by apple on 2019/11/26.
//  Copyright © 2019 CoderYS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KJBleSDKObject.h"

/**
 KJCheckStatusBlock
 
 @param progress 检测进度
 @param eleStats 电极状态 0.脱离电极  1.接触电极
 @param timeOut  YES检测超时
 */
typedef void (^KJCheckStatusBlock)(float progress, int eleStats, BOOL timeOut, BOOL finish);


/**
 KJCheckFinishBlock
 
 @param ecgArray 检测完成返回心电数组 20000个8字节原始数据
 @param eleArray 检测完成返回的生物电数组  42个二维数组
 */
typedef void (^KJCheckFinishBlock)(NSMutableArray *ecgArray, NSMutableArray *eleArray);



/**
 KJQueryUpdateBlock
 
 @param isUpdate 有新固件版本才下载升级
 @param version 固件版本信息
 @param downUrl 固件下载地址
 */
typedef void (^KJQueryUpdateBlock)(BOOL isUpdate, NSString *version, NSString *downUrl);


/**
 KJUpdateStatusBlock
 
 @param progress 升级写数据进度
 @param isAllow 固件是否允许升级
 @param finish 是否升级完成
 */
typedef void (^KJUpdateStatusBlock)(float progress, BOOL isAllow, BOOL finish);


@protocol KJBleSDKDelegate <NSObject>

@optional

/**
 扫描设备返回设备列表

 @param peripherals 代理返回设备列表
 */
- (void)onScanPeripherals:(NSArray *)peripherals;

/**
 连接外设成功

 @param peripheral 外设对象
 */
- (void)onConnectSuccess:(CBPeripheral *)peripheral;

/**
 连接失败（0扫描超时、1连接超时）

 @param error 错误信息
 */
- (void)onConnectFailure:(NSError *)error;

/**
 连接中断

 @param peripheral 外设对象
 */
- (void)onDisconnectPeripheral:(CBPeripheral *)peripheral;

@end

@interface KJBleSDK : NSObject


/**
 单例对象

 @return 单例对象
 */
+ (KJBleSDK *)instance;

/**
 初始化SDK

 @param userInfo 用户Object
 @param delegate 代理者
 */
- (void)jkbInitBleSDK:(KJUserInfo *)userInfo
          delegate:(id<KJBleSDKDelegate>)delegate;

/**
 开始检测

 @param statsBlock 状态信息
 @param finishBlock 数据信息
 */
- (void)jkbStartCheck:(KJCheckStatusBlock)statsBlock
       finishBlock:(KJCheckFinishBlock)finishBlock;

/**
 检测有新版本
 
 @param queryBlock 新版本详细信息
 */
- (void)jkbCheckVersion:(KJQueryUpdateBlock)queryBlock;


/**
 固件升级
 
 @param updateBlock 升级状态
 */
- (void)jkbOtaUpdate:(NSData *)fileData
                fileName:(NSString *)fileName
                updateBlock:(KJUpdateStatusBlock)updateBlock;


/**
 开始扫描（代理获取扫码外设列表）
 */
+ (void)jkbStartScan;

/**
 停止扫描
 */
+ (void)jkbStopScan;

/**
 连接外设
 @param peripheralInfo 外设mobject
 */
+ (void)jkbConnectPeripheral:(KJPeripheralInfo *)peripheralInfo;


/**
 获取连接外设信息
 
 @return 外设信息
 */
+ (KJDeviceInfo *)jkbGetConnectDeviceInfo;

/**
 获取Api版本号
 @return Api版本号
 */
+ (NSString *)getApiVersion;

/**
 蓝牙连接状态
 @return 连接状态
 */
+ (BOOL)isConnected;

/**
 手机蓝牙状态
 @return 蓝牙状态
 */
+ (BOOL)isBleOpen;


@end



