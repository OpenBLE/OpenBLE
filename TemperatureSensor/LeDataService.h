/*
 
 File: LeDataService.h
 
 Abstract: Data Service Header - Connect to a peripheral
 and send and receive data.
 
 
 */



#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>


/****************************************************************************/
/*						Service Characteristics								*/
/****************************************************************************/
extern NSString *kTemperatureServiceUUIDString;                 // FFF0     Service UUID
extern NSString *kWriteCharacteristicUUIDString;                // FFF2     Write Characteristic
extern NSString *kReadCharacteristicUUIDString;                 // FFF1     Read Characteristic

extern NSString *kDataServiceEnteredBackgroundNotification;
extern NSString *kDataServiceEnteredForegroundNotification;

/****************************************************************************/
/*								Protocol									*/
/****************************************************************************/
@class LeDataService;

@protocol LeDataProtocol<NSObject>
- (void) serviceDidReceiveData:(NSData*)data fromService:(LeDataService*)service;
- (void) serviceDidChangeStatus:(LeDataService*)service;
- (void) serviceDidReset;
@end


/****************************************************************************/
/*						Data service.                                       */
/****************************************************************************/
@interface LeDataService : NSObject

- (id) initWithPeripheral:(CBPeripheral *)peripheral controller:(id<LeDataProtocol>)controller;
- (void) setController:(id<LeDataProtocol>)controller;

- (void) reset;
- (void) start;

- (void) write:(NSData *)data;

/* Behave properly when heading into and out of the background */
- (void)enteredBackground;
- (void)enteredForeground;

@property (readonly) CBPeripheral *peripheral;
@end
