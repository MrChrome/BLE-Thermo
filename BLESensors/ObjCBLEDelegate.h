@import Foundation;
@import CoreBluetooth;

typedef void (^BLEDiscoverBlock)(CBPeripheral *peripheral, NSData *mfrData, NSNumber *rssi, NSString *localName);
typedef void (^BLEConnectBlock)(CBPeripheral *peripheral, CBCharacteristic *writeCharacteristic);
typedef void (^BLEDisconnectBlock)(CBPeripheral *peripheral);

// Callbacks for Govee history download
typedef void (^GoveeReadyBlock)(void);
typedef void (^GoveeDataBlock)(NSData *packet);
typedef void (^GoveeControlBlock)(NSData *packet);
typedef void (^GoveeDisconnectBlock)(NSError *_Nullable error);

@interface ObjCBLEDelegate : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>

// LED strip callbacks
@property (nonatomic, copy, nullable) BLEDiscoverBlock onDiscover;
@property (nonatomic, copy, nullable) BLEConnectBlock onConnect;
@property (nonatomic, copy, nullable) BLEDisconnectBlock onDisconnect;

// Govee history callbacks
@property (nonatomic, copy, nullable) GoveeReadyBlock onGoveeReady;
@property (nonatomic, copy, nullable) GoveeDataBlock onGoveeData;
@property (nonatomic, copy, nullable) GoveeControlBlock onGoveeControl;
@property (nonatomic, copy, nullable) GoveeDisconnectBlock onGoveeDisconnect;

- (void)startWithQueue:(nullable dispatch_queue_t)queue;
- (void)beginConnection:(CBPeripheral *)peripheral;
- (void)endConnection:(CBPeripheral *)peripheral;
- (void)beginGoveeHistory:(CBPeripheral *)peripheral;
- (void)sendGoveeCommand:(NSData *)data;
- (void)endGoveeHistory;
@end
