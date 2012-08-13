//
//  BZAgentController.m
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-17.
//

#import "BZAgentController.h"

//Constants
#import "BZConstants.h"

//Managers
#import "BZJobManager.h"

//Model
#import "BZJob.h"

//Controllers
#import "BZWebViewController.h"

@interface BZAgentController () <UITextFieldDelegate, BZWebViewControllerDelegate, BZIdleViewDelegate>
@property (nonatomic, copy) NSString *activeURL;

- (void)registerForKeyboardNotifications;
- (void)unregisterForKeyboardNotifications;

- (void)startPolling;
- (void)stopPolling;
- (void)pollForJobs:(BOOL) fromAuto;

- (void)clearCachesFolder;
- (void)switchActiveUrl;

- (void)resetScreenSaverTimer;
- (void)startScreenSaverTimer;
- (void)stopScreenSaverTimer;
- (NSInteger)screenSaverTimeout;

@end

@implementation BZAgentController

@synthesize activeURL;

- (id)init
{
	self = [super init];
	if (self) {
        activeURLInd = -1;
        [self switchActiveUrl];
        // Set the index to -1 again, to avoid skipping the first server on the first poll
        activeURLInd = -1;
		isEnabled = NO;
		keyboardVisible = NO;
		busy = NO;
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(jobListUpdated:) name:BZNewJobReceivedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(failedToGetJobs:) name:BZFailedToGetJobsNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(noJobs:) name:BZNoJobsNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(jobUploaded:) name:BZJobUploadedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(failedToUploadJob:) name:BZFailedToUploadJobNotification object:nil];
		
		NSNumber *shouldAutoPoll = [[NSUserDefaults standardUserDefaults] objectForKey:kBZAutoPollSettingsKey];
		if (shouldAutoPoll && [shouldAutoPoll boolValue]) 
        {
            isEnabled = YES;
			[idleView showEnabled:@"Auto Polling enabled"];
			[self startPolling];
		}
        
        NSInteger screenSaverTimeout = [self screenSaverTimeout];
		if (screenSaverTimeout > 0) {
			[self startScreenSaverTimer];
		}

	}
	return self;
}

- (void)loadView
{
	[super loadView];
	
	idleView = [[BZIdleView alloc] initWithFrame:self.view.bounds];
	[idleView.pollNowButton addTarget:self action:@selector(pollNowPressed:) forControlEvents:UIControlEventTouchUpInside];
	[idleView.enabledSwitch addTarget:self action:@selector(enabledToggleValueChanged:) forControlEvents:UIControlEventValueChanged];
	idleView.apiURLField.delegate = self;
	[self.view addSubview:idleView];
	
	idleView.apiURLField.text = activeURL;
    idleView.delegate = self;

	[self registerForKeyboardNotifications];
}

- (void)viewDidUnload
{
	[idleView removeFromSuperview];
	[idleView release];
	idleView = nil;
	
	[super viewDidUnload];
}

