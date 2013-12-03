/*
 
 File: ViewController.m
 
 Abstract: User interface to display a list of discovered peripherals
 and allow the user to connect to them.
 
 
 */

#import <Foundation/Foundation.h>

#import "ViewController.h"
#import "LeDiscovery.h"
#import "LeDataService.h"
#import "DetailViewController.h"


@interface ViewController ()  <LeDiscoveryDelegate, LeServiceDelegate, UITableViewDataSource, UITableViewDelegate>
@property (retain, nonatomic) LeDataService             *currentlyDisplayingService;
@property (retain, nonatomic) NSMutableArray            *connectedServices;
@property (retain, nonatomic) IBOutlet UITableView      *sensorsTable;

@property (retain, nonatomic) IBOutlet UIRefreshControl *refreshControl;
-(IBAction)refresh:(id)sender;
-(IBAction)reset:(UIStoryboardSegue *)segue;

@end

@implementation ViewController

@synthesize currentlyDisplayingService;
@synthesize connectedServices;
@synthesize sensorsTable;
@synthesize refreshControl;

#pragma mark -
#pragma mark View lifecycle
/****************************************************************************/
/*								View Lifecycle                              */
/****************************************************************************/
- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    connectedServices = [NSMutableArray new];
    
	[[LeDiscovery sharedInstance] setDiscoveryDelegate:self];
    [[LeDiscovery sharedInstance] setPeripheralDelegate:self];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackgroundNotification:) name:kDataServiceEnteredBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterForegroundNotification:) name:kDataServiceEnteredForegroundNotification object:nil];
    
    [self.refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    
    [self refresh:nil];
}

- (void) viewDidUnload
{

    [self setSensorsTable:nil];

    [self setConnectedServices:nil];
    [self setCurrentlyDisplayingService:nil];
    
    [[LeDiscovery sharedInstance] stopScanning];
    
    [super viewDidUnload];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void) dealloc 
{
    [[LeDiscovery sharedInstance] stopScanning];
    
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    
    DetailViewController *dest =[segue destinationViewController];
    dest.currentlyDisplayingService = currentlyDisplayingService;
    [currentlyDisplayingService setController:dest];
    
    //tell Discovery to that it should report to destination when its peripheral changes status
    [[LeDiscovery sharedInstance] setPeripheralDelegate:dest];

    [[LeDiscovery sharedInstance] stopScanning];
}

- (IBAction)refresh:(id)sender {
    [[LeDiscovery sharedInstance] startScanningForUUIDString:nil];
    
    [self.refreshControl beginRefreshing];
    
    if (self.tableView.contentOffset.y == 0) {
        
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^(void){
            
            self.tableView.contentOffset = CGPointMake(0, -self.refreshControl.frame.size.height);
            
        } completion:^(BOOL finished){
            
        }];
        
    }
}

- (IBAction)reset:(id)sender {
    [[LeDiscovery sharedInstance] setPeripheralDelegate:self];
    [self refresh:nil];
}

#pragma mark -
#pragma mark LeData Interactions
/****************************************************************************/
/*                  LeData Interactions                                     */
/****************************************************************************/
- (LeDataService*) serviceForPeripheral:(CBPeripheral *)peripheral
{
    for (LeDataService *service in connectedServices) {
        if ( [[service peripheral] isEqual:peripheral] ) {
            return service;
        }
    }
    
    return nil;
}

- (void)didEnterBackgroundNotification:(NSNotification*)notification
{   
    NSLog(@"Entered background notification called.");
    for (LeDataService *service in self.connectedServices) {
        [service enteredBackground];
    }
}

- (void)didEnterForegroundNotification:(NSNotification*)notification
{
    NSLog(@"Entered foreground notification called.");
    for (LeDataService *service in self.connectedServices) {
        [service enteredForeground];
    }    
}


