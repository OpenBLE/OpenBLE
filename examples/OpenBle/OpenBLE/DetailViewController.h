//
//  DetailViewController.h
//  OpenBLE
//
//  Created by Jacob on 11/11/13.
//  Copyright (c) 2013 Augmetous Inc.
//

#import <UIKit/UIKit.h>
#import "LeDataService.h"
#import "LeDiscovery.h"

@interface DetailViewController : UIViewController <LeDiscoveryDelegate, LeDataProtocol>

@property (weak, nonatomic) IBOutlet UITextView *response;
@property (weak, nonatomic) IBOutlet UITextField *input;
@property (weak, nonatomic) IBOutlet UIButton *sendButton;
@property (weak, nonatomic) IBOutlet UISwitch *notifySwitch;
@property (weak, nonatomic) IBOutlet UILabel *RSSI;

@property (strong, nonatomic) LeDataService *currentlyDisplayingService;

-(IBAction)send:(id)sender;
-(IBAction)back:(id)sender;

@end