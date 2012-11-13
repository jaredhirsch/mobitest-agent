//
//  BZWebViewController.m
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-17.
//

#import "BZWebViewController.h"
#import "BZAgentController.h"
#import "BZJobManager.h"

//Additions
#import "NSData+Base64.h"

//Constants
#import "BZConstants.h"

#ifdef __APPLE__
#include "TargetConditionals.h"
#endif

#import </usr/include/objc/objc-class.h>

#ifdef BZ_DEBUG_REQUESTS
#include "WebViewPrivate.h"
#endif

//WARNING: Underground API usage
extern "C" CGImageRef UIGetScreenImage();
//
//We use it to render the entire screen (status bar included).  This provides better framerates since the 'above ground' alternative requires us to create
//an image context, iterate over the windows and render each of the windows onto the context.  This allows us to remove as much overhead as possible.
//

@interface NSURLRequest (PrivateAPI)
+ (void)setAllowsAnyHTTPSCertificate:(BOOL)allow forHost:(NSString*)host;
@end

@interface BZWebViewController () <UIWebViewDelegate, BZWebViewDelegate>
- (void)startJob;
- (void)completeJob;

- (void)startSession;
- (void)possiblyFullyCompleteSession;
- (void)fullyCompleteSession;
- (void)fullyCompleteSession:(BOOL)timeout;
- (void)markSessionAsComplete;

- (void)startRecording;
- (void)captureScreen;
- (void)captureScreen:(NSString*)identifier important:(BOOL)important;
- (void)pauseRecording;

- (void)startTimeoutTimer;
- (void)stopTimeoutTimer;

- (void)clearCache;
@end

@implementation BZWebViewController

@synthesize delegate;
@synthesize stopPollingButton;

- (id)initWithJob:(BZJob*)aJob timeout:(float)timeoutValue
{
	self = [super init];
	if (self) {
		job = [aJob retain];
		timeout = timeoutValue;
		currentRun = 0;
		currentSubRun = 0;
		
        cachesFolder = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] retain];
        resultFolder = [[cachesFolder stringByAppendingPathComponent:@"result"] retain];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveData:) name:BZDataReceivedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(responseReceived:) name:BZResponseReceivedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resultUploaded:) name:BZResultUploadedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resultUploadFailed:) name:BZResultUploadFailedNotification object:nil];
        
