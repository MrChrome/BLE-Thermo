#import "ObjCBLEDelegate.h"

// LED strip service/characteristic
static CBUUID *kLEDServiceUUID   = nil;
static CBUUID *kLEDWriteCharUUID = nil;

// Govee INTELLI_ROCKS_HW service/characteristics
static CBUUID *kGoveeServiceUUID = nil;
static CBUUID *kGoveeChar2011    = nil;
static CBUUID *kGoveeChar2012    = nil;
static CBUUID *kGoveeChar2013    = nil;

@implementation ObjCBLEDelegate {
    CBCentralManager  *_central;
    dispatch_queue_t   _bleQueue;
    CBPeripheral      *_goveePeripheral;
    CBCharacteristic  *_goveeWriteChar;       // 2012 - history command target
    CBCharacteristic  *_goveeDeviceChar;      // 2011 - device info char
    CBCharacteristic  *_goveeDataChar;        // 2013 - data stream
    NSUInteger         _goveeSubscribedCount;
    BOOL               _goveeHandshakeSent;
}

+ (void)initialize {
    if (self == [ObjCBLEDelegate class]) {
        kLEDServiceUUID   = [CBUUID UUIDWithString:@"FFF0"];
        kLEDWriteCharUUID = [CBUUID UUIDWithString:@"FFF3"];
        kGoveeServiceUUID = [CBUUID UUIDWithString:@"494e5445-4c4c-495f-524f-434b535f4857"];
        kGoveeChar2011    = [CBUUID UUIDWithString:@"494e5445-4c4c-495f-524f-434b535f2011"];
        kGoveeChar2012    = [CBUUID UUIDWithString:@"494e5445-4c4c-495f-524f-434b535f2012"];
        kGoveeChar2013    = [CBUUID UUIDWithString:@"494e5445-4c4c-495f-524f-434b535f2013"];
    }
}

- (void)startWithQueue:(dispatch_queue_t)queue {
    _bleQueue = dispatch_queue_create("com.blesensors.ble", DISPATCH_QUEUE_SERIAL);
    _central = [[CBCentralManager alloc] initWithDelegate:self queue:_bleQueue];
}

// MARK: - LED strip

- (void)beginConnection:(CBPeripheral *)peripheral {
    peripheral.delegate = self;
    [_central connectPeripheral:peripheral options:nil];
}

- (void)endConnection:(CBPeripheral *)peripheral {
    [_central cancelPeripheralConnection:peripheral];
}

// MARK: - Govee history

- (void)beginGoveeHistory:(CBPeripheral *)peripheral {
    _goveePeripheral = peripheral;
    _goveeSubscribedCount = 0;
    _goveeHandshakeSent = NO;
    _goveeWriteChar = nil;
    _goveeDeviceChar = nil;
    _goveeDataChar = nil;
    peripheral.delegate = self;
    [_central connectPeripheral:peripheral options:nil];
}

- (void)sendGoveeCommand:(NSData *)data {
    if (_goveePeripheral && _goveeWriteChar) {
        CBCharacteristicWriteType writeType = (_goveeWriteChar.properties & CBCharacteristicPropertyWrite)
            ? CBCharacteristicWriteWithResponse
            : CBCharacteristicWriteWithoutResponse;
        [_goveePeripheral writeValue:data forCharacteristic:_goveeWriteChar type:writeType];
    }
}

- (void)endGoveeHistory {
    if (_goveePeripheral) {
        [_central cancelPeripheralConnection:_goveePeripheral];
        _goveePeripheral = nil;
        _goveeWriteChar = nil;
        _goveeDeviceChar = nil;
        _goveeDataChar = nil;
        _goveeHandshakeSent = NO;
    }
}

