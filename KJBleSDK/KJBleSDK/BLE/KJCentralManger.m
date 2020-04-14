//
//  ViewController.m
//  健康宝
//
//  Created by apple on 2018/1/22.
//  Copyright © 2018年 HEJJY. All rights reserved.
//

#import "KJCentralManger.h"
#import "NSString+KJExtention.h"

#define KJ_ERROR_CODE(description, errorCode) [NSError errorWithDomain:@"com.kangjia" code:errorCode userInfo:@{NSLocalizedDescriptionKey:description}]

@interface KJCentralManger () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (strong, nonatomic) CBCentralManager *centralManager;

// 找到的所有的 Peripheral
@property (strong, nonatomic) NSMutableArray *discoveredPerInfos;

// 当前已经连接的 Peripheral
@property (strong, nonatomic) CBPeripheral *connectedPeripheral;

///< 上一次连接上的 Peripheral，用来做自动连接时，保存强引用
@property (strong, nonatomic) CBPeripheral *lastConnectedPeripheral;

///< 连接的所有 characteristic，主要用于断开连接时，取消 notify 监听
@property (strong, nonatomic) NSMutableArray *readCharacteristics;

// 当前连接设备信息
@property (nonatomic, strong) KJPeripheralInfo *peripheralInfo;

@property (strong, nonatomic) NSTimer *timeoutTimer;

///< 将允许搜索的 service UUID 打包为数组 CBUUID 类型
@property (copy, nonatomic) NSArray *serviceUUIDArray;

///< 将允许搜索的 characteristic UUID 打包为数组 CBUUID 类型
@property (copy, nonatomic) NSArray *characteristicUUIDArray;

///< 记录当前的数据写入方式，用于判断写入成功应该走哪个代理的回调
@property (assign, nonatomic) BOOL isOTA;

//@property (assign, nonatomic) NSInteger otaSubDataOffset; ///< 已经写入的数据长度
//@property (copy, nonatomic) NSData *otaData; ///< 记录 ota 传输的 data，因为 ota 文件比较大，需要切割然后不停的传

@end

@implementation KJCentralManger

static NSString * const LastPeriphrealIdentifierConnectedKey = @"LastPeriphrealIdentifierConnectedKey"; // 蓝牙UUID

static const NSTimeInterval KJCentralMangerTimeOut = 60; ///< 超时时长，如果 <= 0 则不做超时处理
static const BOOL KJCentralMangerAutoConnect = YES;     /// 自动连接
//static const NSInteger KJCentralMangerOTADataSubLength = 20; ///< OTA 每次发送字节的长度

#pragma mark - Left Cycle

static KJCentralManger *manager = nil;

#pragma mark - 单列初始化
+ (KJCentralManger *)instance {
    if ( manager == nil ){
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            manager = [[KJCentralManger alloc] init];
        });
    }
    return manager;
}

- (instancetype)init {

    if (self = [super init]) {
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        // 如果设置了自动连接
        if (KJCentralMangerAutoConnect) {
            // 这里需要延迟 0.1s 才能走连接成功的代理，具体原因未知
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self autoConnect];
            });
        }
    }
    return self;
}

#pragma mark - Public Methods
- (void)startScan {
//    kCBAdvDataManufacturerData
    if (self.discoveredPerInfos.count) {
        [self.discoveredPerInfos removeAllObjects];
    }
//    CBCentralManagerScanOptionAllowDuplicatesKey
    [self.centralManager scanForPeripheralsWithServices:self.serviceUUIDArray options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@(NO)}];
    [self startTimer:KJTimeOutTypeScan];
    
}

- (void)stopScan {
    [self.centralManager stopScan];
}

- (void)connectPeripheral:(CBPeripheral *)peripheral peripheralInfo:(KJPeripheralInfo *)peripheralInfo {
    self.peripheralInfo = peripheralInfo;
    
    NSLog(@"last = %@",peripheral);
    
    [self.centralManager connectPeripheral:peripheral options:nil];
//    [self stopScan];
    [self startTimer:KJTimeOutTypeConnect];
}

- (void)otaSendData:(NSData *)data {

    if (!self.writeCharacteristic || !self.isConnected) {
        return;
    }
    
    NSLog(@"write:%@",data);

    if (data == nil || data.length == 0) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(centralManger:writeFinishWithError:)]) {

            NSError *error = KJ_ERROR_CODE(KJCentralErrorWriteDataLength, KJCentralErrorCodeWriteDataLength);
            [self.delegate centralManger:self writeFinishWithError:error];
        }
        return;
    }
    self.isOTA = NO;
    [self.connectedPeripheral writeValue:data forCharacteristic:self.writeCharacteristic type:CBCharacteristicWriteWithResponse];
    
    //    self.otaSubDataOffset = 0;
    //    self.otaData = data;
    //    [self sendOTAWriteToCharacteristic:self.writeCharacteristic];
}