#if BZ_DEBUG_REQUESTS
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getDataSource:) name:BZPassDataSourceNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getWebViewPrivate:) name:BZPassWebViewPrivateNotification object:nil];
#endif        
        userAgent = [[NSUserDefaults standardUserDefaults] objectForKey:kBZUserAgentSettingsKey];

	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[timeoutTimer invalidate];
	[timeoutTimer release];
	timeoutTimer = nil;
	
	[recordingTimerStarted release];
	recordingTimerStarted = nil;
    
	[recordingTimer invalidate];
	[recordingTimer release];
	recordingTimer = nil;
	
	[stopPollingButton release];
	
	[job release];
	[result release];
	[webView release];
	
    [cachesFolder release];
    [resultFolder release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark View Setup and Teardown

- (void)createWebView
{
	webView = [[BZWebView alloc] initWithFrame:self.view.bounds];
	webView.delegate = self;
	webView.webViewDelegate = self;
	[self.view addSubview:webView];
	
	stopPollingButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	stopPollingButton.frame = self.view.bounds;
	[stopPollingButton addTarget:self action:@selector(stopPolling:) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:stopPollingButton];
}

- (void)destroyWebView
{
	if ([webView isLoading]) {
		@try {
			NSLog(@"[Controller] Halting loading before destroying the web view");
			[webView stopLoading];
		}
		@catch (NSException *e) {
			NSLog(@"[Controller] Caught an exception while stopping a load");
		}
	}
	[webView removeFromSuperview];
	[webView safeRelease];
	[webView release];
	webView = nil;
	
	[stopPollingButton removeFromSuperview];
	[stopPollingButton release];
	stopPollingButton = nil;
}

- (void)loadView
{
	[super loadView];

	[self createWebView];
}

- (void)viewDidUnload
{
	[self destroyWebView];
	
	[super viewDidUnload];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	//Time to get to work!
	[self startJob];
}

- (void)applicationWillResignActive:(NSNotification*)notification
{
	//Abandon whatever we're doing right now
	//TODO: Serialize the current job so that it's not lost
	[self pauseRecording];
	[webView stopLoading];
	
	if (delegate) {
		[delegate jobInterrupted:job];
	}
}

#pragma mark -
#pragma mark Work Flow

- (void)startJob
{
	//Create the result
	result = [[BZResult alloc] init];
	result.jobId = job.testId;
    // Compress screenshots with the image quality setting of the job.
    result.screenShotImageQuality = job.screenShotImageQuality;
	currentRun = 0;

	//Now get started
	[self startSession];
}

- (void)completeJob
{
	if (delegate) {
		[delegate jobCompleted:job withResult:result];
	}
}

- (void)incrementRunNumbers
{
	if (job.fvOnly || currentSubRun == 1) {
		++currentRun;
		[self clearCache];
		[self destroyWebView];
		[self createWebView];
		webView.result = result;
		
		currentSubRun = 0;
	}
	else if (currentRun == 0) {
		[self clearCache];
		
		++currentRun;
	}
	else {
		++currentSubRun;	
	}
}

- (void)startSession
{
	completing = NO;
	
	[self incrementRunNumbers];

	if (preCache) {
		NSLog(@"****** Running the CACHED VIEW %d-%d", currentRun, currentSubRun);
		preCache = NO;
	}
	else if (!preCache && currentSubRun == 1) {
		NSLog(@"****** Running the CACHED VIEW %d-%d", currentRun, currentSubRun);
//		NSLog(@"****** Running the precache run %d-%d", currentRun, currentSubRun);
//		[objc_getClass("WebCache") setDisabled:NO];
//		[self clearCache];
//		preCache = YES;
//		--currentSubRun;
	}
	else {
        
		//[BZAgentController clearCachesFolder];
		NSLog(@"****** Running the FIRST VIEW %d-%d", currentRun, currentSubRun);
		[objc_getClass("WebCache") setDisabled:YES];
		[objc_getClass("WebCache") setDisabled:NO];
	}
	
	NSURL *url = [NSURL URLWithString:job.url];
 	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:[[[NSUserDefaults standardUserDefaults] objectForKey:kBZTimeoutSettingsKey] floatValue]];
	
    [NSURLRequest setAllowsAnyHTTPSCertificate:YES forHost:[url host]];
    
	if (job.useBasicAuth) {
		//Set the Basic Authentication parameters
		NSData *userData = [[NSString stringWithFormat:@"%@:%@", job.login ? job.login : @"", job.password ? job.password : @""] dataUsingEncoding:NSASCIIStringEncoding];
		[request setValue:[NSString stringWithFormat:@"Basic %@", [userData base64EncodedString]] forHTTPHeaderField:@"Authorization"];
	}

	webView.result = preCache ? nil : result;
	
    if (![[NSFileManager defaultManager] fileExistsAtPath:resultFolder]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:resultFolder withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            NSLog(@"%@", error);
        }
    }

    NSString *videoFolder = nil;
 	if (!preCache) {
        videoFolder = [NSString stringWithFormat:@"video_%d%@", currentRun, (currentSubRun == 0 ? @"" : @"_cached")];
 		NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:[resultFolder stringByAppendingPathComponent:videoFolder] withIntermediateDirectories:YES attributes:nil error:&error];
 		if (error) {
 			NSLog(@"%@", error);
 		}
 	}

 	[webView reset];
 	
	[self startTimeoutTimer];

	if (!preCache) {
		[result startSession:job.url identifier:[NSString stringWithFormat:@"page_%d_%d", currentRun, currentSubRun] videoFolder:videoFolder];
        [self startRecording];
	}
    
	[webView loadRequest:request];
}

