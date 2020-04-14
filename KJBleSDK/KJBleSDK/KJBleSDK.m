//
//  KJBleSDK.m
//  KJBleSDK
//
//  Created by apple on 2019/11/26.
//  Copyright © 2019 CoderYS. All rights reserved.
//

#import "KJBleSDK.h"
#import "KJCentralManger.h"
#import "KJRequestManager.h"
#import "NSString+KJExtention.h"

#define KJVersionUrl @"http://task.jiankangzhan.com/app/upgrade/getAppVer"
#define KJApiVersion @"1.0"

@interface KJBleSDK () <KJCentralMangerDelegate, KJCentralMangerOTADelegate>

@property (nonatomic, strong) NSMutableData *versionData; // 版本数据

@property (nonatomic, strong) KJUserInfo *userInfo; // 用户信息
@property (nonatomic, weak) id<KJBleSDKDelegate> delegate;

@property (nonatomic, copy) KJCheckStatusBlock statsBlock;
@property (nonatomic, copy) KJCheckFinishBlock finishBlock;

@property (nonatomic, assign) float progress;
@property (nonatomic, assign) float eleStats;
@property (nonatomic, assign) BOOL  timeOut;
@property (nonatomic, assign) BOOL  checkFinish;

@property (nonatomic, strong) NSMutableArray *egcDataArray; // 心电数据
@property (nonatomic, strong) NSMutableArray *eleDataArray; // 生物电数据

@property (nonatomic, strong) NSData *fileData; // 固件data
@property (nonatomic, copy)   NSString *fileName; // 固件名

@property (nonatomic, copy) KJUpdateStatusBlock updateBlock;
@property (nonatomic, assign) float updateProgress;
@property (nonatomic, assign) float isAllow;
@property (nonatomic, assign) BOOL  finish;


@property (nonatomic, copy) KJQueryUpdateBlock queryBlock;

@end

@implementation KJBleSDK

#pragma mark - 单列初始化
static KJBleSDK *manager = nil;
+ (KJBleSDK *)instance {
    if ( manager == nil ){
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            manager = [[KJBleSDK alloc] init];
        });
    }
    return manager;
}

