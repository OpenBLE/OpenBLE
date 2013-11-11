/*

 File: LeDataService.m
 
 Abstract: Temperature Alarm Service Code - Connect to a peripheral 
 get notified when the temperature changes and goes past settable
 maximum and minimum temperatures.
 
 Version: 1.0
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by 
 Apple Inc. ("Apple") in consideration of your agreement to the
 following terms, and your use, installation, modification or
 redistribution of this Apple software constitutes acceptance of these
 terms.  If you do not agree with these terms, please do not use,
 install, modify or redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software. 
 Neither the name, trademarks, service marks or logos of Apple Inc. 
 may be used to endorse or promote products derived from the Apple
 Software without specific prior written permission from Apple.  Except
 as expressly stated in this notice, no other rights or licenses, express
 or implied, are granted by Apple herein, including but not limited to
 any patent rights that may be infringed by your derivative works or by
 other works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2011 Apple Inc. All Rights Reserved.
 
 */



#import "LeDataService.h"
#import "LeDiscovery.h"

#define START_SYSEX             0xF0
#define END_SYSEX               0xF7

#define DIGITAL_MESSAGE         0x90 // send data for a digital pin
#define ANALOG_MESSAGE          0xE0 //
#define REPORT_VERSION          0xF9 // report firmware version
#define REPORT_FIRMWARE         0x79 // report name and version of the firmware

#define RESERVED_COMMAND        0x00 // 2nd SysEx data byte is a chip-specific command (AVR, PIC, TI, etc).
#define ANALOG_MAPPING_QUERY    0x69 // ask for mapping of analog to pin numbers
#define ANALOG_MAPPING_RESPONSE 0x6A // reply with mapping info
#define CAPABILITY_QUERY        0x6B // ask for supported modes and resolution of all pins
#define CAPABILITY_RESPONSE     0x6C // reply with supported modes and resolution
#define PIN_STATE_QUERY         0x6D // ask for a pin's current mode and value
#define PIN_STATE_RESPONSE      0x6E // reply with a pin's current mode and value
#define EXTENDED_ANALOG         0x6F // analog write (PWM, Servo, etc) to any pin
#define SERVO_CONFIG            0x70 // set max angle, minPulse, maxPulse, freq
#define STRING_DATA             0x71 // a string message with 14-bits per char
#define SHIFT_DATA              0x75 // shiftOut config/data message (34 bits)
#define I2C_REQUEST             0x76 // I2C request messages from a host to an I/O board
#define I2C_REPLY               0x77 // I2C reply messages from an I/O board to a host
#define I2C_CONFIG              0x78 // Configure special I2C settings such as power pins and delay times
#define REPORT_FIRMWARE         0x79 // report name and version of the firmware
#define SAMPLING_INTERVAL       0x7A // sampling interval
#define SYSEX_NON_REALTIME      0x7E // MIDI Reserved for non-realtime messages
#define SYSEX_REALTIME          0x7F // MIDI Reserved for realtime messages


NSString *kTemperatureServiceUUIDString = @"FFF0";
NSString *kCurrentTemperatureCharacteristicUUIDString = @"FFF2";
NSString *kMinimumTemperatureCharacteristicUUIDString = @"FFF2";
NSString *kMaximumTemperatureCharacteristicUUIDString = @"FFF2";
NSString *kAlarmCharacteristicUUIDString = @"FFF1";

NSString *kAlarmServiceEnteredBackgroundNotification = @"kAlarmServiceEnteredBackgroundNotification";
NSString *kAlarmServiceEnteredForegroundNotification = @"kAlarmServiceEnteredForegroundNotification";

@interface LeDataService() <CBPeripheralDelegate> {
@private
    CBPeripheral		*servicePeripheral;
    
    CBService			*dataService;
    
    CBCharacteristic    *tempCharacteristic;
    CBCharacteristic	*minTemperatureCharacteristic;
    CBCharacteristic    *maxTemperatureCharacteristic;
    CBCharacteristic    *alarmCharacteristic;
    
    CBUUID              *temperatureAlarmUUID;
    CBUUID              *minimumTemperatureUUID;
    CBUUID              *maximumTemperatureUUID;
    CBUUID              *currentTemperatureUUID;
    
    NSMutableData       *firmataData;
    BOOL                inMessage;

    id<LeDataProtocol>	peripheralDelegate;
}
@end



@implementation LeDataService


@synthesize peripheral = servicePeripheral;