- (void)sendData:(Byte *)byte length:(int)length {
    
    if (!self.writeCharacteristic || !self.isConnected) {
        return;
    }
    NSData *data =  [NSData dataWithBytes:byte length:length];
    NSLog(@"write:%@",data);
    
    if (data == nil || data.length == 0) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(centralManger:writeFinishWithError:)]) {

            NSError *error = KJ_ERROR_CODE(KJCentralErrorWriteDataLength, KJCentralErrorCodeWriteDataLength);
            [self.delegate centralManger:self writeFinishWithError:error];
        }
        return;
    }
    self.isOTA = NO;
    [self.connectedPeripheral writeValue:data forCharacteristic:self.writeCharacteristic type:CBCharacteristicWriteWithResponse];
}


- (void)disconnectWithPeripheral:(CBPeripheral *)peripheral {
    for (CBCharacteristic *characteristic in self.readCharacteristics) {
        [self.connectedPeripheral setNotifyValue:NO forCharacteristic:characteristic];
    }
    [self.centralManager cancelPeripheralConnection:self.connectedPeripheral];
    self.connectedPeripheral = nil;
}

#pragma mark - Private Methods

// 自动连接
- (void)autoConnect {
    // 取出上次连接成功后，存的 peripheral identifier
    NSString *lastPeripheralIdentifierConnected = [[NSUserDefaults standardUserDefaults] objectForKey:LastPeriphrealIdentifierConnectedKey];

    // 如果没有，则不做任何操作，说明需要用户点击开始扫描的按钮，进行手动搜索
    if (lastPeripheralIdentifierConnected == nil || lastPeripheralIdentifierConnected.length == 0) {
        return;
    }
    // 查看上次存入的 identifier 还能否找到 peripheral
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:lastPeripheralIdentifierConnected];
    NSArray *peripherals = [self.centralManager retrievePeripheralsWithIdentifiers:@[uuid]];
    // 如果不能成功找到或连接，可能是设备未开启等原因，返回连接错误
    if (peripherals == nil || [peripherals count] == 0) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(centralManger:connectFailure:)]) {
            NSError *error = KJ_ERROR_CODE(KJCentralErrorConnectAutoConnectFail, KJCentralErrorCodeAutoConnectFail);
            [self.delegate centralManger:self connectFailure:error];
        }
        return;
    }
    // 如果能找到则开始建立连接
    CBPeripheral *peripheral = [peripherals firstObject];
    [self.centralManager connectPeripheral:peripheral options:nil];
    // 注意保留 Peripheral 的引用
    self.lastConnectedPeripheral = peripheral;
    [self startTimer:KJTimeOutTypeConnect];
}

#pragma mark - Timer

- (void)startTimer:(KJTimeOutType)type {
    [self stopTimer];

    NSTimer *timer = [NSTimer timerWithTimeInterval:KJCentralMangerTimeOut target:self selector:@selector(timeOut:) userInfo:@(type) repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    _timeoutTimer = timer;
    
}

- (void)stopTimer {

    [_timeoutTimer invalidate];
    _timeoutTimer = nil;
}

- (void)timeOut:(NSTimer *)timer {

    NSInteger type = [timer.userInfo integerValue];
    if (type == KJTimeOutTypeScan) {
        [self stopScan];
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(centralManger:connectFailure:)]) {
        
        if (type == KJTimeOutTypeScan) {
            NSError *error = KJ_ERROR_CODE(KJCentralErrorScanTimeOut, KJCentralErrorCodeScanTimeOut);
            [self.delegate centralManger:self connectFailure:error];
        } else {
            NSError *error = KJ_ERROR_CODE(KJCentralErrorConnectTimeOut, KJCentralErrorCodeConnectTimeOut);
            [self.delegate centralManger:self connectFailure:error];
        }
    }
}

#pragma mark - CBCentralManagerDelegate

