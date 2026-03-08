#import "ObjCBLEDelegate.h"

@implementation ObjCBLEDelegate {
    CBCentralManager *_central;
    dispatch_queue_t _bleQueue;
}

- (void)startWithQueue:(dispatch_queue_t)queue {
    _bleQueue = dispatch_queue_create("com.blesensors.ble", DISPATCH_QUEUE_SERIAL);
    _central = [[CBCentralManager alloc] initWithDelegate:self queue:_bleQueue];
}

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
    if (mfrData && self.onDiscover) {
        self.onDiscover(peripheral, mfrData, RSSI);
    }
}

@end