#pragma mark -
#pragma mark Init
/****************************************************************************/
/*								Init										*/
/****************************************************************************/
- (id) initWithPeripheral:(CBPeripheral *)peripheral controller:(id<LeDataProtocol>)controller
{
    self = [super init];
    if (self) {
        firmataData = [[NSMutableData alloc] init];
        inMessage=false;
        
        servicePeripheral = [peripheral retain];
        [servicePeripheral setDelegate:self];
		peripheralDelegate = controller;
        
        minimumTemperatureUUID	= [[CBUUID UUIDWithString:kMinimumTemperatureCharacteristicUUIDString] retain];
        maximumTemperatureUUID	= [[CBUUID UUIDWithString:kMaximumTemperatureCharacteristicUUIDString] retain];
        currentTemperatureUUID	= [[CBUUID UUIDWithString:kCurrentTemperatureCharacteristicUUIDString] retain];
        temperatureAlarmUUID	= [[CBUUID UUIDWithString:kAlarmCharacteristicUUIDString] retain];
	}
    return self;
}


- (void) dealloc {
	if (servicePeripheral) {
		[servicePeripheral setDelegate:[LeDiscovery sharedInstance]];
		[servicePeripheral release];
		servicePeripheral = nil;
        
        [minimumTemperatureUUID release];
        [maximumTemperatureUUID release];
        [currentTemperatureUUID release];
        [temperatureAlarmUUID release];
        
        [firmataData release];
    }
    [super dealloc];
}


- (void) reset
{
	if (servicePeripheral) {
		[servicePeripheral release];
		servicePeripheral = nil;
	}
}



#pragma mark -
#pragma mark Service interaction
/****************************************************************************/
/*							Service Interactions							*/
/****************************************************************************/
- (void) start
{
	CBUUID	*serviceUUID	= [CBUUID UUIDWithString:kTemperatureServiceUUIDString];
	NSArray	*serviceArray	= [NSArray arrayWithObjects:serviceUUID, nil];

    [servicePeripheral discoverServices:serviceArray];
}

- (void) peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
	NSArray		*services	= nil;
	NSArray		*uuids	= [NSArray arrayWithObjects:currentTemperatureUUID, // Current Temp
								   minimumTemperatureUUID, // Min Temp
								   maximumTemperatureUUID, // Max Temp
								   temperatureAlarmUUID, // Alarm Characteristic
								   nil];

	if (peripheral != servicePeripheral) {
		NSLog(@"Wrong Peripheral.\n");
		return ;
	}
    
    if (error != nil) {
        NSLog(@"Error %@\n", error);
		return ;
	}

	services = [peripheral services];
	if (!services || ![services count]) {
		return ;
	}

	dataService = nil;
    
	for (CBService *service in services) {
		if ([[service UUID] isEqual:[CBUUID UUIDWithString:kTemperatureServiceUUIDString]]) {
			dataService = service;
			break;
		}
	}

	if (dataService) {
		[peripheral discoverCharacteristics:uuids forService:dataService];
	}
}


- (void) peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error;
{
	NSArray		*characteristics	= [service characteristics];
	CBCharacteristic *characteristic;
    
	if (peripheral != servicePeripheral) {
		NSLog(@"Wrong Peripheral.\n");
		return ;
	}
	
	if (service != dataService) {
		NSLog(@"Wrong Service.\n");
		return ;
	}
    
    if (error != nil) {
		NSLog(@"Error %@\n", error);
		return ;
	}
    
	for (characteristic in characteristics) {
        NSLog(@"discovered characteristic %@", [characteristic UUID]);
        
		if ([[characteristic UUID] isEqual:minimumTemperatureUUID]) { // Min Temperature.
            NSLog(@"Discovered Minimum Alarm Characteristic");
			minTemperatureCharacteristic = [characteristic retain];
			[peripheral readValueForCharacteristic:characteristic];
		}
        else if ([[characteristic UUID] isEqual:maximumTemperatureUUID]) { // Max Temperature.
            NSLog(@"Discovered Maximum Alarm Characteristic");
			maxTemperatureCharacteristic = [characteristic retain];
			[peripheral readValueForCharacteristic:characteristic];
		}
        else if ([[characteristic UUID] isEqual:temperatureAlarmUUID]) { // Alarm
            NSLog(@"Discovered Alarm Characteristic");
			alarmCharacteristic = [characteristic retain];
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
		}
        else if ([[characteristic UUID] isEqual:currentTemperatureUUID]) { // Current Temp
            NSLog(@"Discovered Temperature Characteristic");
			tempCharacteristic = [characteristic retain];
			[peripheral readValueForCharacteristic:tempCharacteristic];
			[peripheral setNotifyValue:YES forCharacteristic:characteristic];
		} 
	}
}



