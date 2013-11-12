//
//  AppDelegate.m
//  OpenBLE
//
//  Created by Jacob on 11/12/13.
//  Copyright (c) 2013 Apple Inc. All rights reserved.
//

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