- (void)fullyCompleteSession:(BOOL)didTimeout
{	
	[self pauseRecording];
	
	if (!preCache) {
        NSString *cacheString = (currentSubRun == 1 ? @"Cached_" : @"");
        NSString *identifier = [NSString stringWithFormat:@"%d_%@screen.jpg", currentRun, cacheString, nil];
        [self captureScreen:identifier important:YES];
        //int length = [[webView stringByEvaluatingJavaScriptFromString:@"document.body.innerHTML.length"] integerValue];
        //[result setContentLength:length];

        //Clear the web view (hacky, yet necessary)
        [webView stringByEvaluatingJavaScriptFromString:@"document.body.innerHTML = \"\";"];
	
		//Now clear the old session
		[result cleanupSession];
	}
	
    //For now we upload after every run, but we could upload less often
    BOOL shouldUploadNow = YES;

    BOOL isDone = (currentRun >= job.runs && (currentSubRun == 1 || job.fvOnly));
    if (!shouldUploadNow && !isDone) {
		[self startSession];
	}
    else
    {
        //Create the JSON data in a different thread, since it may take a while (it may have sync requests in it)
        __block NSData *data = nil;
        dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            data = [result jsonDataFromResult];
        });
        //Now write the data to disk
        NSString *harName = [NSString stringWithFormat:@"%d_%@result.har", currentRun,
                             (currentSubRun == 1 ? @"Cached_" : @"")];
        [data writeToFile:[resultFolder stringByAppendingPathComponent:harName] atomically:YES];
        data = nil;
        
        //Upload this result
        result.done = isDone;
#if BZ_DEBUG_PRINT_HAR
        NSLog(@"%@ completed: %@\n\n=====RESULT=====\n%@\n\n====RESULT END====\n", (result.done ? "Job" : "Run"), job, result);
#endif
        NSString *activeURL = (delegate ? [delegate getActiveUrl] : nil);
        [[BZJobManager sharedInstance] publishResult:result url:activeURL];
        //Our resultUploaded will call startSession or jobCompleted
    }
}

- (void)fullyCompleteSession
{
	[self fullyCompleteSession:NO];
}

- (void)possiblyFullyCompleteSession
{
    // Check if how long we've waited since we started post load recording. 
    NSTimeInterval curTime = [[NSDate date] timeIntervalSince1970];
    int gap = curTime - startPostLoadRecording;

    // If we still have active requests, wait some more, until we pass the timeout.
    // In theory the timeout might be double the provided value.
    int activeRequests = [webView getActiveRequests];
    if (activeRequests > 0 && gap < timeout) {
        
#if BZ_DEBUG_REQUESTS
        NSLog(@"Waiting 2 more seconds for fully complete");
#endif
        // Wait 2 more secs
        [self performSelector:@selector(possiblyFullyCompleteSession) withObject:nil afterDelay:2.0f];
    }
    else 
    {
        [self fullyCompleteSession];
    }
}

//Invoked after the site has actually stopped loading.
- (void)markSessionAsComplete
{
	[self stopTimeoutTimer];
	
	if (!preCache) {
		//Mark the session as done, but do not clean up yet, keep recording
		[result endSession];
	}
}

- (void)clearCache
{	
	NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
	for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
		[cookieStorage deleteCookie:cookie];
	}
	
#if BZ_DEBUG_JOB
	NSLog(@"About to clear the NSURLCache: MEM USAGE: %d DISK USAGE: %d", [[NSURLCache sharedURLCache] currentMemoryUsage], [[NSURLCache sharedURLCache] currentDiskUsage]);
#endif
	[[NSURLCache sharedURLCache] removeAllCachedResponses];
	NSString *path = [[NSURLCache sharedURLCache] _diskCacheDefaultPath];
	if (path) {
		[[NSURLCache sharedURLCache] performSelector:@selector(_diskCacheClear)];
	}
