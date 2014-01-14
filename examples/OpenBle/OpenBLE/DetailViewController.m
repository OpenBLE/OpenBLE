//
//  DetailViewController.m
//  OpenBLE
//
//  Created by Jacob on 11/11/13.
//  Copyright (c) 2013 Augmetous Inc.
//

#import "DetailViewController.h"
#import "LeDataService.h"

@implementation DetailViewController

@synthesize currentlyDisplayingService;
@synthesize currentlyConnectedSensor;
@synthesize response;
@synthesize input;

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
    
    currentlyConnectedSensor.text = [[currentlyDisplayingService peripheral] name];
}

- (void) viewDidUnload
{
    [self setCurrentlyConnectedSensor:nil];
    [self setResponse:nil];
    [self setCurrentlyDisplayingService:nil];
    
    [super viewDidUnload];
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
#pragma mark App IO
/****************************************************************************/
/*                              App IO Methods                              */
/****************************************************************************/
-(IBAction)send:(id)sender
{
    NSData* tosend=[[input text] dataUsingEncoding:NSUTF8StringEncoding];
    
    [currentlyDisplayingService write:tosend];
    
    NSString* newStr = [[NSString alloc] initWithFormat:@"< %@\n",[input text]] ;

    [response setText:[newStr stringByAppendingString:response.text]];
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
    
    NSString* newStr = [[NSString alloc] initWithData:data
                                              encoding:NSUTF8StringEncoding] ;
    
    NSString* newStr2 = [[NSString alloc] initWithFormat:@"> %@",newStr] ;

    [response setText:[newStr2 stringByAppendingString:response.text]];
}

//if your service supports writewithresponse, this confirms the data was received with ack
//otherwise just returns after an attempted send with error nil
//very helpful in metering a large batch of sends so you don't overwhelm the device's receive buffer
-(void)didWriteFromService:(LeDataService *)service withError:(NSError *)error{
    
}


#pragma mark -
#pragma mark LeService Delegate Methods
/****************************************************************************/
/*				LeServiceDelegate Delegate Methods                                */
/****************************************************************************/
/** Central Manager reset */
- (void) serviceDidReset
{
    //TODO do something? probably have to go back to root controller and reconnect?
}

/** Peripheral connected or disconnected */
- (void) serviceDidChangeStatus:(LeDataService*)service
{
    if ( [[service peripheral] isConnected] )
    {
        NSLog(@"Service (%@) connected", service.peripheral.name);
    }
    
    else
    {
        NSLog(@"Service (%@) disconnected", service.peripheral.name);
        [[self navigationController] popToRootViewControllerAnimated:YES];
    }
}


#pragma mark -
#pragma mark LeDiscoveryDelegate
/****************************************************************************/
/*                       LeDiscoveryDelegate Methods                        */
/****************************************************************************/
- (void) discoveryDidRefresh
{
}

- (void) discoveryStatePoweredOff
{
    NSString *title     = @"Bluetooth Power";
    NSString *message   = @"You must turn on Bluetooth in Settings in order to use LE";
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alertView show];
}

@end
