/*
 
 File: LeDiscovery.m
 
 Abstract: Scan for and discover nearby LE peripherals with the
 matching service UUID.
 
 
 */



#import "LeDiscovery.h"


@interface LeDiscovery () <CBCentralManagerDelegate, CBPeripheralDelegate> {
	CBCentralManager    *centralManager;
	BOOL				pendingInit;
}
@end


@implementation LeDiscovery

@synthesize foundPeripherals;
@synthesize connectedServices;
@synthesize discoveryDelegate;
@synthesize peripheralDelegate;



#pragma mark -
#pragma mark Init
/****************************************************************************/
/*									Init									*/
/****************************************************************************/
+ (id) sharedInstance
{
	static LeDiscovery	*this	= nil;
    
	if (!this)
		this = [[LeDiscovery alloc] init];
    
	return this;
}


- (id) init
{
    self = [super init];
    if (self) {
		pendingInit = YES;
		centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
        
		foundPeripherals = [[NSMutableArray alloc] init];
		connectedServices = [[NSMutableArray alloc] init];
	}
    return self;
}


- (void) dealloc
{
    // We are a singleton and as such, dealloc shouldn't be called.
    assert(NO);
}



#pragma mark -
#pragma mark Restoring
/****************************************************************************/
/*								Settings									*/
/****************************************************************************/
/* Reload from file. */
- (void) loadSavedDevices
{
	NSArray	*storedDevices	= [[NSUserDefaults standardUserDefaults] arrayForKey:@"StoredDevices"];
    
	if (![storedDevices isKindOfClass:[NSArray class]]) {
        NSLog(@"No stored array to load");
        return;
    }
    
    for (id deviceUUIDString in storedDevices) {
        
        if (![deviceUUIDString isKindOfClass:[NSString class]])
            continue;
        
        CFUUIDRef uuid = CFUUIDCreateFromString(NULL, (CFStringRef)deviceUUIDString);
        if (!uuid)
            continue;
        
        [centralManager retrievePeripherals:[NSArray arrayWithObject:(__bridge id)uuid]];
        CFRelease(uuid);
    }
    
}


