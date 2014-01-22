//
//  ViewController.m
//  OpenBLE
//
//  Created by Jacob on 11/11/13.
//  Copyright (c) 2013 Augmetous Inc.
//

#import <Foundation/Foundation.h>

#import "ViewController.h"
#import "LeDiscovery.h"
#import "LeDataService.h"
#import "DetailViewController.h"
#import "BLECell.h"

@interface ViewController ()  <LeDiscoveryDelegate, LeServiceDelegate, UITableViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UITableView *sensorsTable;
@property (weak, nonatomic) IBOutlet UIRefreshControl *refreshControl;

@property (weak, nonatomic) LeDataService* currentlyDisplayingService;

@end

@implementation ViewController

@synthesize currentlyDisplayingService;
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
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackgroundNotification:) name:kDataServiceEnteredBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterForegroundNotification:) name:kDataServiceEnteredForegroundNotification object:nil];

    }
    return self;
}

//stuff that needs to happen once
- (void) viewDidLoad
{
    [super viewDidLoad];
    
    [self.refreshControl beginRefreshing];
    
    if (self.tableView.contentOffset.y == 0)
    {
        self.tableView.contentOffset = CGPointMake(0, -self.refreshControl.frame.size.height / 2);
    }
}

//stuff that needs to happen every time we come back to this view controller
-(void)viewWillAppear:(BOOL)animated
{
    [[LeDiscovery sharedInstance] setPeripheralDelegate:self];
	[[LeDiscovery sharedInstance] setDiscoveryDelegate:self];

    [self reset:nil];
}


- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void) dealloc 
{
    [[LeDiscovery sharedInstance] stopScanning];
    [[LeDiscovery sharedInstance] setPeripheralDelegate:nil];
	[[LeDiscovery sharedInstance] setDiscoveryDelegate:nil];
}

//turn stuff off before we move to next view
- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    DetailViewController *dest =[segue destinationViewController];
    dest.currentlyDisplayingService = (LeDataService*)sender;
    [(LeDataService*)sender setController:dest];
    
    //tell Discovery to that it should report to destination when its peripheral changes status
    [[LeDiscovery sharedInstance] setPeripheralDelegate:dest];

    [[LeDiscovery sharedInstance] stopScanning];
}

- (void)reset:(id)sender
{
    [[LeDiscovery sharedInstance] startScanningForUUIDString:nil];
}

#pragma mark -
#pragma mark LeData Interactions
/****************************************************************************/
/*                  LeData Interactions                                     */
/****************************************************************************/
- (LeDataService*) serviceForPeripheral:(CBPeripheral *)peripheral
{
    for (LeDataService *service in [[LeDiscovery sharedInstance] connectedServices]) {
        if ( [[service peripheral] isEqual:peripheral] ) {
            return service;
        }
    }
    
    return nil;
}

- (void)didEnterBackgroundNotification:(NSNotification*)notification
{   
    NSLog(@"Entered background notification called.");
    for (LeDataService *service in [[LeDiscovery sharedInstance] connectedServices]) {
        [service enteredBackground];
    }
}

- (void)didEnterForegroundNotification:(NSNotification*)notification
{
    NSLog(@"Entered foreground notification called.");
    for (LeDataService *service in [[LeDiscovery sharedInstance] connectedServices]) {
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
    NSLog(@"Service (%@) did receive characteristics", service.peripheral.name);
    currentlyDisplayingService = service;
    [self performSegueWithIdentifier: @"deviceView" sender:service];
}

/** Peripheral connected or disconnected */
- (void) serviceDidChangeStatus:(LeDataService*)service
{
    [self.tableView reloadData];
}

/** Received Data */
- (void) serviceDidReceiveData:(NSData*)data fromService:(LeDataService*)service
{
    
}

/** Central Manager reset */
- (void) serviceDidReset
{
    [self.tableView reloadData];
}


#pragma mark -
#pragma mark TableView Delegates
/****************************************************************************/
/*							TableView Delegates								*/
/****************************************************************************/
- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	CBPeripheral	*peripheral;
	NSArray			*devices;
	NSInteger		row	= [indexPath row];

    static NSString *cellID = @"deviceCell";
	BLECell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    
    //2 sections, connected devices and discovered devices
	if ([indexPath section] == 0)
    {
		devices = [[LeDiscovery sharedInstance] connectedServices];
        peripheral = [(LeDataService*)[devices objectAtIndex:row] peripheral];
	} else
    {        
		devices = [[LeDiscovery sharedInstance] foundPeripherals];
        peripheral = (CBPeripheral*)[devices objectAtIndex:row];
	}
    
    if ([[peripheral name] length])
    {
        [cell.name setText:[peripheral name]];
    }
    else
    {
        [cell.name setText:@"Peripheral"];
    }
    
    [cell.uuid setText:[[peripheral identifier] UUIDString]];

    if([peripheral isConnected])
    {
        [cell.status setText:@"Connected"];
    }else
    {
        [cell.status setText:@"Not Connected"];
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
        currentlyDisplayingService = [devices objectAtIndex:row];
        [self performSegueWithIdentifier: @"deviceView" sender:[devices objectAtIndex:row]];

	} else {
        //found devices, send off connect which will segue if successful
		devices = [[LeDiscovery sharedInstance] foundPeripherals];
    	peripheral = (CBPeripheral*)[devices objectAtIndex:row];
        [[LeDiscovery sharedInstance] connectPeripheral:peripheral];
	}
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    CBPeripheral	*peripheral;
	NSArray			*devices;
    
    //if device isnt connected we get bounds exception for array
    @try
    {
        devices = [[LeDiscovery sharedInstance] connectedServices];
        peripheral = [(LeDataService*)[devices objectAtIndex:indexPath.row] peripheral];
        
        if([peripheral isConnected]){
            return YES;
        }else{
            return NO;
        }
    }
    @catch(NSException* ex)
    {
        return NO;
    }
    
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    CBPeripheral	*peripheral;
	NSArray			*devices;
    devices = [[LeDiscovery sharedInstance] connectedServices];
    peripheral = [(LeDataService*)[devices objectAtIndex:indexPath.row] peripheral];
    
    [[LeDiscovery sharedInstance] disconnectPeripheral:peripheral];
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return @"disconnect";
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