- (instancetype)init {
    if (self = [super init]) {
        
        [KJCentralManger instance].delegate = self;
        
        self.egcDataArray = [[NSMutableArray alloc] init];
        self.eleDataArray = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)jkbInitBleSDK:(KJUserInfo *)userInfo delegate:(id<KJBleSDKDelegate>)delegate {
    
    self.userInfo = userInfo;
    self.delegate = delegate;
}

- (void)jkbStartCheck:(KJCheckStatusBlock)statsBlock finishBlock:(KJCheckFinishBlock)finishBlock {
    
    self.progress = 0;
    self.timeOut = NO;
    self.checkFinish = NO;
    if (self.egcDataArray.count) [self.egcDataArray removeAllObjects];
    if (self.eleDataArray.count) [self.eleDataArray removeAllObjects];
    
    self.statsBlock = statsBlock;
    self.finishBlock = finishBlock;
    
    // 发送心电测量指令
    [self egcCheck];
}

- (void)jkbCheckVersion:(KJQueryUpdateBlock)queryBlock {
    
    self.queryBlock = queryBlock;
    
    // 查询健康宝版本号
    [self queryDeviceVersion];
}

- (void)jkbOtaUpdate:(NSData *)fileData
         fileName:(NSString *)fileName
      updateBlock:(KJUpdateStatusBlock)updateBlock {
    
    self.updateProgress = 0;
    self.isAllow = NO;
    self.finish = NO;
    
    self.fileData = fileData;
    self.fileName = fileName;
    self.updateBlock = updateBlock;
    
    // 执行升级指令
    [self deviceAllowUpdate];
}

+ (NSString *)getApiVersion {
    
//    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    return KJApiVersion;
}

+ (void)jkbStartScan {
    
    // 先停止，再扫描
    [[KJCentralManger instance] stopScan];
    [[KJCentralManger instance] startScan];
}

+ (void)jkbStopScan {
    
    [[KJCentralManger instance] stopScan];
}

+ (BOOL)isConnected {
    return [KJCentralManger instance].isConnected;
}

+ (BOOL)isBleOpen {
    return [KJCentralManger instance].isBleOpen;
}

+ (KJDeviceInfo *)jkbGetConnectDeviceInfo {
    
    // 未连接返回nil
    if (![self isConnected]) return nil;
    
    return [KJDeviceInfo instance];
}

+ (void)connectPeripheral:(KJPeripheralInfo *)peripheralInfo {
    
    if (!peripheralInfo) return;
    CBPeripheral *peripheral = peripheralInfo.peripheral;
    [[KJCentralManger instance] connectPeripheral:peripheral peripheralInfo:peripheralInfo];
}


// 请求云端版本
- (void)requestNewVersion:(NSString *)version {
    
    // 请求云端固件版本
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"version"] = version;

    [KJRequestManager postWithUrl:KJVersionUrl params:params success:^(NSURLResponse *response, id responseObject) {

        NSDictionary *dict = (NSDictionary *)responseObject;
        if ([dict[@"code"] intValue] == 0) {
            NSDictionary *dataDict = [dict valueForKey:@"data"];
            NSString *jkbVersion = [dataDict valueForKey:@"jkbVersion"];
            NSString *downUrl = [dataDict valueForKey:@"downUrl"];

            if (![jkbVersion isNotEmpty] || ![downUrl isNotEmpty]) {
                NSLog(@"jkbVersion and downUrl is empty");
                return;
            }
            
            // 没有新版本
            if ([jkbVersion isEqualToString:version]) {

                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self.queryBlock) {
                        self.queryBlock(NO, version, downUrl);
                    }
                });
                
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self.queryBlock) {
                        self.queryBlock(YES, version, downUrl);
                    }
                });
            }
        }

    } failure:^(NSURLResponse *response, NSError *error) {

    }];
}

#pragma mark - KJCentralMangerDelegate
- (void)centralManger:(KJCentralManger *)centralManger findPeripherals:(NSArray *)peripherals {
    //    NSLog(@"peripherals = %@", peripherals);
    if (self.delegate && [self.delegate respondsToSelector:@selector(onScanPeripherals:)]) {
        [self.delegate onScanPeripherals:peripherals];
    }
}

- (void)centralManger:(KJCentralManger *)centralManger connectSuccess:(CBPeripheral *)peripheral {
    
    NSLog(@"蓝牙连接成功连接");
    if (self.delegate && [self.delegate respondsToSelector:@selector(onConnectSuccess:)]) {
        [self.delegate onConnectSuccess:peripheral];
    }
}

- (void)centralManger:(KJCentralManger *)centralManger connectFailure:(NSError *)error {
    NSLog(@"错误 ---- %@", error);
    if (self.delegate && [self.delegate respondsToSelector:@selector(onConnectFailure:)]) {
        [self.delegate onConnectFailure:error];
    }
}

- (void)centralManger:(KJCentralManger *)centralManger disconnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"外设断开连接");
    if (self.delegate && [self.delegate respondsToSelector:@selector(onDisconnectPeripheral:)]) {
        [self.delegate onDisconnectPeripheral:peripheral];
    }
}

// 接收数据
- (void)centralManger:(KJCentralManger *)centralManger characteristic:(CBCharacteristic *)characteristic recievedData:(NSData *)data {
    
    NSString *UUID = characteristic.UUID.UUIDString;
    NSString *info = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    if ([UUID isEqualToString:CharacteristicNotifyUUIDString1]) {
        [self handleReciveData:data];
    } else { // 设备信息
        NSLog(@"%@ = %@",UUID,info);
        KJDeviceInfo *deviceInfo = [KJDeviceInfo instance];
        if ([UUID isEqualToString:CharacteristicReadUUIDString1]) {
            Byte *reciveByte = (Byte *)[data bytes];
            deviceInfo.battery = reciveByte[0];
        } else if ([UUID isEqualToString:CharacteristicReadUUIDString2]) {
            deviceInfo.company = info;
        } else if ([UUID isEqualToString:CharacteristicReadUUIDString3]) {
            deviceInfo.boot_version = info;
        } else if ([UUID isEqualToString:CharacteristicReadUUIDString4]) {
            deviceInfo.hardware_version = info;
        } else if ([UUID isEqualToString:CharacteristicReadUUIDString5]) {
            deviceInfo.firmware_version = info;
        } else if ([UUID isEqualToString:CharacteristicReadUUIDString6]) {
            deviceInfo.device_sn = info;
        } else if ([UUID isEqualToString:CharacteristicReadUUIDString7]) {
            deviceInfo.device_type = info;
        }
    }
}