- (void)dealloc
{
	[self unregisterForKeyboardNotifications];
	
	[pollTimer release];
	[idleView release];
	[activeURL release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Polling

- (void)tick:(NSTimer*)timer
{
	[self pollForJobs:true];
}

- (void)startPolling
{
	[self stopPolling];
	
	float pollFrequency = [[[NSUserDefaults standardUserDefaults] objectForKey:kBZJobsFetchTime] floatValue];
	if (pollFrequency <= 0) {
		pollFrequency = 5.0;
	}
	pollTimer = [[NSTimer scheduledTimerWithTimeInterval:pollFrequency target:self selector:@selector(tick:) userInfo:nil repeats:YES] retain];
}

- (void)stopPolling
{
	if (pollTimer) {
		[pollTimer invalidate];
		[pollTimer release];
		pollTimer = nil;
	}
}

- (NSString*)getActiveUrlKeyFromInd:(NSInteger)ind
{
    switch(ind) {
        case 0:
            return kBZJobsURL1SettingsKey;
        case 1:
            return kBZJobsURL2SettingsKey;
        case 2:
            return kBZJobsURL3SettingsKey;
        case 3:
            return kBZJobsURL4SettingsKey;
    }
    return @"";
    
}

- (void)switchActiveUrl
{
    // Advance the index of the active URL
    NSInteger newActiveInd = activeURLInd;
    do
    {
        newActiveInd = (newActiveInd+1)%4;
        // If there is a value in that server field, use it
        NSString* newActiveUrl = [[[NSUserDefaults standardUserDefaults] objectForKey:[self getActiveUrlKeyFromInd:newActiveInd]] retain];
        if ([newActiveUrl length] > 0) {
            activeURLInd = newActiveInd;
            activeURL = newActiveUrl;
            idleView.apiURLField.text = activeURL;
            break;
        }
    }
    while(newActiveInd != activeURLInd);
}

- (void)pollForJobs:(BOOL) fromAuto
{
    if (!busy) 
    {
        // Switch to the next valid server
        [self switchActiveUrl];
        
        [idleView showPolling:@"Polling"];
        [[BZJobManager sharedInstance] pollForJobs:activeURL fromAuto:fromAuto];
    }
}


#pragma mark -
#pragma mark View Events

- (void)pollNowPressed:(UIButton*)button
{
	[self pollForJobs:false];
	[self resetScreenSaverTimer];
}

- (void)enabledToggleValueChanged:(UISwitch*)toggle
{
	if ([toggle isOn]) {
		isEnabled = YES;
		[idleView showEnabled:@"Polling enabled"];
		[self startPolling];
	}
	else {
		isEnabled = NO;
		[idleView showDisabled:@"Polling disabled"];
		[self stopPolling];
	}
	[self resetScreenSaverTimer];
}

- (void)stopPollingRequested
{
	[self stopPolling];
	
	isEnabled = NO;
	[idleView.enabledSwitch setOn:NO animated:NO];
	[self resetScreenSaverTimer];
}

#pragma mark -
#pragma mark UITextFieldDelegate Methods

- (BOOL)textFieldShouldReturn:(UITextField*)textField
{
	[textField resignFirstResponder];
	return YES; //Let them return
}

- (void)textFieldDidEndEditing:(UITextField*)textField
{
	self.activeURL = textField.text;
	[[NSUserDefaults standardUserDefaults] setObject:activeURL forKey:[self getActiveUrlKeyFromInd:activeURLInd]];
}

#pragma mark -
#pragma mark Job Notifications

- (void)processNextJob:(BOOL)shouldPoll
{	
	if (!busy) {
		//First step is to clear the caches folder from last run... this is to make sure this app doesn't become bloated.
		[self clearCachesFolder];
		
		//Now poll for the next one if there are none in the queue.  Make sure that this is sequential so that the upload does not affect the next job.  We could theoretically download at the same time though.
		BZJobManager *jobManager = [BZJobManager sharedInstance];
		if ([jobManager hasJobs]) {
			busy = YES;
			
			//Enforce the timeout
			float timeout = [[[NSUserDefaults standardUserDefaults] objectForKey:kBZTimeoutSettingsKey] floatValue];
			if (timeout < -1) {
				timeout = 120;
			}

			BZWebViewController *webController = [[[BZWebViewController alloc] initWithJob:[jobManager nextJob] timeout:timeout] autorelease];
			webController.delegate = self;
			[self presentModalViewController:webController animated:NO];
		}
		else if (isEnabled && shouldPoll) {
			[self pollForJobs:false];
		}
		else if (isEnabled) {
			[idleView showEnabled:@"Polling enabled"];
		}
		else {
			[idleView showDisabled:@"Polling stopped"];
		}
	}
}

- (void)jobListUpdated:(NSNotification*)notification
{
#if BZ_DEBUG_JOB
	NSLog(@"Job list updated!");
#endif
	[idleView showPolling:@"Processing new job"];
	
	[self processNextJob:NO];
}

- (void)failedToGetJobs:(NSNotification*)notification
{
	NSDictionary *userInfo = [notification userInfo];
	NSString *reason = [userInfo objectForKey:kBZJobsErrorKey];
	[idleView showError:reason ? reason : @"Could not poll: unknown Error"];
}

- (void)noJobs:(NSNotification*)notification
{
#if BZ_DEBUG_JOB
	NSLog(@"No jobs to process");
#endif
	[self processNextJob:NO];
}

- (void)restartIfRequired
{
#if BZ_DEBUG_JOB
	NSLog(@"Checking if restart required");
#endif
    NSNumber *shouldRestartAfterJob = [[NSUserDefaults standardUserDefaults] objectForKey:kBZRestartAfterJobSettingsKey];
    if (shouldRestartAfterJob && [shouldRestartAfterJob boolValue] && isEnabled) 
    {
        if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"BlazeRecoverAgent://"]]) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"BlazeRecoverAgent://"]];
            NSLog(@"Restarting agent in 1 sec");
            kill(getpid(), 1);
        }
    }
    
}