#pragma mark -
#pragma mark LeDataProtocol Delegate Methods
/****************************************************************************/
/*				LeDataProtocol Delegate Methods                             */
/****************************************************************************/
- (void) serviceDidReceiveCharacteristicsFromService:(LeDataService*)service
{
    if(currentlyDisplayingService == service){
        [self performSegueWithIdentifier: @"deviceView" sender:self];
    }
}

/** Peripheral connected or disconnected */
- (void) serviceDidChangeStatus:(LeDataService*)service
{
    if ( [[service peripheral] isConnected] ) {
        NSLog(@"Service (%@) connected", service.peripheral.name);
        if (![connectedServices containsObject:service]) {
            [connectedServices addObject:service];
        }
    }
    
    else {
        NSLog(@"Service (%@) disconnected", service.peripheral.name);
        if ([connectedServices containsObject:service]) {
            [connectedServices removeObject:service];
        }
    }
}

/** Received Data */
- (void) serviceDidReceiveData:(NSData*)data fromService:(LeDataService*)service
{
    
}

/** Central Manager reset */
- (void) serviceDidReset
{
    [connectedServices removeAllObjects];
}


#pragma mark -
#pragma mark TableView Delegates
/****************************************************************************/
/*							TableView Delegates								*/
/****************************************************************************/
- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell	*cell;
	CBPeripheral	*peripheral;
	NSArray			*devices;
	NSInteger		row	= [indexPath row];
    static NSString *cellID = @"DeviceList";
    
	cell = [tableView dequeueReusableCellWithIdentifier:cellID];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellID] ;
    
    //2 sections, connected devices and discovered devices
	if ([indexPath section] == 0) {
		devices = [[LeDiscovery sharedInstance] connectedServices];
        peripheral = [(LeDataService*)[devices objectAtIndex:row] peripheral];
        
	} else {
		devices = [[LeDiscovery sharedInstance] foundPeripherals];
        peripheral = (CBPeripheral*)[devices objectAtIndex:row];
	}
    
    if ([[peripheral name] length]){
        [[cell textLabel] setText:[peripheral name]];
    }
    else {
        [[cell textLabel] setText:@"Peripheral"];
    }
    
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    if([peripheral isConnected]){
        [[cell detailTextLabel] setText:@"Connected"];
    }else {
        [[cell detailTextLabel] setText:@"Not Connected"];
    }
    
	return cell;
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	NSInteger	res = 0;
    
	if (section == 0)
		res = [[[LeDiscovery sharedInstance] connectedServices] count];
	else
		res = [[[LeDiscovery sharedInstance] foundPeripherals] count];
    
	return res;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{  
	CBPeripheral	*peripheral;
	NSArray			*devices;
	NSInteger		row	= [indexPath row];
	
	if ([indexPath section] == 0) {
        //connected devices, segue on over
		devices = [[LeDiscovery sharedInstance] connectedServices];
        peripheral = [(LeDataService*)[devices objectAtIndex:row] peripheral];
        currentlyDisplayingService = [self serviceForPeripheral:peripheral];
        [self performSegueWithIdentifier: @"deviceView" sender:self];

	} else {
        //found devices, send off connect which will segue if successful
		devices = [[LeDiscovery sharedInstance] foundPeripherals];
    	peripheral = (CBPeripheral*)[devices objectAtIndex:row];
        currentlyDisplayingService = [self serviceForPeripheral:peripheral];
        [[LeDiscovery sharedInstance] connectPeripheral:peripheral];
	}
}


#pragma mark -
#pragma mark LeDiscoveryDelegate 
/****************************************************************************/
/*                       LeDiscoveryDelegate Methods                        */
/****************************************************************************/
- (void) discoveryDidRefresh 
{
    [sensorsTable reloadData];
}

- (void) discoveryStatePoweredOff 
{
    NSString *title     = @"Bluetooth Power";
    NSString *message   = @"You must turn on Bluetooth in Settings in order to use LE";
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alertView show];
}

@end