#pragma mark -
#pragma mark Characteristics interaction
/****************************************************************************/
/*						Characteristics Interactions						*/
/****************************************************************************/
- (void) write:(NSData *)data
{
    
    if (!servicePeripheral) {
        NSLog(@"Not connected to a peripheral");
		return ;
    }

    if (!minTemperatureCharacteristic) {
        NSLog(@"No valid minTemp characteristic");
        return;
    }
    
    [servicePeripheral writeValue:data forCharacteristic:minTemperatureCharacteristic type:CBCharacteristicWriteWithResponse];
}

- (void) analogMappingQuery{
    [self write:[NSData dataWithBytes:(const char *[]){START_SYSEX, ANALOG_MAPPING_QUERY, END_SYSEX} length:3]];
}

- (void) capabilityQuery{
    [self write:[NSData dataWithBytes:(const char *[]){START_SYSEX, CAPABILITY_QUERY, END_SYSEX} length:3]];
}

- (void) pinStateQuery:(int)pin{
    [self write:[NSData dataWithBytes:(const char *[]){START_SYSEX, PIN_STATE_QUERY, pin, END_SYSEX} length:4]];
}

//- (void) extendedAnalogQuery:(int)pin:] withData:(NSData)data{
//    [self write:[NSData dataWithBytes:(const char *[]){START_SYSEX, EXTENDED_ANALOG, pin, END_SYSEX} length:3]];
//}

- (void) servoConfig:(int)pin minPulseLSB:(int)minPulseLSB minPulseMSB:(int)minPulseMSB maxPulseLSB:(int)maxPulseLSB maxPulseMSB:(int)maxPulseMSB{
    [self write:[NSData dataWithBytes:(const char *[]){START_SYSEX, SERVO_CONFIG, pin, minPulseLSB, minPulseMSB, maxPulseLSB, maxPulseMSB, END_SYSEX} length:8]];
}

//- (void) stringData:(NSString)string{
//    [self write:[NSData dataWithBytes:(const char *[]){START_SYSEX, STRING_DATA, END_SYSEX} length:3]];
//}

//- (void) shiftData:(int)high{
//    [self write:[NSData dataWithBytes:(const char *[]){START_SYSEX, SHIFT_DATA, END_SYSEX} length:3]];
//}
//
//- (void) i2cRequest:(int)high{
//    [self write:[NSData dataWithBytes:(const char *[]){START_SYSEX, I2C_REQUEST, END_SYSEX} length:3]];
//}
//
//- (void) i2cConfig:(int)high{
//    [self write:[NSData dataWithBytes:(const char *[]){START_SYSEX, I2C_CONFIG, END_SYSEX} length:3]];
//}

- (void) reportFirmware{
    [self write:[NSData dataWithBytes:(const char *[]){START_SYSEX, REPORT_FIRMWARE, END_SYSEX} length:3]];
}

- (void) samplingInterval:(int)intervalMillisecondLSB intervalMillisecondMSB:(int)intervalMillisecondMSB{
    [self write:[NSData dataWithBytes:(const char *[]){START_SYSEX, SAMPLING_INTERVAL, intervalMillisecondMSB, intervalMillisecondMSB, END_SYSEX} length:5]];
}


/** If we're connected, we don't want to be getting temperature change notifications while we're in the background.
 We will want alarm notifications, so we don't turn those off.
 */
- (void)enteredBackground
{
    // Find the fishtank service
    for (CBService *service in [servicePeripheral services]) {
        if ([[service UUID] isEqual:[CBUUID UUIDWithString:kTemperatureServiceUUIDString]]) {
            
            // Find the temperature characteristic
            for (CBCharacteristic *characteristic in [service characteristics]) {
                if ( [[characteristic UUID] isEqual:[CBUUID UUIDWithString:kCurrentTemperatureCharacteristicUUIDString]] ) {
                    
                    // And STOP getting notifications from it
                    [servicePeripheral setNotifyValue:NO forCharacteristic:characteristic];
                }
            }
        }
    }
}