- (void)jobUploaded:(NSNotification*)notification
{
	busy = NO;
#if BZ_DEBUG_JOB
	NSLog(@"Job uploaded");
#endif
    
    [self restartIfRequired];
    
	[self processNextJob:YES];
}

- (void)failedToUploadJob:(NSNotification*)notification
{
#if BZ_DEBUG_JOB
	NSLog(@"Failed to upload job");
#endif
	busy = NO;
	
	[idleView showError:@"Failed to upload"];
    
    [self restartIfRequired];

	[self processNextJob:YES];
}

#pragma mark -
#pragma mark BZWebViewControllerDelegate

- (void)jobCompleted:(BZJob*)job withResult:(BZResult*)result
{	
#if BZ_DEBUG_PRINT_HAR
	NSLog(@"Job completed: %@\n\n=====RESULT=====\n%@\n\n====RESULT END====\n", job, result);
#endif
	
	//Dismiss the web view
	[self dismissModalViewControllerAnimated:NO];
	
	// Compress screenshots with the image quality setting of the job.
	result.screenShotImageQuality = job.screenShotImageQuality;

    //dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [idleView showUploading:@"Publishing Results"];
        [[BZJobManager sharedInstance] publishResults:result url:activeURL];
    //});

    
}

- (void)jobInterrupted:(BZJob*)job
{
	busy = NO;
#if BZ_DEBUG_JOB
	NSLog(@"Job was cancelled: %@", job);
#endif
	
	[self dismissModalViewControllerAnimated:NO];
	
	//Do not process the next job
	[idleView showError:@"Last Job Interrupted!"];
}

#pragma mark -
#pragma mark Handling of Keyboard Appearing/Disappearing

- (void)registerForKeyboardNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)unregisterForKeyboardNotifications
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidHideNotification object:nil];
}

- (NSTimeInterval)keyboardAnimationDurationForNotification:(NSNotification*)notification
{
	NSDictionary* info = [notification userInfo];
	NSValue* value = [info objectForKey:UIKeyboardAnimationDurationUserInfoKey];
	NSTimeInterval duration = 0;
	[value getValue:&duration];
	return duration;
}

- (void)keyboardWillShow:(NSNotification*)aNotification
{
	if (keyboardVisible) {
		return;
	}
	
	[idleView.pollNowButton setEnabled:NO];
	
	NSDictionary *info = [aNotification userInfo];
	
	//Get the size of the keyboard.
	CGFloat height = 0;
	
	BOOL useFrameEnd = [[UIDevice currentDevice].systemVersion compare:@"3.2" options:NSNumericSearch] != NSOrderedAscending;
	if (useFrameEnd) {
		//We use the 'end' key here since the keyboard is not visible
		NSValue *value = [info objectForKey:UIKeyboardFrameEndUserInfoKey];
		height = [value CGRectValue].size.height;
	}
	else {
		NSValue *value = [info objectForKey:UIKeyboardBoundsUserInfoKey];
		height = [value CGRectValue].size.height;
	}
	
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationBeginsFromCurrentState:YES];
	[UIView setAnimationDuration:[self keyboardAnimationDurationForNotification:aNotification]];
	
	//Resize the scroll view (which is the root view of the window)
	CGRect viewFrame = idleView.scrollPanel.frame;
	viewFrame.size.height -= height;
	idleView.scrollPanel.frame = viewFrame;
	idleView.scrollPanel.scrollEnabled = YES;
	
	CGRect rectToScrollTo = CGRectOffset(idleView.apiURLField.frame, 0, 10);
	[idleView.scrollPanel scrollRectToVisible:rectToScrollTo animated:YES];
	keyboardVisible = YES;
	
	[UIView commitAnimations];
}