#if BZ_DEBUG_JOB
	NSLog(@"Cleared the NSURLCache: MEM USAGE: %d DISK USAGE: %d", [[NSURLCache sharedURLCache] currentMemoryUsage], [[NSURLCache sharedURLCache] currentDiskUsage]);
#endif
	//Ignore this warning.  This clears the internal WebCache.
	[objc_getClass("WebCache") empty];
	[objc_getClass("WebCache") emptyInMemoryResources];
	[objc_getClass("WebCoreStatistics") emptyCache];
	[objc_getClass("WebCoreStatistics") purgeInactiveFontData];
	[objc_getClass("WebCoreStatistics") returnFreeMemoryToSystem];
	[objc_getClass("WebCoreStatistics") garbageCollectJavaScriptObjects];
	
	if ([[UIDevice currentDevice].systemVersion compare:@"4.2.1" options:NSNumericSearch] != NSOrderedAscending) {
		//Only try this on 4.2.1
		[objc_getClass("WebCache") clearCachedCredentials];
		[objc_getClass("WebApplicationCache") deleteAllApplicationCaches];
		[objc_getClass("WebHistory") _removeAllVisitedLinks];
		id history = [objc_getClass("WebHistory") optionalSharedHistory];
		if (history) {
			[history removeAllItems];
		}
	}

    NSString *libraryFolder = [cachesFolder stringByAppendingPathComponent:@"WebKit"];
	NSError *error = nil;
	[[NSFileManager defaultManager] removeItemAtPath:libraryFolder error:&error];
	if (!error) {
		[[NSFileManager defaultManager] createDirectoryAtPath:libraryFolder withIntermediateDirectories:YES attributes:nil error:&error];
		if (error) {
			NSLog(@"%@", error);
		}
	}
	
	NSString *cookiesFolder = [cachesFolder stringByAppendingPathComponent:@"Cookies"];
	error = nil;
	[[NSFileManager defaultManager] removeItemAtPath:cookiesFolder error:&error];
	if (!error) {
		[[NSFileManager defaultManager] createDirectoryAtPath:cookiesFolder withIntermediateDirectories:YES attributes:nil error:&error];
		if (error) {
			NSLog(@"%@", error);
		}
	}
    
	NSString *browserCacheFolder = [cachesFolder stringByAppendingPathComponent:@"com.akamai.mobitest.agent"];
	error = nil;
	[[NSFileManager defaultManager] removeItemAtPath:browserCacheFolder error:&error];
	if (!error) {
		[[NSFileManager defaultManager] createDirectoryAtPath:browserCacheFolder withIntermediateDirectories:YES attributes:nil error:&error];
		if (error) {
			NSLog(@"%@", error);
		}
	}
    
    error = nil;
    NSArray *cacheDirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:cachesFolder error:&error];
    if (error) {
        NSLog(@"%@", error);
    }
    for (NSString* cacheFile in cacheDirContents) {
        NSString * ext = [cacheFile pathExtension];
        if ([ext compare:@"localstorage"]==0)
        {
            error = nil;
            NSString *fullCacheFile = [cachesFolder stringByAppendingPathComponent:cacheFile];
            [[NSFileManager defaultManager] removeItemAtPath:fullCacheFile error:&error];
            if (error) {
                NSLog(@"%@", error);
            }
        }
    }
}

#pragma mark -
#pragma mark Managing Timeouts

- (void)startTimeoutTimer
{
	if (timeoutTimer) {
		[self stopTimeoutTimer];
	}
	
	if (timeout > 0) {
		timeoutTimer = [[NSTimer scheduledTimerWithTimeInterval:timeout target:self selector:@selector(timedOut) userInfo:nil repeats:NO] retain];
	}
}

- (void)timedOut
{
	//Clean up the timer
	[self stopTimeoutTimer];
	
#if BZ_DEBUG_JOB
	NSLog(@"**** TIMEOUT -- Stopping");
#endif
	
	//Now force the stop
	completing = YES;
	if (!preCache) {
		[self markSessionAsComplete];
	}
	[self fullyCompleteSession:YES];
}