/***********************************蓝牙测量***********************************/
// 处理接收的数据
- (void)handleReciveData:(NSData *)data {
    
    Byte * reciveByte = (Byte *)[data bytes];

    // 健康宝回复是否可以测量心电和生物电
    if (reciveByte[4] == 0x10) {
        
        NSLog(@"心电结束notify:%@",data);
        
        // 测量过程异常（脱离电极）
    } else if (reciveByte[4] == 0x11) {
        
        self.eleStats = reciveByte[5];
        if (self.statsBlock) {
            self.statsBlock(self.progress, self.eleStats, self.timeOut, self.checkFinish);
        }
        
        // 接收到健康宝发送的开始测量心电命令
    } else if (reciveByte[4] == 0x12) {
        
        NSLog(@"notify:%@",data);
        
        Byte byte[] = {0xa0, 0x03, 0x00, 0x00, 0x12, 0x15};
        [[KJCentralManger instance] sendData:byte length:6];
        
        // 心电数据
    } else if (reciveByte[4] == 0x13) {
        
        // 当前包号 （1429完成）
        int currentNum = reciveByte[2] * 256 + reciveByte[3];
        if (currentNum > 1428) return; // 够20000个字节后舍弃
        
        // 设置进度条
        float progress = currentNum / 1428.f * 0.7;
        self.progress = progress;
        if (self.statsBlock) {
            self.statsBlock(self.progress, self.eleStats, self.timeOut, self.checkFinish);
        }
        
        NSData *egcData = [data subdataWithRange:NSMakeRange(5, data.length - 6)];
        NSDictionary *dataDict = [NSDictionary dictionaryWithObject:egcData forKey:[NSNumber numberWithInt:currentNum]];
        [self.egcDataArray addObject:dataDict];
        NSLog(@"notifyData:%@",data);
        
        // 够20000个字节了（发送完成指令）
        if (currentNum == 1428) {
            
            NSLog(@"***************测量心电结束******************");
            
            // 结束心电测量
            [self endEgcCheck];
            
            // 测量生物电
            [self eleCheck];
        }
        
        // 测量生物电
    } else if (reciveByte[4] == 0x14) {
        
        NSLog(@"notify:%@",data);
        
        Byte byte[] = {0xa0, 0x03, 0x00, 0x00, 0x14, 0x17};
        [[KJCentralManger instance] sendData:byte length:6];
        
        // 接收生物电数据
    } else if (reciveByte[4] == 0x15) {
        
        NSLog(@"notify:%@",data);
        
        // 当前包号
        int currentNum = reciveByte[2] * 256 + reciveByte[3];
    
        NSData *eleData = [data subdataWithRange:NSMakeRange(5, data.length - 6)];
        NSDictionary *dataDict = [NSDictionary dictionaryWithObject:eleData forKey:[NSNumber numberWithInt:currentNum]];
        [self.eleDataArray addObject:dataDict];
        
        // 索要数据
        int check = 0x04 + reciveByte[2] + reciveByte[3] + 0x15 + 0x01;
        Byte byte[] = {0xa0, 0x04, reciveByte[2], reciveByte[3], 0x15, 0x01, check};
        [[KJCentralManger instance] sendData:byte length:7];
        
        // 生物电测量完成
    } else if (reciveByte[4] == 0x16) {
        
        NSLog(@"***************测量生物电结束******************");
        
        [self endEleCheck];
        self.checkFinish = YES;
        
        // 回调
        if (self.statsBlock) {
            self.statsBlock(self.progress, self.eleStats, self.timeOut, self.checkFinish);
        }
        
        // 回调数据
        [self checkFinishCallBack];
        
    } else if (reciveByte[4] == 0x17) { // 心电丢包，重新对某个包进行单独请求
        
        
    } else if (reciveByte[4] == 0x18) { // 心电测量超时
        
        [self checkTimeOut]; // 测量超时
        self.timeOut = YES;
        
        if (self.statsBlock) {
            self.statsBlock(self.progress, self.eleStats, self.timeOut, self.checkFinish);
        }
        
    } else if (reciveByte[4] == 0x19) { // 生物电测量百分比
        
//        NSLog(@"进度 = %d",reciveByte[5]);
        // 设置进度条
        float progress = 0.7 + (0.3 * reciveByte[5]) / 100.f;
        self.progress = progress;
        if (self.statsBlock) {
            self.statsBlock(self.progress, self.eleStats, self.timeOut, self.checkFinish);
        }
        
    } else if (reciveByte[4] == 0x1a) { // 手机询问健康宝生物电电压值
        NSLog(@"生物电电压 = %d",reciveByte[5]);
        
    // 查询健康宝版本号
    } else if (reciveByte[4] == 0x20) {
        NSLog(@"notify:%@",data);
        
        NSData *recData = [data subdataWithRange:NSMakeRange(5, data.length - 6)];
        [self.versionData appendData:recData];
        
        if (reciveByte[3] != 0x01) {
            int check = 0x03 + reciveByte[2] + reciveByte[3] + 0x20;
            Byte byte[] = {0xa0, 0x03, reciveByte[2], reciveByte[3], 0x20, check};
            [[KJCentralManger instance] sendData:byte length:6];
            
        } else {
            
            // 发送结束命令
            Byte byte[] = {0xa0, 0x03, 0x01, 0x01, 0x20, 0x25};
            [[KJCentralManger instance] sendData:byte length:6];
            
            NSLog(@"version = %@",[[NSString alloc] initWithData:self.versionData encoding:NSUTF8StringEncoding]);
            NSString *version = [[NSString alloc] initWithData:self.versionData encoding:NSUTF8StringEncoding];
            
            self.versionData = nil;
          
            // 请求服务端版本号
            [self requestNewVersion:version];
        }
        
    // 健康宝是否允许升级
    } else if (reciveByte[4] == 0x21) {
        
        BOOL isAllow = reciveByte[5];
        self.isAllow = isAllow;
        if (self.updateBlock) {
            self.updateBlock(self.progress, self.isAllow, self.finish);
        }
        
        // 健康宝询问新版本号
    } else if (reciveByte[4] == 0x22) {
        NSLog(@"notify:%@",data);
        
        NSData *newData = [_fileName dataUsingEncoding:NSUTF8StringEncoding];
        Byte *newByte = (Byte *)[newData bytes];
        
        if (reciveByte[2] == 0x00 && reciveByte[3] == 0x00) {
            
            int check = 0x11 + 0x01 + 0x22 + newByte[0] + newByte[1] + newByte[2] + newByte[3] + newByte[4] + newByte[5] + newByte[6] + newByte[7] + newByte[8] + newByte[9] + newByte[10] + newByte[11] + newByte[12] + newByte[13];
            
            Byte byte[] = {0xa0, 0x11, 0x01, 0x00, 0x22, newByte[0], newByte[1], newByte[2], newByte[3], newByte[4], newByte[5], newByte[6], newByte[7], newByte[8], newByte[9], newByte[10], newByte[11], newByte[12], newByte[13], check & 0xff};
            
            [[KJCentralManger instance] sendData:byte length:20];
        } else if (reciveByte[2] == 0x01 && reciveByte[3] == 0x00) {
            
            // 从高位到地位
            Byte one = (_fileData.length >> 24) & 0xff;
            Byte two = (_fileData.length >> 16)  & 0xff;
            Byte three = (_fileData.length >> 8) & 0xff;
            Byte four = _fileData.length & 0xff;
            
            int check = 0x0a + 0x01 + 0x01 + 0x22 + one + two + three + four + newByte[14] + newByte[15] + newByte[16];
            Byte byte[] = {0xa0, 0x0a, 0x01, 0x01, 0x22, newByte[14], newByte[15], newByte[16], one, two, three, four, check};
            
            [[KJCentralManger instance] sendData:byte length:13];
        }
        
        // 健康宝请求升级数据
    } else if (reciveByte[4] == 0x23) {
        NSLog(@"notify:%@",data);
        // 发送（a0 长度 00 00 23 数据 校验，其中00 00 是包号）
        
        int index = (((reciveByte[2] & 0xff) << 8) | (reciveByte[3] & 0xff));
        NSData *upData = [NSData data];
        
        // 最后一个组
        if (index * 14 + 14 > _fileData.length) {
            upData = [_fileData subdataWithRange:NSMakeRange(index * 14, _fileData.length - index * 14)] ;
        } else {
            upData = [_fileData subdataWithRange:NSMakeRange(index * 14, 14)];
        }
        
        // 计算校验、并拼接
        Byte *upByte = (Byte *)[upData bytes];
        int check = 0;
        for (int i = 0; i < upData.length; i++) {
            Byte b = upByte[i];
            int value = b & 0xff;
            check += value;
        }
        
        // 拼接data
        int length = (int)upData.length + 3;
        Byte byte[] = {0xa0, length, reciveByte[2], reciveByte[3], 0x23};
        NSMutableData *sendData = [NSMutableData dataWithBytes:byte length:5];
        [sendData appendData:upData];
        
        check = check + length + reciveByte[2] + reciveByte[3] + 0x23; // 校验和
        Byte lastByte[] = {check};
        NSData *lastData = [NSData dataWithBytes:lastByte length:1];
        [sendData appendData:lastData];
        
        float progress = index * 1.0 / (_fileData.length / 14);
        NSLog(@"%d  %zd  %.2f",index,_fileData.length / 14,progress);
//        self.updateView.progress = progress;
        self.updateProgress = progress;
        if (self.updateBlock) {
            self.updateBlock(self.updateProgress, self.isAllow, self.finish);
        }
        
        // 写数据
        [[KJCentralManger instance] otaSendData:sendData];
        
        // 升级成功
    } else if (reciveByte[4] == 0x24) {
        
        NSLog(@"notify:%@",data);
        
        Byte byte[] = {0xa0, 0x03, 0x00, 0x00, 0x24, 0x27};
        [[KJCentralManger instance] sendData:byte length:6];
        
        NSLog(@"固件升级完成");
        self.finish = YES;
        if (self.updateBlock) {
            self.updateBlock(self.progress, self.isAllow, self.finish);
        }
    }
}

