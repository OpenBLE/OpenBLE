//
//  ViewController.m
//  OpenBLE
//
//  Created by Jacob on 11/11/13.
//  Copyright (c) 2013 Augmetous Inc.
//


#import <Foundation/Foundation.h>

#import "ScannerViewController.h"

@implementation ScannerViewController

@synthesize currentPeripheral;
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

    }
    return self;
}

//stuff that needs to happen once
- (void) viewDidLoad
{
    [super viewDidLoad];
}

//stuff that needs to happen every time we come back to this view controller
-(void)viewWillAppear:(BOOL)animated
{
    [[LeDiscovery sharedInstance] setDiscoveryDelegate:self];
    
    [[LeDiscovery sharedInstance] startScanningForUUIDString:nil];
    
    [sensorsTable reloadData];
}


- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void) dealloc 
{
    [[LeDiscovery sharedInstance] stopScanning];
	[[LeDiscovery sharedInstance] setDiscoveryDelegate:nil];
}

- (IBAction)refresh:(id)sender
{
    [self.refreshControl beginRefreshing];
    [[LeDiscovery sharedInstance] stopScanning];
    [[[LeDiscovery sharedInstance] foundPeripherals] removeAllObjects];
    [[LeDiscovery sharedInstance] startScanningForUUIDString:nil];
    [self.tableView reloadData];
    [self.refreshControl endRefreshing];
}

- (void)manualSegue
{
    [[LeDiscovery sharedInstance] stopScanning];
    
    //Switch to initial view controller of main storyboard
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil];
    UIViewController *viewController = [storyboard instantiateInitialViewController];
    [self presentViewController:viewController animated:YES completion:nil];
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
		devices = [[LeDiscovery sharedInstance] connectedPeripherals];
        peripheral = [devices objectAtIndex:row];
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
		res = [[[LeDiscovery sharedInstance] connectedPeripherals] count];
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
		devices = [[LeDiscovery sharedInstance] connectedPeripherals];
        currentPeripheral = [devices objectAtIndex:row];
        [self manualSegue];

	} else {
        //found devices, send off connect which will segue if successful
		devices = [[LeDiscovery sharedInstance] foundPeripherals];
    	peripheral = (CBPeripheral*)[devices objectAtIndex:row];
        [[LeDiscovery sharedInstance] connectPeripheral:peripheral];
	}
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if([indexPath section])
    {
        [[[LeDiscovery sharedInstance] foundPeripherals] removeObjectAtIndex:indexPath.row];
        [self.tableView reloadData];
    }
    else
    {
        CBPeripheral	*peripheral;
        NSArray			*devices;
        devices = [[LeDiscovery sharedInstance] connectedPeripherals];
        peripheral = [devices objectAtIndex:indexPath.row];
        
        [[LeDiscovery sharedInstance] disconnectPeripheral:peripheral];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if([indexPath section])
    {
        return @"delete";
    }
    else
    {
        return @"disconnect";
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

/** Peripheral disconnected -- do something? */
-(void)peripheralDidDisconnect:(CBPeripheral *)peripheral
{
    [sensorsTable reloadData];
}

/** Peripheral connected */
- (void) peripheralDidConnect:(CBPeripheral *)peripheral
{
    currentPeripheral = peripheral;
    [self manualSegue];
}

@end