// 最新设备的 central 状态，一般用于检测是否支持 central
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    // CBCentralManagerStatePoweredOn 是唯一正常的状态
    if (central.state == CBCentralManagerStatePoweredOn) {
        NSLog(@"蓝牙已打开");
        self.isBleOpen = YES;
        [self startScan];
        return;
    } else if (central.state == CBCentralManagerStatePoweredOff) {
        self.isBleOpen = NO;
        NSLog(@"蓝牙已关闭");
    }
    // 其他状态都是错的
    if (self.delegate && [self.delegate respondsToSelector:@selector(centralManger:connectFailure:)]) {
        // 如果蓝牙关闭了
        if (central.state == CBCentralManagerStatePoweredOff) {
            NSError *error = KJ_ERROR_CODE(KJCentralErrorBluetoothPowerOff, KJCentralErrorCodeBluetoothPowerOff);
            [self.delegate centralManger:self connectFailure:error];
            return;
        }
        // 还有当前设备不支持、未知错误等，统一为其它错误
        NSError *error = KJ_ERROR_CODE(KJCentralErrorBluetoothOtherState, KJCentralErrorCodeBluetoothOtherState);
        [self.delegate centralManger:self connectFailure:error];
    }
}

// 找到设备时调用，每找到一个就调用一次
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    [self stopTimer];
    
    // 将找到的 peripheral 存入数组
    id data = advertisementData[@"kCBAdvDataManufacturerData"];
    NSString *device_sn = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (device_sn.length >= 2) device_sn = [device_sn substringFromIndex:2];
    NSString *device_name = advertisementData[@"kCBAdvDataLocalName"];
    
//    NSLog(@"sn = %@",device_sn);
//    NSLog(@"advertisementData = %@",advertisementData);
//    NSLog(@"idf = %@",peripheral.identifier.UUIDString);
    
    KJPeripheralInfo *perInfo = [[KJPeripheralInfo alloc] init];
    perInfo.device_name = device_name;
    perInfo.device_sn = device_sn;
    perInfo.peripheral = peripheral;
    
    // 获取发现设备
    if (!self.discoveredPerInfos.count) {
        if ([perInfo.device_sn isNotEmpty]) {
            [self.discoveredPerInfos addObject:perInfo];
        }
    } else {
        for (KJPeripheralInfo *info in self.discoveredPerInfos) {
            
            // 数组没有sn并且sn不空
            if (![info.device_sn isEqualToString:perInfo.device_sn] && [perInfo.device_sn isNotEmpty]) {
                
                [self.discoveredPerInfos addObject:perInfo];
            }
        }
    }
    
    // 找到设备的回调
    if (self.delegate && [self.delegate respondsToSelector:@selector(centralManger:findPeripherals:)]) {
        [self.delegate centralManger:self findPeripherals:[self.discoveredPerInfos copy]];
    }
}

// 成功连接到某个设备
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    [self stopTimer];
    [self stopScan];
    peripheral.delegate = self;
    
    // 情况版本信息
    if (![self.connectedPeripheral isEqual:peripheral]) {
        
//        [[KJAppData instance] clearVersion];3
    }
    
    self.connectedPeripheral = peripheral; // 存储设备信息
    self.connectDeviceName = self.peripheralInfo.device_name; // 存储设备名
    self.connectDeviceSN = self.peripheralInfo.device_sn; // 存储SN
    
    [peripheral discoverServices:self.serviceUUIDArray];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(centralManger:connectSuccess:)]) {
        [self.delegate centralManger:self connectSuccess:peripheral];
    }
}

// 连接失败（但不包含超时，系统没有超时处理）
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if (error && self.delegate && [self.delegate respondsToSelector:@selector(centralManger:connectFailure:)]) {
        [self.delegate centralManger:self connectFailure:error];
    }
}

// 外设断开蓝牙连接
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    
    NSLog(@"now = %@",peripheral);
    NSLog(@"error:%@",error);
    
//    for (CBCharacteristic *characteristic in self.readCharacteristics) {
//        [self.connectedPeripheral setNotifyValue:NO forCharacteristic:characteristic];
//    }
//    self.connectedPeripheral = nil;
    // 重新连接
//    [self.centralManager connectPeripheral:peripheral options:nil];
    
    self.connectedPeripheral = nil;
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(centralManger:disconnectPeripheral:)]) {
        [self.delegate centralManger:self disconnectPeripheral:peripheral];
    }
  
}

#pragma mark - CBPeripheralDelegate