/** Coming back from the background, we want to register for notifications again for the temperature changes */
- (void)enteredForeground
{
    // Find the fishtank service
    for (CBService *service in [servicePeripheral services]) {
        if ([[service UUID] isEqual:[CBUUID UUIDWithString:kTemperatureServiceUUIDString]]) {
            
            // Find the temperature characteristic
            for (CBCharacteristic *characteristic in [service characteristics]) {
                if ( [[characteristic UUID] isEqual:[CBUUID UUIDWithString:kCurrentTemperatureCharacteristicUUIDString]] ) {
                    
                    // And START getting notifications from it
                    [servicePeripheral setNotifyValue:YES forCharacteristic:characteristic];
                }
            }
        }
    }
}

- (CGFloat) minimumTemperature
{
    CGFloat result  = NAN;
    int16_t value	= 0;
	
    if (minTemperatureCharacteristic) {
        [[minTemperatureCharacteristic value] getBytes:&value length:sizeof (value)];
        result = (CGFloat)value / 10.0f;
    }
    return result;
}


- (CGFloat) maximumTemperature
{
    CGFloat result  = NAN;
    int16_t	value	= 0;
    
    if (maxTemperatureCharacteristic) {
        [[maxTemperatureCharacteristic value] getBytes:&value length:sizeof (value)];
        result = (CGFloat)value / 10.0f;
    }
    return result;
}


- (CGFloat) temperature
{
    CGFloat result  = NAN;
    int16_t	value	= 0;

	if (tempCharacteristic) {
        [[tempCharacteristic value] getBytes:&value length:sizeof (value)];
        result = (CGFloat)value / 10.0f;
    }
    return result;
}


- (void) peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{

	if (peripheral != servicePeripheral) {
		NSLog(@"Wrong peripheral\n");
		return ;
	}

    if ([error code] != 0) {
		NSLog(@"Error %@\n", error);
		return ;
	}

    /* Temperature change */
    if ([[characteristic UUID] isEqual:currentTemperatureUUID]) {
        [peripheralDelegate alarmServiceDidChangeTemperature:self];
        return;
    }
    
    /* Alarm change */
    if ([[characteristic UUID] isEqual:temperatureAlarmUUID]) {
        
        
        unsigned char mockHex[] = {0xf0,0x90,0x20,0x20,0x20,0xf7};
        NSData *mock = [NSData dataWithBytes:mockHex length:6];
        
         
        const unsigned char *bytes = [mock bytes]; //[alarmCharacteristic value]
        for (int i = 0; i < [mock length]; i++)
        {
            const unsigned char byte = bytes[i];
            NSLog(@"Processing %02hhx", byte);
            
            if(inMessage){

                if(byte==END_SYSEX){
                    NSLog(@"End sysex received");
                    inMessage=false;
                    
                    //nightmare to get back first byte of nsdata...
                    NSRange range = NSMakeRange (0, 1);
                    unsigned char buffer;
                    [firmataData getBytes:&buffer range:range];
                    NSLog(@"Control byte is %02hhx", buffer);

                    switch ( buffer )
                    {
                        case DIGITAL_MESSAGE:
                            NSLog(@"type of message is digital");
                            break;
                            
                        case ANALOG_MESSAGE:
                            NSLog(@"type of message is anlog");
                            break;
                            
                        case REPORT_FIRMWARE:
                            NSLog(@"type of message is firmware report");
                            break;
                            
                        case REPORT_VERSION:
                            NSLog(@"type of message is version report");
                            break;
                            
                        default:
                            NSLog(@"type of message unknown");
                            break;
                    }
                }
                else{
                    NSLog(@"appending %02hhx", byte);
                    [firmataData appendBytes:( const void * )&byte length:1];
                }
            }
            else if(byte==START_SYSEX){
                NSLog(@"Start sysex received, clear data");
                [firmataData setLength:0];
                inMessage=true;
            }
        }
        return;
    }
    
               

    /* Upper or lower bounds changed */
    if ([characteristic.UUID isEqual:minimumTemperatureUUID] || [characteristic.UUID isEqual:maximumTemperatureUUID]) {
        [peripheralDelegate alarmServiceDidChangeTemperatureBounds:self];
    }
}


- (void) peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    /* When a write occurs, need to set off a re-read of the local CBCharacteristic to update its value */
    [peripheral readValueForCharacteristic:characteristic];
    
    /* Upper or lower bounds changed */
    if ([characteristic.UUID isEqual:minimumTemperatureUUID] || [characteristic.UUID isEqual:maximumTemperatureUUID]) {
        [peripheralDelegate alarmServiceDidChangeTemperatureBounds:self];
    }
}
@end