- (void)stopTimeoutTimer
{
	[timeoutTimer invalidate];
	[timeoutTimer release];
	timeoutTimer = nil;
}

#pragma mark - 
#pragma mark Screenshotting

- (void)startRecording
{
	if (job.captureVideo) {
		if (recordingTimer) {
			[recordingTimer invalidate];
			[recordingTimer release];
			recordingTimer = nil;

			[recordingTimerStarted release];
			recordingTimerStarted = nil;
		}
        
        // Call the first capture screen, to get the blank screen
        [self performSelector:@selector(captureScreen) withObject:Nil afterDelay:0.1f];

		CGFloat secondsPerFrame = 1.0f / [[[NSUserDefaults standardUserDefaults] objectForKey:kBZFPSSettingsKey] floatValue];

		// Remember when we start the timer, so that we can compute the timestamp on
		// each video frame.
		recordingTimerStarted = [[NSDate alloc] init];
		recordingTimer = [[NSTimer scheduledTimerWithTimeInterval:secondsPerFrame
		                                                   target:self
		                                                 selector:@selector(captureScreen)
		                                                 userInfo:nil
		                                                  repeats:YES] retain];
	}
}

- (void)captureScreen:(NSString*)identifier important:(BOOL)important
{    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    UIImage *image = Nil;
    // Physical device supports UIGetScreenImage, which seems better
	CGImageRef screen = UIGetScreenImage();
    if (screen) {
        image = [UIImage imageWithCGImage:screen];
    } 
    else 
    {
        // Simulator doesn't support UIGetScreenImage, using something else
        UIGraphicsBeginImageContext(webView.frame.size);
        [self.view.layer renderInContext:UIGraphicsGetCurrentContext()];
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();        
    }

	if (image) {
		//TODO: Expose PNG setting using 'UIImagePNGRepresentation(image);'
		NSData *imageData = UIImageJPEGRepresentation(image, 1.0);
		
		//TODO: We currently write to disk constantly, we should probably cache some of these and do batches if possible.
        NSString *path = [resultFolder stringByAppendingPathComponent:result.currentRun.videoFolder];
        if (important) {
            path = [path stringByDeletingLastPathComponent];
        }

		NSString *filePath = [path stringByAppendingPathComponent:identifier];
		if ([imageData writeToFile:filePath atomically:NO]) {
			if (important) {
				[result addImportantScreenshot:filePath];
			}
			else {
				[result addScreenshot:filePath];
			}
		}
		else {
			//Failed to save image!
#if BZ_DEBUG_JOB
			NSLog(@"Failed to record image at: %@", filePath);
#endif
		}
		
        if (screen) {
            //Ignore incorrect decrement notice
            CGImageRelease(screen);
        }
	}
    [pool drain];
	
}

- (void)captureScreen
{
    // How long has it been since we started recording?  NSTimeInterval is
    // a floating point value, so fractional parts of seconds are supported.
    NSTimeInterval timeSinceStartInSeconds = -[recordingTimerStarted timeIntervalSinceNow];

    // The WebPageTest server expects the file name to include the time as the
    // integer number of tenths of seconds.
    int tenthsOfSecondsSinceStart = (int)(timeSinceStartInSeconds * 10.0);
    NSString *cacheString = (currentSubRun == 1 ? @"Cached_" : @"");

    NSString *identifier =  [NSString stringWithFormat:@"%d_%@progress_%04d.jpg",
                                 currentRun, cacheString, tenthsOfSecondsSinceStart, nil];

	[self captureScreen:identifier important:NO];
}

- (void)pauseRecording
{
	if (job.captureVideo) {
		[recordingTimer invalidate];
		[recordingTimer release];
		recordingTimer = nil;

		[recordingTimerStarted release];
		recordingTimerStarted = nil;
	}
}

#pragma mark -
#pragma mark Notifications