// 搜索到 Service （或失败）
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(centralManger:connectFailure:)]) {
            [self.delegate centralManger:self connectFailure:error];
        }
        return;
    }
    for (CBService *service in peripheral.services) {
        
//        NSLog(@"service = %@", service.UUID.UUIDString);
        
        // 对比是否是需要的 service
        if (![self.serviceUUIDArray containsObject:service.UUID]) {
            continue;
        }
        // 如果找到了，就继续找 characteristic
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

// 搜索到 Characteristic （或失败）
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(centralManger:connectFailure:)]) {
            [self.delegate centralManger:self connectFailure:error];
        }
        return;
    }
    for (CBCharacteristic *characteristic in service.characteristics) {
    
        // 对比是否是需要的 characteristic
        if (![self.characteristicUUIDArray containsObject:characteristic.UUID]) {
            continue;
        }
        
        // 找到可读的 characteristic，就自动读取数据
        if (characteristic.properties & CBCharacteristicPropertyRead) {
            [peripheral readValueForCharacteristic:characteristic];
        }
        if (characteristic.properties & CBCharacteristicPropertyNotify) {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            [self.readCharacteristics addObject:characteristic];
        }
        if (characteristic.properties & CBCharacteristicPropertyWriteWithoutResponse) {

            if ([characteristic.UUID.UUIDString isEqual:CharacteristicWriteUUIDString1]) {
            
                _writeCharacteristic = characteristic;
            }
        }
    }
}

// 读到 Characteristic 的数据的回调
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(centralManger:connectFailure:)]) {
            [self.delegate centralManger:self connectFailure:error];
        }
        return;
    }
    
    NSData *value = characteristic.value;
    if (!self.isOTA) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(centralManger:characteristic:recievedData:)]) {
            [self.delegate centralManger:self characteristic:characteristic recievedData:value];
        }
    } else {
        if (self.delegate && [self.delegate respondsToSelector:@selector(centralManger:characteristic:otaRecievedData:)]) {
            [self.delegate centralManger:self characteristic:characteristic otaRecievedData:value];
        }
    }
}

// 设置数据订阅成功（或失败）
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(centralManger:connectFailure:)]) {
            [self.delegate centralManger:self connectFailure:error];
        }
        return;
    }
    
//    // 读特性
//    if (characteristic.properties & CBCharacteristicPropertyNotify) {
//        //如果具备通知，即可以读取特性的value
//        [peripheral readValueForCharacteristic:characteristic];
//    }
}

// 接收到数据写入结果的回调 （写入数据调用）
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {

    // 如果是 OTA，则判断错误，无错就继续截取发送

//        [self otaDataWriteValueWithError:error characteristic:characteristic];
    if (self.isOTA &&self.delegate&& [self.delegate respondsToSelector:@selector(centralManger:otaWriteFinishWithError:)]) {
        [self.delegate centralManger:self otaWriteFinishWithError:error];
        return;
    }
    
    // 如果不是 OTA，并且设置了代理
    if (!self.isOTA && self.delegate && [self.delegate respondsToSelector:@selector(centralManger:writeFinishWithError:)]) {
        [self.delegate centralManger:self writeFinishWithError:error];
        return;
    }
}


#pragma mark - Getter / Setter

- (NSMutableArray *)discoveredPerInfos {
    if (!_discoveredPerInfos) {
        _discoveredPerInfos = [NSMutableArray new];
    }
    return _discoveredPerInfos;
}

- (NSMutableArray *)readCharacteristics {
    if (!_readCharacteristics) {
        _readCharacteristics = [NSMutableArray new];
    }
    return _readCharacteristics;
}

- (NSArray *)serviceUUIDArray {
    if (!_serviceUUIDArray) {
        CBUUID *serviceUUID1 = [CBUUID UUIDWithString:ServiceUUIDString1];
        CBUUID *serviceUUID2 = [CBUUID UUIDWithString:ServiceUUIDString2];
        CBUUID *serviceUUID3 = [CBUUID UUIDWithString:ServiceUUIDString3];
        _serviceUUIDArray = @[serviceUUID1, serviceUUID2, serviceUUID3];
    }
    return _serviceUUIDArray;
}

- (NSArray *)characteristicUUIDArray {
    if (!_characteristicUUIDArray) {
        CBUUID *characteristicUUID1 = [CBUUID UUIDWithString:CharacteristicReadUUIDString1];
        CBUUID *characteristicUUID2 = [CBUUID UUIDWithString:CharacteristicReadUUIDString2];
        CBUUID *characteristicUUID3 = [CBUUID UUIDWithString:CharacteristicReadUUIDString3];
        CBUUID *characteristicUUID4 = [CBUUID UUIDWithString:CharacteristicReadUUIDString4];
        CBUUID *characteristicUUID5 = [CBUUID UUIDWithString:CharacteristicReadUUIDString5];
        CBUUID *characteristicUUID6 = [CBUUID UUIDWithString:CharacteristicReadUUIDString6];
        CBUUID *characteristicUUID7 = [CBUUID UUIDWithString:CharacteristicReadUUIDString7];
        
        CBUUID *characteristicUUID8 = [CBUUID UUIDWithString:CharacteristicWriteUUIDString1];
        CBUUID *characteristicUUID9 = [CBUUID UUIDWithString:CharacteristicNotifyUUIDString1];
        
        _characteristicUUIDArray = @[characteristicUUID1, characteristicUUID2, characteristicUUID3, characteristicUUID4, characteristicUUID5, characteristicUUID6, characteristicUUID7, characteristicUUID8, characteristicUUID9];
    }
    return _characteristicUUIDArray;
}

