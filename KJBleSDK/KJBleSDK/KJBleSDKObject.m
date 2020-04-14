//
//  KJBleSDKObject.m
//  KJBleSDK
//
//  Created by apple on 2019/11/26.
//  Copyright © 2019 CoderYS. All rights reserved.
//

#import "KJBleSDKObject.h"

@implementation KJUserInfo

@end

@implementation KJPeripheralInfo


@end


@implementation KJDeviceInfo

static KJDeviceInfo *deviceInfo = nil;

+ (KJDeviceInfo *)instance {
    
    if (deviceInfo == nil) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            deviceInfo = [[KJDeviceInfo alloc] init];
        });
    }
    return deviceInfo;
}

- (instancetype)init {
    if (self = [super init]) {
        
        _device_sn = [[NSUserDefaults standardUserDefaults]
                      objectForKey:LastDeviceSNIdentifierConnectedKey];
        _device_name = [[NSUserDefaults standardUserDefaults] objectForKey:LastDeviceNameIdentifierConnectedKey];
    }
    return self;
}

@end
//static NSString * const CharacteristicReadUUIDString1 = @"2A19"; // 电池电量
//static NSString * const CharacteristicReadUUIDString2 = @"2A29"; // 制造商字符串
//static NSString * const CharacteristicReadUUIDString3 = @"2A28"; // boot版本
//static NSString * const CharacteristicReadUUIDString4 = @"2A27"; // 硬件版本
//static NSString * const CharacteristicReadUUIDString5 = @"2A26"; // 固件版本
//static NSString * const CharacteristicReadUUIDString6 = @"2A25"; // SN号
//static NSString * const CharacteristicReadUUIDString7 = @"2A24"; // 型号

//2018-12-20 13:47:37.385577+0800 JianKangBao[4203:487076] 2A19 = )
//2018-12-20 13:47:37.505511+0800 JianKangBao[4203:487076] 2A29 = kangjiakeji
//2018-12-20 13:47:37.625609+0800 JianKangBao[4203:487076] 2A25 = KJ301JS00001000
//2018-12-20 13:47:37.685392+0800 JianKangBao[4203:487076] 2A27 = H1.2
//2018-12-20 13:47:37.745734+0800 JianKangBao[4203:487076] 2A26 = 201812191
//2018-12-20 13:47:37.805584+0800 JianKangBao[4203:487076] 2A28 = B1.2