- (void)didReceiveData:(NSNotification*)notification
{
	if (!preCache) {
		NSDictionary *userInfo = [notification userInfo];
		if (userInfo) {
			NSURLRequest *req = [userInfo objectForKey:BZDataReceivedReq];
			NSNumber *dataLength = [userInfo objectForKey:BZDataReceivedDataLength];
            NSURL *url = req?[req URL]:nil;
            NSString *path = url?[url absoluteString]:@"";
            NSNumber *hash = [result getRequestHash:req];
			//This is the GZIPPED values.  We can't rely on this
			
			if (hash && dataLength) {
                //#if BZ_DEBUG_JOB
//				NSLog(@"URL: %@", url);
//				NSLog(@"Number: %@", dataLength);
                //#endif
				BZResource *resource = [[result currentRun] resourceForHash:hash forUrl:path];
				if (resource) {
					@synchronized (resource) {
						if (resource.responseContentSizeFromNetwork == -1) {
							resource.responseContentSizeFromNetwork = [dataLength longValue];
						}
						else {
							resource.responseContentSizeFromNetwork = [dataLength longValue] + resource.responseContentSizeFromNetwork;
						}
					}
				}
				else {
#if BZ_DEBUG_REQUESTS
					NSLog(@"Missed data: %@", path);
#endif
				}
			}
		}
	}
}

- (void)processWebResource:(ArchiveResource*)p
{
   //NSLog(@"Single resource %ld", (long)p);    
}

#if BZ_DEBUG_REQUESTS
id dummyDS;
- (void)getDataSourceHelper
{
    id arr = [dummyDS performSelector:@selector(subresources)];
    
    for (id res in arr) {
        Ivar privIVar = class_getInstanceVariable([res class], "_private");
        id privObj = object_getIvar(res, privIVar);
        Ivar coreItemIVar = class_getInstanceVariable([privObj class], "coreResource");
        struct ArchiveResource *p = (ArchiveResource *)object_getIvar(privObj, coreItemIVar);
        [self processWebResource:p];
    }

    NSLog(@"Got pass data source notification, resources %@", arr);    
}

- (void)getDataSource:(NSNotification*)notification
{
    NSDictionary *userInfo = [notification userInfo];
    if (userInfo) {
        id dataSource = [userInfo objectForKey:@"dataSource"];
        dummyDS = dataSource;
        [self performSelector:@selector(getDataSourceHelper) withObject:nil afterDelay:1.0f];
    }
}
#endif

- (void)getWebViewPrivate:(NSNotification*)notification
{
    NSDictionary *userInfo = [notification userInfo];
    if (userInfo) {
        webViewPrivate = [userInfo objectForKey:@"webViewPrivate"];
    }
}


- (void)responseReceived:(NSNotification*)notification
{
	if (!preCache) {
		NSDictionary *userInfo = [notification userInfo];
		if (userInfo) {
			NSURLResponse *response = [userInfo objectForKey:BZResponse];
			if (response) {
#if BZ_DEBUG_REQUESTS
                NSLog(@"Setting response for URL %@", [response URL]);
#endif
				[result setResponse:response forResourceByHash:nil url:[[response URL] absoluteString]];
			}
			else {
				NSLog(@"Missing response in notification: %@", notification);
			}
		}
	}
}

- (void)clearResultFolder
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:resultFolder]) {
    		NSError *error = nil;
    		[[NSFileManager defaultManager] removeItemAtPath:resultFolder error:&error];
    		if (error) {
    			NSLog(@"%@", error);
    		}
    	}
    }

- (void)resultUploaded:(NSNotification*)notification
{
    [self clearResultFolder];
	[result removeAllSessions];

	BOOL isDone = (currentRun >= job.runs && (currentSubRun == 1 || job.fvOnly));
	if (isDone) {
		[self completeJob];
	}
	else {
		[self startSession];
	}
}

- (void)resultUploadFailed:(NSNotification*)notification
{
	if (delegate) {
		[delegate jobFailed:job];
	}
}


