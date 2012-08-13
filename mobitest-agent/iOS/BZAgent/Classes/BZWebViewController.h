//
//  BZWebViewController.h
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-17.
//

#import <Foundation/Foundation.h>

//Views
#import "BZWebView.h"

//Model
#import "BZJob.h"
#import "BZResult.h"

@class WebViewPrivate;

@protocol BZWebViewControllerDelegate <NSObject>
- (void)jobCompleted:(BZJob*)job withResult:(BZResult*)result;
- (void)jobInterrupted:(BZJob*)job;
- (void)stopPollingRequested;
@end

/**
 * Web view controller that collects screenshots and 
 * page load times.
 */
@interface BZWebViewController : UIViewController {
@private
	//Hooks
	id<BZWebViewControllerDelegate> delegate;
	
	//Model
	BZJob *job;
	BZResult *result;
	
	float timeout;
	int currentRun;
	int currentSubRun;
	BOOL completing;
	BOOL preCache;
    NSTimeInterval startPostLoadRecording;
	
	//View
	BZWebView *webView;
	UIButton *stopPollingButton;
	
	NSTimer *timeoutTimer;

	NSDate *recordingTimerStarted;
	NSTimer *recordingTimer;
	
	NSString *cacheFolder;
    
    NSString *userAgent;
    
    // The WebViewPrivate object captured during init
    WebViewPrivate *webViewPrivate;
}

- (id)initWithJob:(BZJob*)job timeout:(float)timeout;

@property (nonatomic, assign) id<BZWebViewControllerDelegate> delegate;
@property (nonatomic, readonly) UIButton *stopPollingButton;

@end
