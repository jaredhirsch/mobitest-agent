//
//  BZWebView.h
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-17.
//  Copyright 2010 Blaze. All rights reserved.
//

#import <Foundation/Foundation.h>

//Model (Added in here for convenience/performance)
#import "BZResult.h"

//#include "InspectorController.h"
//#include "BZInspectorClient.h"

@class BZWebView;

@protocol BZWebViewDelegate <NSObject>

- (void)webViewCompletelyFinishedLoading:(BZWebView*)webView;
- (void)startRender;
- (void)docComplete;

@end


/**
 * Web view subclass used to expose page load times
 */
@interface BZWebView : UIWebView {
@private
	BOOL hasStarted;
	BOOL hasRendered;
	BOOL gotDocComplete;
	BOOL hasCleared;
	BOOL isComplete;
	BOOL hasAddedCallback;
	
	BOOL cachedRun;
	
	BOOL releasing;
	
	NSTimer *timer;
	
	//The result to populate.
	BZResult *result;
	
	id <BZWebViewDelegate> webViewDelegate;
	
	int frameLoadingCount;
	int activeRequests;
	int webViewLoads;
	
	NSMutableSet *loadingSet;
    
	
//	WebCore::InspectorController *controller;
//	WebCore::BZInspectorClient *client;
}

@property (nonatomic, assign) id<BZWebViewDelegate> webViewDelegate;
@property (nonatomic, retain) BZResult *result;

- (BOOL)isDone;
- (void)reset;
- (void)safeRelease;
- (int)getActiveRequests;
- (void)checkAndMarkCompletion;

@end