/*********************************蓝牙数据处理**********************************/

// 回调
- (void)checkFinishCallBack {
    NSMutableArray *egcArray = [self getEgcData];
    NSMutableArray *eleArray = [self getEleData];
    
    if (self.finishBlock) {
        self.finishBlock(egcArray, eleArray);
    }
}

// 心电数据一维数组
- (NSMutableArray *)getEgcData {
    
    NSMutableArray *dataArray = [NSMutableArray array];
    for (int i = 0; i < self.egcDataArray.count; i++) { // 1428组
        NSDictionary *dict = self.egcDataArray[i];
        [dict enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, NSData *data, BOOL * _Nonnull stop) {
            int index = [key intValue];
            //            NSLog(@"index = %d",index);
            Byte *byte = (Byte *)[data bytes]; // 14字节
            for (int j = 0; j < 14; j++) {
                int16_t value = (int16_t)(byte[j] & 0xFF);
                int currentIndex = index * 14 + j;
                if (currentIndex < 20000) {
                    
                    dataArray[index * 14 + j] = @(value);
                }
            }
        }];
    }
    return dataArray;
}

// 获取生物电二维数组
- (NSMutableArray *)getEleData {
    
    NSMutableArray *dataArray = [NSMutableArray array];
    for (int i = 0; i < self.eleDataArray.count; i++) {
        NSDictionary *dict = self.eleDataArray[i];
        [dict enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, NSData *data, BOOL *stop) {
            
            int index = [key intValue];
            Byte *byte = (Byte *)[data bytes];
            
            for (int j = 0; j < 7; j++) {
                
                int16_t value = (int16_t) (((byte[j * 2] & 0xFF)<<8)
                                           | (byte[j * 2 + 1] & 0xFF));
                dataArray[index * 7 + j] = @(value);
            }
        }];
    }
    
    // 年龄 身高 体重  性别
    dataArray[80] = @(self.userInfo.age);
    dataArray[81] = @(self.userInfo.height);
    dataArray[82] = @(self.userInfo.weight);
    dataArray[83] = @(self.userInfo.sex);
    
    // 转化二维数组
    NSMutableArray *checkArray = [NSMutableArray array];
    for (int i = 0; i < dataArray.count; i++) {
        
        if (i % 2 == 0) {
            int num0 = [dataArray[i] intValue];
            int num1 = [dataArray[i + 1] intValue];
            
            NSMutableArray *array = [NSMutableArray array];
            [array addObject:@(num0)];
            [array addObject:@(num1)];
            
            [checkArray addObject:array];
        }
    }
    return checkArray;
}

