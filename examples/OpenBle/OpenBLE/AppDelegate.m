/*
 
 File: AppDelegate.m
 
 Abstract: Boilerplate Appl AppDelegate
 
 */

#import "AppDelegate.h"
#import "LeDataService.h"   // For the Notification strings

@implementation AppDelegate

@synthesize window = _window;

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kDataServiceEnteredBackgroundNotification object:self];
    //    NSLog(@"Entered background...");
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kDataServiceEnteredForegroundNotification object:self];
    //    NSLog(@"Entered foreground...");
}

@end

