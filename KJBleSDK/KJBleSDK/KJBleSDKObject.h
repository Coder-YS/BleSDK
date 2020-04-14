//
//  KJBleSDKObject.h
//  KJBleSDK
//
//  Created by apple on 2019/11/26.
//  Copyright © 2019 CoderYS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

typedef enum : NSUInteger {
    KJTimeOutTypeScan     = 0,
    KJTimeOutTypeConnect  = 1
    
} KJTimeOutType;

/// 蓝牙连接错误码
static NSInteger const KJCentralErrorCodeScanTimeOut = 1000; // 扫描超时
static NSInteger const KJCentralErrorCodeConnectTimeOut = 1001; // 连接超时
static NSInteger const KJCentralErrorCodeBluetoothPowerOff = 1002; // 蓝牙关闭
static NSInteger const KJCentralErrorCodeBluetoothOtherState = 1003; // 除了蓝牙打开关闭的其他状态
static NSInteger const KJCentralErrorCodeAutoConnectFail = 1004; // 自动连接失败
static NSInteger const KJCentralErrorCodeWriteDataLength = 1005; // 写如数据不正确

// 设备SN
static NSString * const LastDeviceSNIdentifierConnectedKey = @"LastDeviceSNIdentifierConnectedKey";
// 设备名
static NSString * const LastDeviceNameIdentifierConnectedKey = @"LastDeviceNameIdentifierConnectedKey";

@interface KJUserInfo : NSObject

// 用户年龄
@property (nonatomic, assign) int age;

// 用户性别 （0.女 1.男）
@property (nonatomic, assign) int sex;

// 用户身高
@property (nonatomic, assign) float height;

// 用户体重
@property (nonatomic, assign) float weight;

@end

// 扫描外设信息
@interface KJPeripheralInfo : NSObject

// 设备名
@property (nonatomic, copy) NSString *device_name;

// 设备SN
@property (nonatomic, copy) NSString *device_sn;

// 设备类型
@property (nonatomic, copy) NSString *device_type;

// 设备
@property (nonatomic, strong) CBPeripheral *peripheral;

// 设备连接状态
@property (nonatomic, assign) BOOL connected;

// 设备标识
@property (nonatomic, copy) NSString *identifier;

@end


// 连接设备信息
@interface KJDeviceInfo : NSObject

// 外设名
@property (nonatomic, copy) NSString *device_name;

// 电池电量
@property (nonatomic, assign) int battery;

// 制造商
@property (nonatomic, copy) NSString *company;

// boot版本
@property (nonatomic, copy) NSString *boot_version;

 // 硬件版本
@property (nonatomic, copy) NSString *hardware_version;

 // 固件版本
@property (nonatomic, copy) NSString *firmware_version;

// 设备sn
@property (nonatomic, copy) NSString *device_sn;

// 设备型号
@property (nonatomic, copy) NSString *device_type;

// 单例对象
+ (KJDeviceInfo *)instance;

@end