#pragma mark -
#pragma mark Important Page Load Milestones

- (void)startRenderHelper
{
	[self captureScreen:[NSString stringWithFormat:@"%d_%@screen_render.jpg", currentRun, currentSubRun == 1 ? @"Cached_" : @"", nil] important:YES];
}

- (void)startRender
{
#if BZ_DEBUG_JOB
	NSLog(@"Start rendering");
#endif
	if (!preCache) {
		//Wait 20ms.  We do this because of how UIWebViews actually render.  There is a lot of 'voodoo magic' here simply because it waits for when it can actually perform the rendering.
		//TODO: Look into ways to forcing javascript to call back to us whenever a render occurs
		[self performSelector:@selector(startRenderHelper) withObject:nil afterDelay:0.02];
	}
}

- (void)docComplete
{
	if (!preCache) {
		//Capture the docComplete screenshot
		[self captureScreen:[NSString stringWithFormat:@"%d_%@screen_doc.jpg", currentRun, currentSubRun == 1 ? @"Cached_" : @"", nil] important:YES];
	}
}


#pragma mark -
#pragma mark UIWebViewDelegate Methods

- (BOOL)webView:(UIWebView*)webView shouldStartLoadWithRequest:(NSURLRequest*)request navigationType:(UIWebViewNavigationType)navigationType
{    
	if (!preCache) {
		if (([[[request URL] absoluteString] rangeOfString:kBZLoadCallback]).location != NSNotFound) {
#if BZ_DEBUG_JOB
		NSLog(@"*************************************** LOAD!!!!!!!!");
#endif
			return NO;
		}
		if (job.ignoreSSL) {
			[NSURLRequest setAllowsAnyHTTPSCertificate:YES forHost:[[request URL] host]];
		}
	}
	
	return YES;
}

- (void)checkLoadingStatus
{
	if (!completing && !webView.loading && [webView isDone]) {
#if BZ_DEBUG_REQUESTS
        NSLog(@"checkLoadingStatus, inside if");    
#endif
#if BZ_DEBUG_JOB
		NSLog(@"[Controller] Marking session as complete");
#endif
		completing = YES;
		[self markSessionAsComplete];

        // Consider completing the session, immediately or later
        startPostLoadRecording = [[NSDate date] timeIntervalSince1970];
        [self performSelector:@selector(possiblyFullyCompleteSession) withObject:nil afterDelay:2.0f];

	}	
    else 
    {
#if BZ_DEBUG_REQUESTS
        NSLog(@"checkLoadingStatus, outside if");    
#endif
    }
}

- (void)webViewDidStartLoad:(UIWebView*)webPageView
{
	//We don't actually use this to gauge timing.  The standard UIWebViewDelegate is very flaky.
	
#if BZ_DEBUG_JOB
	NSLog(@"[Controller] Did start load called");
#endif
}

- (void)webViewDidFinishLoad:(UIWebView*)webPageView
{
#if BZ_DEBUG_JOB
	NSLog(@"[Controller] Did finish load called");
#endif
	
	//Verify loading status.  We will do this in vairous places to ensure that in at least *one* of the cases we're done.
	[self checkLoadingStatus];
}

- (void)webViewCompletelyFinishedLoading:(BZWebView*)view
{
	//Verify loading status.  We will do this in vairous places to ensure that in at least *one* of the cases we're done.
	[self checkLoadingStatus];
}

- (void)webView:(UIWebView*)webPageView didFailLoadWithError:(NSError*)error
{
#if BZ_DEBUG_JOB
	NSLog(@"Failure: %@", error);
#endif
	if (!preCache) {
		[result handleError:error];
	}
	
	//Verify loading status.  We will do this in vairous places to ensure that in at least *one* of the cases we're done.
	[self checkLoadingStatus];
}

#pragma mark -
#pragma mark Button Presses

- (void)stopPolling:(id)sender
{
	if (delegate) {
		[delegate stopPollingRequested];
	}
}

@end