/***********************************蓝牙指令***********************************/
// 心电检测
- (void)egcCheck {
    
    Byte byte[] = {0xa0, 0x05, 0x00, 0x00, 0x10, 0x01, 0x01, 0x17};
    [[KJCentralManger instance] sendData:byte length:8];
}

// 心电结束
- (void)endEgcCheck {
    
    Byte byte[] = {0xa0, 0x05, 0x00, 0x00, 0x10, 0x00, 0x01, 0x16};
    [[KJCentralManger instance] sendData:byte length:8];
}

// 生物电检测
- (void)eleCheck {
    
    Byte byte[] = {0xa0, 0x05, 0x00, 0x00, 0x10, 0x01, 0x02, 0x18};
    [[KJCentralManger instance] sendData:byte length:8];
}

// 结束生物电检测
- (void)endEleCheck {
    Byte byte[] = {0xa0, 0x03, 0x00, 0x00, 0x16, 0x19};
    [[KJCentralManger instance] sendData:byte length:6];
}

// 查询健康宝版本信息
- (void)queryDeviceVersion {
    
    Byte byte[] = {0xa0, 0x03, 0x00, 0x00, 0x20, 0x23};
    [[KJCentralManger instance] sendData:byte length:6];
}

// 健康宝升级(去升级)
- (void)deviceAllowUpdate {
    
    Byte byte[] = {0xa0, 0x03, 0x00, 0x00, 0x21, 0x24};
    [[KJCentralManger instance] sendData:byte length:6];
}


////////////////////////////////////////////////////////////////////////
// 补传心电数据
- (void)requestPacketData:(int)pakageNum {
    // 从高位到地位
    Byte height = (pakageNum >> 8) & 0xff;
    Byte low = pakageNum & 0xff;
    int check = 0x05 + height + low + 0x17;
    Byte byte[] = {0xa0, 0x05, 0x00, 0x00, 0x17, height, low, check};
    [[KJCentralManger instance] sendData:byte length:8];
}

// 测量超时
- (void)checkTimeOut {
    Byte byte[] = {0xa0, 0x03, 0x00, 0x00, 0x18, 0x1b};
    [[KJCentralManger instance] sendData:byte length:6];
}

// 获取生物电检测电压
- (void)CheckVoltage {
    Byte byte[] = {0xa0, 0x03, 0x00, 0x00, 0x1a, 0x1d};
    [[KJCentralManger instance] sendData:byte length:6];
}

- (NSMutableData *)versionData {
    if (!_versionData) {
        _versionData = [NSMutableData data];
    }
    return _versionData;
}

@end
