/*
 
 File: DetailViewController.h
 
 Abstract: User interface to send and receive data from connected peripheral.
 
 */

#import <UIKit/UIKit.h>
#import "LeDataService.h"
#import "LeDiscovery.h"

@interface DetailViewController : UIViewController <LeDiscoveryDelegate, LeServiceDelegate, LeDataProtocol>

@property (strong, nonatomic) LeDataService *currentlyDisplayingService;
@property (strong, nonatomic) IBOutlet UILabel *currentlyConnectedSensor;
@property (strong, nonatomic) IBOutlet UITextView *response;
@property (strong, nonatomic) IBOutlet UITextField *input;

-(IBAction)send:(id)sender;

@end