@import Foundation;
@import CoreBluetooth;

typedef void (^BLEDiscoverBlock)(CBPeripheral *peripheral, NSData *mfrData, NSNumber *rssi);

@interface ObjCBLEDelegate : NSObject <CBCentralManagerDelegate>
@property (nonatomic, copy, nullable) BLEDiscoverBlock onDiscover;
- (void)startWithQueue:(nullable dispatch_queue_t)queue;
@end
