//
//  DetailViewController.m
//  TemperatureSensor
//
//  Created by Jacob on 11/11/13.
//  Copyright (c) 2013 Apple Inc. All rights reserved.
//

#import "DetailViewController.h"
#import "LeDataService.h"

@implementation DetailViewController

@synthesize currentlyDisplayingService;
@synthesize currentlyConnectedSensor;
@synthesize response;

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
    UITextField *input = (UITextField*)sender;
    [sender resignFirstResponder];
    NSLog(@"Sending ascii: %@", [input text]);
    
    NSData* tosend=[[input text] dataUsingEncoding:NSUTF8StringEncoding];
    
    [currentlyDisplayingService write:tosend];
    
}

-(IBAction)dismissKeyboard:(id)sender
{
    [sender resignFirstResponder];
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
    
    [response setText:newStr];
}

/** Central Manager reset */
- (void) serviceDidReset
{
    //TODO do something? probably have to go back to root controller and reconnect?
}

/** Peripheral connected or disconnected */
- (void) serviceDidChangeStatus:(LeDataService*)service
{
    
    //TODO do something?
    if ( [[service peripheral] isConnected] ) {
        NSLog(@"Service (%@) connected", service.peripheral.name);
    }
    
    else {
        NSLog(@"Service (%@) disconnected", service.peripheral.name);

    }
}

@end
