/*
 
 File: DetailViewController.m
 
 Abstract: User interface to send and receive data from connected peripheral.

 */

#import "DetailViewController.h"
#import "LeDataService.h"

@implementation DetailViewController

@synthesize currentlyDisplayingService;
@synthesize currentlyConnectedSensor;
@synthesize response;
@synthesize input;
@synthesize scrollView;
@synthesize activeField;

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
    
    [self registerForKeyboardNotifications];
    
    //fix for uiscrollview
    //http://stackoverflow.com/questions/8528134/uiscrollview-not-scrolling-when-keyboard-covers-active-uitextfield-using-apple
    CGRect applicationFrame = [[UIScreen mainScreen] applicationFrame];
    CGRect navigationFrame = [[self.navigationController navigationBar] frame];
    CGFloat height = applicationFrame.size.height - navigationFrame.size.height;
    CGSize newContentSize = CGSizeMake(applicationFrame.size.width, height);
    
    scrollView.contentSize = newContentSize;
    //end

    
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
    
    //TODO do something?
    if ( [[service peripheral] isConnected] ) {
        NSLog(@"Service (%@) connected", service.peripheral.name);
    }
    
    else {
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


#pragma mark -
#pragma mark UI Text Field Delegates
/****************************************************************************/
/*                        UI Text Field Methods                             */
/****************************************************************************/
-(BOOL) textFieldShouldReturn:(UITextField *)textField{
    
    [input resignFirstResponder];
    return YES;
}

// Call this method somewhere in your view controller setup code.
- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                   initWithTarget:self
                                   action:@selector(textFieldShouldReturn:)];
    [self.view addGestureRecognizer:tap];
    
}

// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification*)aNotification
{
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
    scrollView.contentInset = contentInsets;
    scrollView.scrollIndicatorInsets = contentInsets;
    
    // If active text field is hidden by keyboard, scroll it so it's visible
    // Your app might not need or want this behavior.
    CGRect aRect = self.view.frame;
    aRect.size.height -= kbSize.height;
    if (!CGRectContainsPoint(aRect, activeField.frame.origin) ) {
        [self.scrollView scrollRectToVisible:activeField.frame animated:YES];
    }
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    scrollView.contentInset = contentInsets;
    scrollView.scrollIndicatorInsets = contentInsets;
}

- (IBAction)textFieldDidBeginEditing:(UITextField *)textField
{
    activeField = textField;
}

- (IBAction)textFieldDidEndEditing:(UITextField *)textField
{
    activeField = nil;
}

@end