// MARK: - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state != CBManagerStatePoweredOn) return;
    [central scanForPeripheralsWithServices:nil
                                   options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @YES}];
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary<NSString *,id> *)advertisementData
                  RSSI:(NSNumber *)RSSI {
    NSData *mfrData = advertisementData[CBAdvertisementDataManufacturerDataKey];
    NSString *localName = advertisementData[CBAdvertisementDataLocalNameKey];
    if (self.onDiscover) {
        self.onDiscover(peripheral, mfrData, RSSI, localName);
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    if (peripheral == _goveePeripheral) {
        [peripheral discoverServices:@[kGoveeServiceUUID]];
    } else {
        [peripheral discoverServices:@[kLEDServiceUUID]];
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if (peripheral == _goveePeripheral) {
        _goveePeripheral = nil;
        _goveeWriteChar = nil;
        if (self.onGoveeDisconnect) self.onGoveeDisconnect(error);
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if (peripheral == _goveePeripheral) {
        _goveePeripheral = nil;
        _goveeWriteChar = nil;
        if (self.onGoveeDisconnect) self.onGoveeDisconnect(error);
    } else {
        if (self.onDisconnect) self.onDisconnect(peripheral);
    }
}

// MARK: - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    for (CBService *service in peripheral.services) {
        if ([service.UUID isEqual:kGoveeServiceUUID]) {
            [peripheral discoverCharacteristics:@[kGoveeChar2011, kGoveeChar2012, kGoveeChar2013] forService:service];
        } else if ([service.UUID isEqual:kLEDServiceUUID]) {
            [peripheral discoverCharacteristics:@[kLEDWriteCharUUID] forService:service];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if ([service.UUID isEqual:kGoveeServiceUUID]) {
        for (CBCharacteristic *c in service.characteristics) {
            if ([c.UUID isEqual:kGoveeChar2011]) _goveeDeviceChar = c;
            if ([c.UUID isEqual:kGoveeChar2012]) _goveeWriteChar  = c;
            if ([c.UUID isEqual:kGoveeChar2013]) _goveeDataChar   = c;
            if (c.properties & CBCharacteristicPropertyNotify) {
                [peripheral setNotifyValue:YES forCharacteristic:c];
            }
        }
    } else if ([service.UUID isEqual:kLEDServiceUUID]) {
        for (CBCharacteristic *c in service.characteristics) {
            if ([c.UUID isEqual:kLEDWriteCharUUID]) {
                if (self.onConnect) self.onConnect(peripheral, c);
            }
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error || peripheral != _goveePeripheral) return;
    if (characteristic.isNotifying) {
        _goveeSubscribedCount++;
        // Once 2012 (command) and 2013 (data) are both subscribed, send the AA 01 handshake.
        // Guard with _goveeHandshakeSent to only fire once.
        BOOL cmd2012Ready  = (_goveeWriteChar != nil && _goveeWriteChar.isNotifying);
        BOOL data2013Ready = (_goveeDataChar  != nil && _goveeDataChar.isNotifying);
        if (cmd2012Ready && data2013Ready && !_goveeHandshakeSent) {
            _goveeHandshakeSent = YES;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), _bleQueue, ^{
                if (!self->_goveePeripheral || !self->_goveeWriteChar) return;
                uint8_t bytes[20] = {0xaa, 0x01, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0};
                uint8_t checksum = 0;
                for (int i = 0; i < 19; i++) checksum ^= bytes[i];
                bytes[19] = checksum;
                NSData *handshake = [NSData dataWithBytes:bytes length:20];
                CBCharacteristicWriteType writeType = (self->_goveeWriteChar.properties & CBCharacteristicPropertyWrite)
                    ? CBCharacteristicWriteWithResponse
                    : CBCharacteristicWriteWithoutResponse;
                [self->_goveePeripheral writeValue:handshake forCharacteristic:self->_goveeWriteChar type:writeType];
            });
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error || !characteristic.value || peripheral != _goveePeripheral) return;

    const uint8_t *bytes = characteristic.value.bytes;

    if ([characteristic.UUID isEqual:kGoveeChar2013]) {
        if (self.onGoveeData) self.onGoveeData(characteristic.value);
    } else {
        // Detect AA 01 ACK — device is ready for history command
        if (characteristic.value.length >= 2 && bytes[0] == 0xAA && bytes[1] == 0x01) {
            if (self.onGoveeReady) self.onGoveeReady();
        } else {
            if (self.onGoveeControl) self.onGoveeControl(characteristic.value);
        }
    }
}

@end
