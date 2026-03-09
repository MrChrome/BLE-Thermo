#import "ObjCBLEDelegate.h"

static CBUUID *kServiceUUID       = nil;
static CBUUID *kWriteCharUUID     = nil;

@implementation ObjCBLEDelegate {
    CBCentralManager *_central;
    dispatch_queue_t _bleQueue;
}

+ (void)initialize {
    if (self == [ObjCBLEDelegate class]) {
        kServiceUUID   = [CBUUID UUIDWithString:@"FFF0"];
        kWriteCharUUID = [CBUUID UUIDWithString:@"FFF3"];
    }
}

- (void)startWithQueue:(dispatch_queue_t)queue {
    _bleQueue = dispatch_queue_create("com.blesensors.ble", DISPATCH_QUEUE_SERIAL);
    _central = [[CBCentralManager alloc] initWithDelegate:self queue:_bleQueue];
}

- (void)beginConnection:(CBPeripheral *)peripheral {
    peripheral.delegate = self;
    [_central connectPeripheral:peripheral options:nil];
}

- (void)endConnection:(CBPeripheral *)peripheral {
    [_central cancelPeripheralConnection:peripheral];
}

// MARK: - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state != CBManagerStatePoweredOn) {
        return;
    }
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
    [peripheral discoverServices:@[kServiceUUID]];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if (self.onDisconnect) {
        self.onDisconnect(peripheral);
    }
}

// MARK: - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    for (CBService *service in peripheral.services) {
        if ([service.UUID isEqual:kServiceUUID]) {
            [peripheral discoverCharacteristics:@[kWriteCharUUID] forService:service];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    for (CBCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.UUID isEqual:kWriteCharUUID]) {
            if (self.onConnect) {
                self.onConnect(peripheral, characteristic);
            }
        }
    }
}

@end
