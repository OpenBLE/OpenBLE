//
//  DetailViewController.h
//  TemperatureSensor
//
//  Created by Jacob on 11/11/13.
//  Copyright (c) 2013 Apple Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LeDataService.h"

@interface DetailViewController : UIViewController  <LeDataProtocol>

@property (strong, nonatomic) LeDataService             *currentlyDisplayingService;
@property (strong, nonatomic) IBOutlet UILabel          *currentlyConnectedSensor;
@property (strong, nonatomic) IBOutlet UITextField      *response;
@property (strong, nonatomic) IBOutlet UITextField      *input;

-(IBAction)dismissKeyboard:(id)sender;
-(IBAction)send:(id)sender;
@end