- (void)setConnectedPeripheral:(CBPeripheral *)connectedPeripheral {
    _connectedPeripheral = connectedPeripheral;
    // 如果当前的 peripheral 不为空 并且 设置了自动连接，则记录 identifier，为自动连接做准备
    if (connectedPeripheral != nil && KJCentralMangerAutoConnect) {
        [[NSUserDefaults standardUserDefaults] setObject:connectedPeripheral.identifier.UUIDString forKey:LastPeriphrealIdentifierConnectedKey];
    }
}

- (void)setConnectDeviceSN:(NSString *)connectDeviceSN {
    _connectDeviceSN = connectDeviceSN;
    if ([connectDeviceSN isNotEmpty] && KJCentralMangerAutoConnect) {
        [[NSUserDefaults standardUserDefaults] setObject:connectDeviceSN forKey:LastDeviceSNIdentifierConnectedKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)setConnectDeviceName:(NSString *)connectDeviceName {
    _connectDeviceName = connectDeviceName;
    if ([connectDeviceName isNotEmpty] && KJCentralMangerAutoConnect) {
        [[NSUserDefaults standardUserDefaults] setObject:connectDeviceName forKey:LastDeviceNameIdentifierConnectedKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}


- (BOOL)isConnected {
    if (self.connectedPeripheral == nil) {
        return NO;
    }
    return self.connectedPeripheral.state == CBPeripheralStateConnected;
}

//特征值的属性 枚举如下
/*
 typedef NS_OPTIONS(NSUInteger, CBCharacteristicProperties) {
 CBCharacteristicPropertyBroadcast,//允许广播特征
 CBCharacteristicPropertyRead,//可读属性
 CBCharacteristicPropertyWriteWithoutResponse,//可写并且接收回执
 CBCharacteristicPropertyWrite,//可写属性
 CBCharacteristicPropertyNotify,//可通知属性
 CBCharacteristicPropertyIndicate,//可展现的特征值
 CBCharacteristicPropertyAuthenticatedSignedWrites,//允许签名的特征值写入
 CBCharacteristicPropertyExtendedProperties,
 CBCharacteristicPropertyNotifyEncryptionRequired,
 CBCharacteristicPropertyIndicateEncryptionRequired
 };


#pragma mark - Send Data Loop
// 处理 ota 的写入回调，错误则直接回调返回，正确则继续截取数据并发送
- (void)otaDataWriteValueWithError:(NSError *)error characteristic:(CBCharacteristic *)characteristic {
    if (error) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(centralManger:otaWriteFinishWithError:)]) {
            [self.delegate centralManger:self otaWriteFinishWithError:error];
        }
        return;
    }
    // 将已发送的数据长度回调回去
    if (self.delegate && [self.delegate respondsToSelector:@selector(centralManger:otaWriteLength:)]) {
        [self.delegate centralManger:self otaWriteLength:self.otaSubDataOffset];
    }
    [self sendOTAWriteToCharacteristic:characteristic];
}

// 将截取的数据发送出去
- (void)sendOTAWriteToCharacteristic:(CBCharacteristic *)characteristic {
    NSData *data = [self subOTAData];
    self.otaSubDataOffset += data.length;
    if (data == nil || data.length == 0) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(centralManger:otaWriteFinishWithError:)]) {
            [self.delegate centralManger:self otaWriteFinishWithError:nil];
        }
        return;
    }
    [self.connectedPeripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
}
 
 // 截取数据，因为蓝牙传输的数据单次有大小限制
 - (NSData *)subOTAData {
 NSInteger totalLength = self.otaData.length;
 NSInteger remainLength = totalLength - self.otaSubDataOffset;
 NSInteger rangLength = remainLength > KJCentralMangerOTADataSubLength ? KJCentralMangerOTADataSubLength : remainLength;
 return [self.otaData subdataWithRange:NSMakeRange(self.otaSubDataOffset, rangLength)];
 }
 
*/

@end
