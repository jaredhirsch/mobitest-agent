//
//  BZRecoverAgentAppDelegate.m
//  BZRecoverAgent
//
//  Created by Joshua Tessier on 11-02-19.
//  Copyright 2011 Blaze. All rights reserved.
//

#import "BZRecoverAgentAppDelegate.h"

@implementation BZRecoverAgentAppDelegate

@synthesize window;
@synthesize rootViewController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    rootViewController = [[UIViewController alloc] init];
    window.rootViewController = rootViewController;
	
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	NSLog(@"Recover agent opened -- going to force BlazeAgent to re-open in 3 seconds");
	[self performSelector:@selector(restart) withObject:nil afterDelay:3.0f];
}

- (void)restart
{
	NSLog(@"Opening BlazeAgent");
	if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"BlazeAgent://"]]) {
		if ([[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"BlazeAgent://"]]) {
			NSLog(@"Success");
		}
		else {
			NSLog(@"Failed");
		}
	}
	else {
		NSLog(@"Cannot open!");
	}
}

- (void)dealloc
{
	[window release];
    [rootViewController release];
    [super dealloc];
}

@end
