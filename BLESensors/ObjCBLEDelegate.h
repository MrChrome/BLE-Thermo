@import Foundation;
@import CoreBluetooth;

typedef void (^BLEDiscoverBlock)(CBPeripheral *peripheral, NSData *mfrData, NSNumber *rssi, NSString *localName);
typedef void (^BLEConnectBlock)(CBPeripheral *peripheral, CBCharacteristic *writeCharacteristic);
typedef void (^BLEDisconnectBlock)(CBPeripheral *peripheral);

@interface ObjCBLEDelegate : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>
@property (nonatomic, copy, nullable) BLEDiscoverBlock onDiscover;
@property (nonatomic, copy, nullable) BLEConnectBlock onConnect;
@property (nonatomic, copy, nullable) BLEDisconnectBlock onDisconnect;
- (void)startWithQueue:(nullable dispatch_queue_t)queue;
- (void)beginConnection:(CBPeripheral *)peripheral;
- (void)endConnection:(CBPeripheral *)peripheral;
@end
