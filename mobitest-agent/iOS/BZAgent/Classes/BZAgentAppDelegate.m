//
//  BZAgentAppDelegate.m
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-17.
//  Copyright 2010 Blaze. All rights reserved.
//

#import "BZAgentAppDelegate.h"

#include <libkern/OSAtomic.h>
#include <execinfo.h>

//Constants
#import "BZConstants.h"

@interface BZAgentAppDelegate ()
- (void)initializeSettings;
@end

void InstallUncaughtExceptionHandler();
void restartAndKill();

@implementation BZAgentAppDelegate

@synthesize window;

#pragma mark -
#pragma mark Application lifecycle

+ (void)initialize {
    // Set user agent (the only problem is that we can't modify the User-Agent later in the program)
    NSString* userAgent = [[NSUserDefaults standardUserDefaults] objectForKey:kBZUserAgentSettingsKey];
    NSDictionary *dictionary = [[NSDictionary alloc] initWithObjectsAndKeys:userAgent, @"UserAgent", nil];
    [[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
    [dictionary release];
}

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions
{
	InstallUncaughtExceptionHandler();
	[self initializeSettings];
	
	window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
	
	//Disable the auto-lock feature
	application.idleTimerDisabled = YES;
	
	//Start our application off in the IdleController.  This controller will display a simple screen stating the current state of the
	//application.  This is useful for both debugging and getting some visual information on whether or not the agent is actually working.
	idleController = [[BZAgentController alloc] init];
	[self.window addSubview:idleController.view];
    [self.window makeKeyAndVisible];
    
    return YES;
}

- (void)dealloc
{
	[idleController release];
    [window release];
    [super dealloc];
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
	NSLog(@"Got low memory warning");
    restartAndKill();
}


#pragma mark -
#pragma mark Settings

- (void)initializeSettings
{
	//Ensure that our settings have default values
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *url1 = [defaults objectForKey:kBZJobsURL1SettingsKey];
	if (!url1) {
		[defaults setObject:@"http://wpt.blaze.io/" forKey:kBZJobsURL1SettingsKey];
	}
	NSString *url2 = [defaults objectForKey:kBZJobsURL2SettingsKey];
	if (!url2) {
		[defaults setObject:@"" forKey:kBZJobsURL2SettingsKey];
	}
	NSString *url3 = [defaults objectForKey:kBZJobsURL3SettingsKey];
	if (!url3) {
		[defaults setObject:@"" forKey:kBZJobsURL3SettingsKey];
	}
    NSString *url4 = [defaults objectForKey:kBZJobsURL4SettingsKey];
	if (!url4) {
		[defaults setObject:@"" forKey:kBZJobsURL4SettingsKey];
	}
    
	NSString *location = [defaults objectForKey:kBZJobsLocationSettingsKey];
	if (!location) {
		[defaults setObject:@"Test" forKey:kBZJobsLocationSettingsKey];
	}
	
	NSString *locationKey = [defaults objectForKey:kBZJobsLocationKeySettingsKey];
	if (!locationKey) {
		[defaults setObject:@"1234512345" forKey:kBZJobsLocationKeySettingsKey];
	}
	
	NSString *timeout = [defaults objectForKey:kBZTimeoutSettingsKey];
	if (!timeout) {
		[defaults setObject:@"60" forKey:kBZTimeoutSettingsKey];
	}
	
	NSString *fetchTime = [defaults objectForKey:kBZJobsFetchTime];
	if (!fetchTime) {
		[defaults setObject:@"5" forKey:kBZJobsFetchTime];
	}

    NSString *screenSaverTime = [defaults objectForKey:kBZScreenSaverSettingsKey];
	if (!screenSaverTime) {
		[defaults setObject:@"1" forKey:kBZScreenSaverSettingsKey];
	}

	NSNumber *fps = [defaults objectForKey:kBZFPSSettingsKey];
	if (!fps) {
		[defaults setObject:[NSNumber numberWithInt:1] forKey:kBZFPSSettingsKey];
	}

    NSNumber *vidQuality = [defaults objectForKey:kBZImageVideoQualitySettingsKey];
	if (!vidQuality) {
		[defaults setObject:[NSNumber numberWithFloat:0.3] forKey:kBZImageVideoQualitySettingsKey];
	}

    NSNumber *chkpointQuality = [defaults objectForKey:kBZImageCheckpointQualitySettingsKey];
	if (!chkpointQuality) {
		[defaults setObject:[NSNumber numberWithFloat:0.7] forKey:kBZImageCheckpointQualitySettingsKey];
	}

    NSNumber *imgResizeRatio = [defaults objectForKey:kBZImageResizeRatioSettingsKey];
	if (!imgResizeRatio) {
		[defaults setObject:[NSNumber numberWithFloat:1] forKey:kBZImageResizeRatioSettingsKey];
	}
	
	NSString *accept = [defaults objectForKey:kBZAcceptSettingsKey];
	if (!accept) {
		[defaults setObject:@"application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5" forKey:kBZAcceptSettingsKey];
	}
	
	NSString *acceptEncoding = [defaults objectForKey:kBZAcceptEncodingSettingsKey];
	if (!acceptEncoding) {
		[defaults setObject:@"gzip, deflate" forKey:kBZAcceptEncodingSettingsKey];
	}
	
	NSString *acceptLanguage = [defaults objectForKey:kBZAcceptLanguageSettingsKey];
	if (!acceptLanguage) {
		[defaults setObject:@"en-en" forKey:kBZAcceptLanguageSettingsKey];
	}
    
    NSNumber *maxOfflineSecs = [defaults objectForKey:kBZMaxOfflineSecsSettingsKey];
	if (!maxOfflineSecs) {
		[defaults setObject:[NSNumber numberWithInt:600] forKey:kBZMaxOfflineSecsSettingsKey];
	}
}


@end

void restartAndKill()
{
	if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"BlazeRecoverAgent://"]]) {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"BlazeRecoverAgent://"]];
        if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"BlazeRecoverAgent://"]]) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"BlazeRecoverAgent://"]];
            NSLog(@"About to kill current BlazeAgent app");
            kill(getpid(), 1);
            NSLog(@"Done killing current BlazeAgent app");
        }
	}
}
void HandleException(NSException *exception)
{
	NSLog(@"Uncaught exception: %@ -- Attempting to restart", exception);
    restartAndKill();
}

void SignalHandler(int signal)
{
	NSLog(@"Signal handler caught signal: %d", signal);
    restartAndKill();
}

void InstallUncaughtExceptionHandler()
{
	NSSetUncaughtExceptionHandler(&HandleException);
	signal(SIGABRT, SignalHandler);
	signal(SIGILL, SignalHandler);
	signal(SIGSEGV, SignalHandler);
	signal(SIGFPE, SignalHandler);
	signal(SIGBUS, SignalHandler);
	signal(SIGPIPE, SignalHandler);
}