- (void)keyboardWillHide:(NSNotification*)aNotification
{
	NSDictionary *info = [aNotification userInfo];
	
	[idleView.pollNowButton setEnabled:YES];
	
    //Get the size of the keyboard.
	CGFloat height = 0;
	
	BOOL useFrameBegin = [[UIDevice currentDevice].systemVersion compare:@"3.2" options:NSNumericSearch] != NSOrderedAscending;
	if (useFrameBegin) {
		//We use the 'begin' value here since the keyboard is already visible
		NSValue *value = [info objectForKey:UIKeyboardFrameBeginUserInfoKey];
		height = [value CGRectValue].size.height;
	}
	else {
		NSValue *value = [info objectForKey:UIKeyboardBoundsUserInfoKey];
		height = [value CGRectValue].size.height;
	}
	
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationBeginsFromCurrentState:YES];
	[UIView setAnimationDuration:[self keyboardAnimationDurationForNotification:aNotification]];
	
	// Reset the height of the scroll view to its original value
	CGRect viewFrame = idleView.scrollPanel.frame;
	viewFrame.size.height += height;
	idleView.scrollPanel.frame = viewFrame;
	idleView.scrollPanel.scrollEnabled = NO;
	keyboardVisible = NO;
	
	[UIView commitAnimations];
}
 
#pragma mark -
#pragma mark Helper Methods
 
- (void)clearCachesFolder
{
	NSString *cachesFolder = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSError *error = nil;
	[[NSFileManager defaultManager] removeItemAtPath:cachesFolder error:&error];
	if (!error) {
		[[NSFileManager defaultManager] createDirectoryAtPath:cachesFolder withIntermediateDirectories:YES attributes:nil error:&error];
		if (error) {
			NSLog(@"%@", error);
		}
	}
}

- (void)adjustTimer
{
	if (busy) {
		[self stopScreenSaverTimer];
	}
	else {
		[self startScreenSaverTimer];
	}
}

#pragma mark -
#pragma mark Screen Saver

- (NSInteger)screenSaverTimeout
{
	return [[[NSUserDefaults standardUserDefaults] objectForKey:kBZScreenSaverSettingsKey] intValue];
}

- (void)startScreenSaverTimer
{
	if (screenSaverTimer) {
		[self stopScreenSaverTimer];
	}
	
	NSInteger time = [self screenSaverTimeout];
	if (time > 0) {
		//Tick every 5 seconds to see if we need to turn the screensaver on
		screenSaverTimer = [[NSTimer scheduledTimerWithTimeInterval:time * 60.0f target:self selector:@selector(screenSaverTick:) userInfo:nil repeats:YES] retain];
	}
}

- (void)stopScreenSaverTimer
{
	[idleView setScreensaverEnabled:NO];
	
	if (screenSaverTimer) {
		[screenSaverTimer invalidate];
		[screenSaverTimer release];
		screenSaverTimer = nil;
	}
}

- (void)resetScreenSaverTimer
{
	[self stopScreenSaverTimer];
	[self adjustTimer];
}

- (void)screenSaverTick:(NSTimer*)timer
{
	//Determine if we need to launch a screen saver
	[idleView setScreensaverEnabled:YES];
}

- (void)idleViewTouched:(BZIdleView*)view
{
	[self resetScreenSaverTimer];
}


@end
