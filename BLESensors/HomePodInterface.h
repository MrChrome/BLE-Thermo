// Minimal HomeKit declarations for HomePodReader.
// We declare only what we need here to avoid importing the full HomeKit
// umbrella header (which drags in UIKit and conflicts with AppKit).
// We link against the real HomeKit framework via OTHER_LDFLAGS at build time.

#ifndef HomePodInterface_h
#define HomePodInterface_h

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, HMHomeManagerAuthorizationStatus) {
    HMHomeManagerAuthorizationStatusDetermined = (1 << 0),
    HMHomeManagerAuthorizationStatusRestricted = (1 << 1),
    HMHomeManagerAuthorizationStatusAuthorized = (1 << 2),
};

extern NSString * const HMCharacteristicTypeCurrentTemperature;
extern NSString * const HMCharacteristicTypeCurrentRelativeHumidity;

@class HMHome, HMAccessory, HMService, HMCharacteristic, HMRoom, HMHomeManager;

@protocol HMHomeManagerDelegate <NSObject>
@optional
- (void)homeManagerDidUpdateHomes:(HMHomeManager *)manager;
@end

@interface HMHomeManager : NSObject
@property (weak, nonatomic, nullable) id<HMHomeManagerDelegate> delegate;
@property (nonatomic, readonly, copy) NSArray<HMHome *> *homes;
@property (nonatomic, readonly) HMHomeManagerAuthorizationStatus authorizationStatus;
@end

@interface HMHome : NSObject
@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly, copy) NSArray<HMAccessory *> *accessories;
@end

@interface HMRoom : NSObject
@property (nonatomic, readonly, copy) NSString *name;
@end

@interface HMAccessory : NSObject
@property (nonnull, nonatomic, readonly) NSUUID *uniqueIdentifier;
@property (nonatomic, readonly, copy) NSString *name;
@property (nullable, nonatomic, readonly, weak) HMRoom *room;
@property (nonatomic, readonly, copy) NSArray<HMService *> *services;
@end

@interface HMService : NSObject
@property (nonatomic, readonly, copy) NSArray<HMCharacteristic *> *characteristics;
@end

@interface HMCharacteristic : NSObject
@property (nonatomic, readonly, copy) NSString *characteristicType;
@property (nullable, nonatomic, readonly) id value;
- (void)readValueWithCompletionHandler:(void (^)(NSError * _Nullable error))completion;
@end

#endif /* HomePodInterface_h */
