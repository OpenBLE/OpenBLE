//
//  DetailViewController.m
//  OpenBLE
//
//  Created by Jacob on 11/11/13.
//  Copyright (c) 2013 Augmetous Inc.
//

#import "DetailViewController.h"
#import "LeDataService.h"
#import "ScannerViewController.h"

@interface DetailViewController() {
@private
    bool background;
}
@end

@implementation DetailViewController

@synthesize currentlyDisplayingService;
@synthesize response;
@synthesize input;
@synthesize sendButton;
@synthesize notifySwitch;

#pragma mark -
#pragma mark View lifecycle
/****************************************************************************/
/*								View Lifecycle                              */
/****************************************************************************/
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void) viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    //Tell Discovery to report to us if anything happens with our peripherals
    [[LeDiscovery sharedInstance] setDiscoveryDelegate:self];

    //We left our peripheral in our root controller
    //This is a bit messy but moving between Storyboards is only half supported
    UINavigationController *navController = (UINavigationController*)[self.navigationController presentingViewController];
    ScannerViewController *rootController =(ScannerViewController*)[navController.viewControllers objectAtIndex:0];

    //Create a new DataService with peripheral, and tell it to report to us
    self.currentlyDisplayingService = [[LeDataService alloc] initWithPeripheral:(CBPeripheral*)rootController.currentPeripheral delegate:self];
    
    //start the service
    [currentlyDisplayingService start];
    
    //Until we know service has started, disable sending
    [sendButton setEnabled:NO];

    //set peripheral name into navigation header
    self.navigationItem.title = [[currentlyDisplayingService peripheral] name];
    
    //we want to know if we went into the background or came back
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackgroundNotification:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterForegroundNotification:) name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) dealloc
{
    //nil delegates so nothing points to us
    [[LeDiscovery sharedInstance] setDiscoveryDelegate:nil];
    [currentlyDisplayingService setDelegate:nil];
}


#pragma mark -
#pragma mark App IO
/****************************************************************************/
/*                              App IO Methods                              */
/****************************************************************************/
-(IBAction)send:(id)sender
{
    //send data
    NSData* tosend=[[input text] dataUsingEncoding:NSUTF8StringEncoding];
    [currentlyDisplayingService write:tosend];

    //put sent text in chat box
    NSString* newStr = [[NSString alloc] initWithFormat:@"< %@\n",[input text]] ;
    [response setText:[newStr stringByAppendingString:response.text]];
}

-(IBAction)back:(id)sender
{
    //We have to manually dismiss our view controller instead of using IB's back button
    [[self.navigationController presentingViewController] dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark -
#pragma mark LeDataProtocol Delegate Methods
/****************************************************************************/
/*				LeDataProtocol Delegate Methods                             */
/****************************************************************************/
/** Received data */
- (void) serviceDidReceiveData:(NSData*)data fromService:(LeDataService*)service
{
    if (service != currentlyDisplayingService)
        return;

    //format text and place in chat box
    NSString* newStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ;
    NSString* newStr2 = [[NSString alloc] initWithFormat:@"> %@",newStr] ;
    [response setText:[newStr2 stringByAppendingString:response.text]];
    
    if(background){
        UILocalNotification *localNotif = [[UILocalNotification alloc] init];
        localNotif.alertBody = newStr;
        localNotif.alertAction = @"BLE Message!";
        [[UIApplication sharedApplication] scheduleLocalNotification:localNotif];
    }
}

/** Confirms the data was received with ack (if supported), or the error */
-(void)didWriteFromService:(LeDataService *)service withError:(NSError *)error{
    //we just assume writes went through
}

/** Confirms service started fully */
- (void) serviceDidReceiveCharacteristicsFromService:(LeDataService*)service
{
    //all services go, enable button
    [sendButton setEnabled:YES];
}


#pragma mark -
#pragma mark LeDiscoveryDelegate
/****************************************************************************/
/*                       LeDiscoveryDelegate Methods                        */
/****************************************************************************/
/** Bluetooth support was disabled */
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
    //disable send
    [sendButton setEnabled:NO];
    
    //Try to reconnect
    [[LeDiscovery sharedInstance] connectPeripheral:peripheral];

    //may also just want to automatically go back to chooser
    //We have to manually dismiss our view controller instead of using IB's back button
    //[[self.navigationController presentingViewController] dismissViewControllerAnimated:YES completion:nil];
}

/** Peripheral connected */
- (void) peripheralDidConnect:(CBPeripheral *)peripheral
{
    //only get this if we reconnected, so restart service
    [currentlyDisplayingService start];
}

/** List of peripherals changed */
- (void) discoveryDidRefresh
{
    //shouldnt get this as we disable discovery in the Discovery class
}


#pragma mark -
#pragma mark Backgrounding Methods
/****************************************************************************/
/*                       Bacgrounding Methods                               */
/****************************************************************************/
- (void)didEnterBackgroundNotification:(NSNotification*)notification
{
    //if we were trying to reconnect to a peripheral, lets stop for battery life
    if([[currentlyDisplayingService peripheral] state] == CBPeripheralStateConnecting)
    {
        [[LeDiscovery sharedInstance] disconnectPeripheral:[currentlyDisplayingService peripheral]];
    }
    
    //if notify is off
    if(![notifySwitch isOn]){
        //Tell service we entered background so we don't get notifications
        [currentlyDisplayingService enteredBackground];
    }
    
    background = YES;
}

- (void)didEnterForegroundNotification:(NSNotification*)notification
{
    //if we're not connected, try to connect
    if([[currentlyDisplayingService peripheral] state] == CBPeripheralStateDisconnected)
    {
        [[LeDiscovery sharedInstance] connectPeripheral:[currentlyDisplayingService peripheral]];
    }
    
    //if notify is off
    if(![notifySwitch isOn]){
        //Tell service we entered foreground so we get text again
        [currentlyDisplayingService enteredForeground];
    }
    
    background = NO;
}

@end
