//
//  ViewController.m
//  健康宝
//
//  Created by apple on 2018/1/22.
//  Copyright © 2018年 HEJJY. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KJBleSDKObject.h"
@class KJCentralManger;

static NSString * const KJCentralErrorScanTimeOut = @"scan time out";
static NSString * const KJCentralErrorConnectTimeOut = @"connect time out";
static NSString * const KJCentralErrorBluetoothPowerOff = @"bluetooth power off";
static NSString * const KJCentralErrorBluetoothOtherState = @"bluetooth other state";
static NSString * const KJCentralErrorConnectAutoConnectFail = @"auto connect fail";
static NSString * const KJCentralErrorWriteDataLength = @"data length error";

static NSString * const ServiceUUIDString1 = @"6E401234-5EB7-52A0-5218-632F6E24597D"; // 通讯
static NSString * const ServiceUUIDString2 = @"180F"; // 电池
static NSString * const ServiceUUIDString3 = @"180A"; // 设备信息

static NSString * const CharacteristicReadUUIDString1 = @"2A19"; // 电池电量
static NSString * const CharacteristicReadUUIDString2 = @"2A29"; // 制造商字符串
static NSString * const CharacteristicReadUUIDString3 = @"2A28"; // boot版本
static NSString * const CharacteristicReadUUIDString4 = @"2A27"; // 硬件版本
static NSString * const CharacteristicReadUUIDString5 = @"2A26"; // 固件版本
static NSString * const CharacteristicReadUUIDString6 = @"2A25"; // SN号
static NSString * const CharacteristicReadUUIDString7 = @"2A24"; // 型号

static NSString * const CharacteristicWriteUUIDString1 = @"6E400002-5EB7-52A0-5218-632F6E24597D"; // 下位机发送
static NSString * const CharacteristicNotifyUUIDString1 = @"6E400003-5EB7-52A0-5218-632F6E24597D"; // 下位机接收

@protocol KJCentralMangerDelegate <NSObject>

@optional

// 找到 Peripheral，没找到一个都会返回全部 Peripheral 的数组
- (void)centralManger:(KJCentralManger *)centralManger findPeripherals:(NSArray *)peripherals;

// 连接失败（包括超时、连接错误等）
- (void)centralManger:(KJCentralManger *)centralManger connectFailure:(NSError *)error;

// 连接成功（仅仅是 Peripheral 连接成功，如果内部的 Service 或者 Characteristic 连接失败，会走失败代理）
- (void)centralManger:(KJCentralManger *)centralManger connectSuccess:(CBPeripheral *)peripheral;

// 断开连接（准备断开就会走这个方法，具体是否真正断开要看苹果底层的实现，如果有其他 app 正连接着，不会断开）
- (void)centralManger:(KJCentralManger *)centralManger disconnectPeripheral:(CBPeripheral *)peripheral;

// 收到 Peripheral 发过来的数据
- (void)centralManger:(KJCentralManger *)centralManger characteristic:(CBCharacteristic *)characteristic recievedData:(NSData *)data;

// 写入 Peripheral 结束，如果错误则返回 error
- (void)centralManger:(KJCentralManger *)centralManger writeFinishWithError:(NSError *)error;

@end

@protocol KJCentralMangerOTADelegate <NSObject>

@optional

// ota 发送已写入的数据长度，可用于做进度条
- (void)centralManger:(KJCentralManger *)centralManger characteristic:(CBCharacteristic *)characteristic otaRecievedData:(NSData *)data;

// ota 写入完毕，也有可能是中途出错退出，可通过判断 error 来得到结果
- (void)centralManger:(KJCentralManger *)centralManger otaWriteFinishWithError:(NSError *)error;

@end

@interface KJCentralManger : NSObject

@property (weak, nonatomic) id <KJCentralMangerDelegate, KJCentralMangerOTADelegate> delegate;
@property (assign, nonatomic) BOOL isConnected; ///< 当前是否是连接状态
@property (assign, nonatomic) BOOL isBleOpen; ///手机蓝牙状态
@property (strong, nonatomic, readonly) CBCharacteristic *writeCharacteristic; ///< 需要写入的 chaeacteristic，因为有可能不止一个需要写入，所以在写入数据时，需要外部处理要写入哪一个

@property (nonatomic, copy) NSString *connectDeviceSN; /// 连接设备SN
@property (nonatomic, copy) NSString *connectDeviceName; /// 连接设备的名称


+ (KJCentralManger *)instance;

// 开始扫描
- (void)startScan;

// 停止扫描
- (void)stopScan;

// 选择一个 Peripheral
- (void)connectPeripheral:(CBPeripheral *)peripheral peripheralInfo:(KJPeripheralInfo *)peripheralInfo;

// 断开连接
- (void)disconnectWithPeripheral:(CBPeripheral *)peripheral;

// 发送普通数据，一般用于简单的命令
- (void)sendData:(Byte *)byte length:(int)length;

// 升级数据
- (void)otaSendData:(NSData *)data;

@end