- (void) addSavedDevice:(CFUUIDRef) uuid
{
	NSArray			*storedDevices	= [[NSUserDefaults standardUserDefaults] arrayForKey:@"StoredDevices"];
	NSMutableArray	*newDevices		= nil;
	CFStringRef		uuidString		= NULL;
    
	if (![storedDevices isKindOfClass:[NSArray class]]) {
        NSLog(@"Can't find/create an array to store the uuid");
        return;
    }
    
    newDevices = [NSMutableArray arrayWithArray:storedDevices];
    
    uuidString = CFUUIDCreateString(NULL, uuid);
    if (uuidString) {
        [newDevices addObject:(__bridge NSString*)uuidString];
        CFRelease(uuidString);
    }
    /* Store */
    [[NSUserDefaults standardUserDefaults] setObject:newDevices forKey:@"StoredDevices"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


- (void) removeSavedDevice:(CFUUIDRef) uuid
{
	NSArray			*storedDevices	= [[NSUserDefaults standardUserDefaults] arrayForKey:@"StoredDevices"];
	NSMutableArray	*newDevices		= nil;
	CFStringRef		uuidString		= NULL;
    
	if ([storedDevices isKindOfClass:[NSArray class]]) {
		newDevices = [NSMutableArray arrayWithArray:storedDevices];
        
		uuidString = CFUUIDCreateString(NULL, uuid);
		if (uuidString) {
			[newDevices removeObject:(__bridge NSString*)uuidString];
            CFRelease(uuidString);
        }
		/* Store */
		[[NSUserDefaults standardUserDefaults] setObject:newDevices forKey:@"StoredDevices"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
}


- (void) centralManager:(CBCentralManager *)central didRetrieveConnectedPeripherals:(NSArray *)peripherals
{
	CBPeripheral	*peripheral;
	
	/* Add to list. */
	for (peripheral in peripherals) {
		[central connectPeripheral:peripheral options:nil];
	}
	[discoveryDelegate discoveryDidRefresh];
}


- (void) centralManager:(CBCentralManager *)central didRetrievePeripheral:(CBPeripheral *)peripheral
{
	[central connectPeripheral:peripheral options:nil];
	[discoveryDelegate discoveryDidRefresh];
}


- (void) centralManager:(CBCentralManager *)central didFailToRetrievePeripheralForUUID:(CFUUIDRef)UUID error:(NSError *)error
{
	/* Nuke from plist. */
	[self removeSavedDevice:UUID];
}



#pragma mark -
#pragma mark Discovery
/****************************************************************************/
/*								Discovery                                   */
/****************************************************************************/
- (void) startScanningForUUIDString:(NSString *)uuidString
{
    NSArray			*uuidArray;
    
    if(uuidString){
        uuidArray	= [NSArray arrayWithObjects:[CBUUID UUIDWithString:uuidString], nil];
    }
    else {
        uuidArray = nil;
    }
    
	NSDictionary	*options	= [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:CBCentralManagerScanOptionAllowDuplicatesKey];
    
	[centralManager scanForPeripheralsWithServices:uuidArray options:options];
}


- (void) stopScanning
{
	[centralManager stopScan];
}


- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
	if (![foundPeripherals containsObject:peripheral]) {
		[foundPeripherals addObject:peripheral];
		[discoveryDelegate discoveryDidRefresh];
	}
}



#pragma mark -
#pragma mark Connection/Disconnection
/****************************************************************************/
/*						Connection/Disconnection                            */
/****************************************************************************/
- (void) connectPeripheral:(CBPeripheral*)peripheral
{
	if (![peripheral isConnected]) {
		[centralManager connectPeripheral:peripheral options:nil];
	}
}


- (void) disconnectPeripheral:(CBPeripheral*)peripheral
{
	[centralManager cancelPeripheralConnection:peripheral];
}


- (void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
	LeDataService	*service	= nil;
	
	/* Create a service instance. */
	service = [[LeDataService alloc] initWithPeripheral:peripheral controller:peripheralDelegate] ;
	[service start];
    
	if (![connectedServices containsObject:service])
		[connectedServices addObject:service];
    
	if ([foundPeripherals containsObject:peripheral])
		[foundPeripherals removeObject:peripheral];
    
    [peripheralDelegate serviceDidChangeStatus:service];
	[discoveryDelegate discoveryDidRefresh];
}


- (void) centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Attempted connection to peripheral %@ failed: %@", [peripheral name], [error localizedDescription]);
}


- (void) centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
	LeDataService	*service	= nil;
    
	for (service in connectedServices) {
		if ([service peripheral] == peripheral) {
			[connectedServices removeObject:service];
            [peripheralDelegate serviceDidChangeStatus:service];
			break;
		}
	}
    
	[discoveryDelegate discoveryDidRefresh];
}


- (void) clearDevices
{
    LeDataService	*service;
    [foundPeripherals removeAllObjects];
    
    for (service in connectedServices) {
        [service reset];
    }
    [connectedServices removeAllObjects];
}


- (void) centralManagerDidUpdateState:(CBCentralManager *)central
{
    static CBCentralManagerState previousState = -1;
    
	switch ([centralManager state]) {
		case CBCentralManagerStatePoweredOff:
		{
            [self clearDevices];
            [discoveryDelegate discoveryDidRefresh];
            
			/* Tell user to power ON BT for functionality, but not on first run - the Framework will alert in that instance. */
            if ((int)previousState != -1) {
                [discoveryDelegate discoveryStatePoweredOff];
            }
			break;
		}
            
		case CBCentralManagerStateUnauthorized:
		{
			/* Tell user the app is not allowed. */
			break;
		}
            
		case CBCentralManagerStateUnsupported:
		{
			/* Tell user the app is not allowed. */
			break;
		}
            
		case CBCentralManagerStateUnknown:
		{
			/* Bad news, let's wait for another event. */
			break;
		}
            
		case CBCentralManagerStatePoweredOn:
		{
			pendingInit = NO;
			[self loadSavedDevices];
			[centralManager retrieveConnectedPeripherals];
			[discoveryDelegate discoveryDidRefresh];
			break;
		}
            
		case CBCentralManagerStateResetting:
		{
			[self clearDevices];
            [discoveryDelegate discoveryDidRefresh];
            [peripheralDelegate serviceDidReset];
            
			pendingInit = YES;
			break;
		}
	}
    
    previousState = [centralManager state];
}
@end
