//
//  BZWebView.m
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-17.
//  Copyright 2010 Blaze. All rights reserved.
//

#import "BZWebView.h"

//Constants
#import "BZConstants.h"

//Workarounds
#import "BZWebInspectorFrontend.h"
#import </usr/include/objc/objc-class.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CFNetwork/CFNetwork.h>
#import <CFNetwork/CFHTTPMessage.h>

#ifdef BZ_DEBUG_REQUESTS
#include "ArchiveResource.h"
#include "WebViewPrivate.h"

class InspectorTimelineAgent;
class ArchiveResource;
#endif

typedef struct _CFURLResponse* CFURLResponseRef;
typedef struct _CFURLRequest* CFURLRequestRef;

@class WebInspector;

//Huzzah for method swizzling
void Swizzle(Class c, SEL orig, SEL newSelector)
{
	Method origMethod = class_getInstanceMethod(c, orig);
	Method newMethod = class_getInstanceMethod(c, newSelector);
	if (class_addMethod(c, orig, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(c, newSelector, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
	}
    else {
		method_exchangeImplementations(origMethod, newMethod);
	}
}

//
//Expose all of the Private Headers.  This is more than what we need, but it gives you a very good idea of what UIWebViews are capable of.
//This is all from the UIWebViewWebViewDelegate class
//
//Warning: Some of these methods may change from version to version.  This was written with 4.2.x in mind and verified on 4.x+
//
@interface UIWebView (PrivateHeaders)
- (id)initWithUIWebView:(id)arg1;
- (id)webView:(id)arg1 createWebViewWithRequest:(id)arg2;
- (void)webView:(id)arg1 decidePolicyForNewWindowAction:(id)arg2 request:(id)arg3 newFrameName:(id)arg4 decisionListener:(id)arg5;
- (void)webView:(id)arg1 unableToImplementPolicyWithError:(id)arg2 frame:(id)arg3;
- (void)webView:(id)arg1 frame:(id)arg2 exceededDatabaseQuotaForSecurityOrigin:(id)arg3 database:(id)arg4;
- (void)webView:(id)arg1 didStartProvisionalLoadForFrame:(id)arg2;
- (void)webView:(id)arg1 didReceiveTitle:(id)arg2 forFrame:(id)arg3;
- (id)webView:(id)arg1 connectionPropertiesForResource:(id)arg2 dataSource:(id)arg3;
- (id)webView:(id)arg1 resource:(id)arg2 willSendRequest:(id)arg3 redirectResponse:(id)arg4 fromDataSource:(id)arg5;
- (void)webView:(id)arg1 didClearWindowObject:(id)arg2 forFrame:(id)arg3;
- (void)webView:(id)arg1 didReceiveServerRedirectForProvisionalLoadForFrame:(id)arg2;
- (void)webView:(id)arg1 didFailProvisionalLoadWithError:(id)arg2 forFrame:(id)arg3;
- (void)webView:(id)arg1 decidePolicyForMIMEType:(id)arg2 request:(id)arg3 frame:(id)arg4 decisionListener:(id)arg5;
- (void)webView:(id)arg1 didFirstLayoutInFrame:(id)arg2;
- (void)webViewClose:(id)arg1;
- (void)webView:(id)arg1 runJavaScriptAlertPanelWithMessage:(id)arg2 initiatedByFrame:(id)arg3;
- (BOOL)webView:(id)arg1 runJavaScriptConfirmPanelWithMessage:(id)arg2 initiatedByFrame:(id)arg3;
- (id)webView:(id)arg1 runJavaScriptTextInputPanelWithPrompt:(id)arg2 defaultText:(id)arg3 initiatedByFrame:(id)arg4;
- (void)webView:(id)arg1 decidePolicyForGeolocationRequestFromOrigin:(id)arg2 frame:(id)arg3 listener:(id)arg4;
- (id)webView:(id)arg1 identifierForInitialRequest:(id)arg2 fromDataSource:(id)arg3;
- (void)webView:(id)arg1 resource:(id)arg2 didFinishLoadingFromDataSource:(id)arg3;
- (void)webView:(id)arg1 resource:(id)arg2 didFailLoadingWithError:(id)arg3 fromDataSource:(id)arg4;
- (void)webView:(id)arg1 resource:(id)arg2 didReceiveAuthenticationChallenge:(id)arg3 fromDataSource:(id)arg4;
- (void)webView:(id)arg1 resource:(id)arg2 didCancelAuthenticationChallenge:(id)arg3 fromDataSource:(id)arg4;
- (void)_clearUIWebView;
- (void)webView:(id)arg1 didFinishLoadForFrame:(id)arg2;
- (void)webView:(id)arg1 didFailLoadWithError:(id)arg2 forFrame:(id)arg3;
- (void)webView:(id)arg1 didCommitLoadForFrame:(id)arg2;
- (void)webView:(id)arg1 decidePolicyForNavigationAction:(id)arg2 request:(id)arg3 frame:(id)arg4 decisionListener:(id)arg5;
@end

@implementation NSObject (Swizzle)

- (void)alternateReceivedData:(id)data withDataSource:(id)dataSource
{
	id request = [dataSource performSelector:@selector(initialRequest)];
	if (request && data) {
        NSURL *URL = [request URL];
        NSString *path = nil;
        if (URL) {
            path = [URL absoluteString];
        }
        NSDictionary *dictionary = [[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:[(NSData*)data length]], BZDataReceivedDataLength, request, BZDataReceivedReq, nil] retain];
        [[NSNotificationCenter defaultCenter] postNotificationName:BZDataReceivedNotification object:nil userInfo:dictionary];
    }
    
	[self alternateReceivedData:data withDataSource:dataSource];
}

- (void)alt_webDataSourceReceivedData:(id)arg
{    
    NSLog(@"In alt_webDataSourceReceivedData, %@", self);
    NSDictionary *dictionary = [[NSDictionary dictionaryWithObjectsAndKeys:self, @"dataSource", nil] retain];
    [[NSNotificationCenter defaultCenter] postNotificationName:BZPassDataSourceNotification object:nil userInfo:dictionary];
    
	[self alt_webDataSourceReceivedData:arg];    

}
- (void)alt_webDataSourceAddSubresource:(id)arg1
{
    NSLog(@"In alt_webDataSourceAddSubresource, %@", arg1);
    [self alt_webDataSourceAddSubresource:arg1];

}

- (id)alt_subresourceForURL:(id)arg1
{
#if BZ_DEBUG_REQUESTS
    NSLog(@"In subresourceForUrl, arg is %@", arg1);
#endif
	return [self alt_subresourceForURL:arg1];        
}

- (void)alt_drawRect:(CGRect)rect
{
	[self alt_drawRect:rect];
	[[NSNotificationCenter defaultCenter] postNotificationName:BZWebViewDrawRect
														object:self
													  userInfo:nil];
}

- (void)alt_drawRect:(CGRect)rect contentsOnly:(BOOL)contentsOnly
{
	[self alt_drawRect:rect contentsOnly:contentsOnly];
}


- (id)alt_initWithCoreResource:(ArchiveResource**) coreResPtrPtr
{
#if BZ_DEBUG_REQUESTS
    struct ArchiveResource *p = *coreResPtrPtr;
    NSString *url = CString_getData(p->resResp.m_url.m_string);
    NSLog(@"In init with core resource, %@", url);
#endif
	return [self alt_initWithCoreResource:coreResPtrPtr];
}

- (id)alt_webResourcePrivateInit
{
    NSLog(@"In WebResourcePrivate init");
	return [self alt_webResourcePrivateInit];
}
- (void)alt_didReceiveResponse:(id)webView resource:(id)res didReceiveResponse:(id)resp fromDataSource:(id)src
{
    NSLog(@"In DidReceiveResponse");
    [self alt_didReceiveResponse:webView resource:res didReceiveResponse:resp fromDataSource:src];    
}
-(id)alt_webResourceInit
{    
    NSLog(@"In WebResourceInit");
    return [self alt_webResourceInit];
}
- (id)alt_webResourceInitWithData:(id)arg1 URL:(id)arg2 response:(id)arg3
{
    NSLog(@"In WebResourceInitWithData");
    return [self alt_webResourceInitWithData:arg1 URL:arg2 response:arg3];
}

- (void)alt_nscfurlDidReceiveResponse:(id)arg1
{
    NSLog(@"In alt_nscfurlDidReceiveResponse");
    return [self alt_nscfurlDidReceiveResponse:arg1];
}


- (id)alt_WebViewPrivate_init
{
    NSDictionary *dictionary = [[NSDictionary dictionaryWithObjectsAndKeys:self, @"webViewPrivate", nil] retain];
    [[NSNotificationCenter defaultCenter] postNotificationName:BZPassWebViewPrivateNotification object:nil userInfo:dictionary];
    return [self alt_WebViewPrivate_init];
}

- (id)alt_initWithCFURLRequest:(CFURLRequestRef)req
{
	id ret = [self alt_initWithCFURLRequest:req];
    
#if BZ_DEBUG_REQUESTS
    NSLog(@"Created request for URL %@", [ret URL]);
#endif	
	return ret;
    
}

@end

@implementation NSHTTPURLResponse (Swizzle)

-(id)alt_initWithCFURLResponse:(CFURLResponseRef)response
{
	id ret = [self alt_initWithCFURLResponse:response];

#if BZ_DEBUG_REQUESTS
    NSLog(@"Created response for URL %@", [ret URL]);
#endif
	
	//We've now pulled a response for a particular request
	//...So let's publish it
	[[NSNotificationCenter defaultCenter] postNotificationName:BZResponseReceivedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:ret, BZResponse, nil]];
	
	return ret;
}

@end


@implementation BZWebView

@synthesize result;
@synthesize webViewDelegate;

+ (void)initialize
{
	if (self == [BZWebView class]) {
        

		//Swizzle away
		Swizzle(objc_getClass("WebHTMLRepresentation"), @selector(receivedData:withDataSource:), @selector(alternateReceivedData:withDataSource:));
		Swizzle(objc_getClass("NSHTTPURLResponse"), @selector(_initWithCFURLResponse:), @selector(alt_initWithCFURLResponse:));
		Swizzle(objc_getClass("WebHTMLView"), @selector(drawRect:), @selector(alt_drawRect:));
		Swizzle(objc_getClass("WebFrame"), @selector(_drawRect:contentsOnly:), @selector(alt_drawRect:contentsOnly:));        

#if BZ_DEBUG_REQUESTS        
        [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"WebKitDeveloperExtras"];
        [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"WebKitWebArchiveDebugModeEnabledPreferenceKey"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
		Swizzle(objc_getClass("NSURLRequest"), @selector(_initWithCFURLRequest:), @selector(alt_initWithCFURLRequest:));
		Swizzle(objc_getClass("WebResourcePrivate"), @selector(initWithCoreResource:), @selector(alt_initWithCoreResource:)); 
        Swizzle(objc_getClass("WebDataSource"), @selector(_receivedData:), @selector(alt_webDataSourceReceivedData:));
        //Swizzle(objc_getClass("WebDataSource"), @selector(addSubresource:), @selector(alt_webDataSourceAddSubresource:));
        //Swizzle(objc_getClass("WebDataSource"), @selector(subresourceForURL:), @selector(alt_subresourceForURL:));
        //Swizzle(objc_getClass("WebResource"), @selector(init), @selector(alt_webResourceInit));
        //Swizzle(objc_getClass("WebResource"), @selector(_initWithData:URL:response:), @selector(alt_webResourceInitWithData:URL:response:));
        //Swizzle(objc_getClass("_NSCFURLProtocolBridge"), @selector(didReceiveResponse:), @selector(alt_nscfurlDidReceiveResponse:));
        Swizzle(objc_getClass("WebViewPrivate"), @selector(init), @selector(alt_WebViewPrivate_init));

		//Swizzle(objc_getClass("WebDefaultResourceLoadDelegate"), @selector(webView:resource:didReceiveResponse:fromDataSource:), @selector(alt_didReceiveResponse:resource:didReceiveResponse:fromDataSource:)); 
        
		//Swizzle(objc_getClass("WebResourcePrivate"), @selector(init), @selector(alt_webResourcePrivateInit)); 
#endif
        

	}
}

- (id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
		loadingSet = [[NSMutableSet alloc] init];
		//client = new BZInspectorClient();
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(webViewDidDraw) name:BZWebViewDrawRect object:nil];
		
		self.scalesPageToFit = YES;
	}
	return self;
}

- (void)dealloc
{
	[loadingSet release];
	[result release];

//	if (controller) {
//		delete controller;
//	}
//	
//	if (client) {
//		delete client;
//	}
	[super dealloc];
}

- (void)safeRelease
{
	releasing = YES;
}
- (int)getActiveRequests
{
    return activeRequests;
}

#pragma mark -
#pragma mark Prevent Popups

- (void)webView:(id)webView runJavaScriptAlertPanelWithMessage:(id)message initiatedByFrame:(id)frame
{
#if BZ_DEBUG_REQUESTS
	NSLog(@"[Alert] %@", message);
#endif
}

- (BOOL)webView:(id)webView runJavaScriptConfirmPanelWithMessage:(id)confirm initiatedByFrame:(id)frame
{
#if BZ_DEBUG_REQUESTS
	NSLog(@"[Confirm] %@", confirm);
#endif
	return NO;
}

- (id)webView:(id)webView runJavaScriptTextInputPanelWithPrompt:(id)textinput defaultText:(id)defaultText initiatedByFrame:(id)frame
{
#if BZ_DEBUG_REQUESTS
	NSLog(@"[Input Prompt] %@ - %@", textinput, defaultText);
#endif
	return @"";
}

#pragma mark -
#pragma mark Tracking Requests

- (BOOL)checkCompletion
{
	BOOL complete = NO;
	if (!releasing) {
		@try {
            NSString *readyState = [self stringByEvaluatingJavaScriptFromString:@"document.readyState"]; 
			complete = [readyState isEqual:@"complete"];
#if BZ_DEBUG_REQUESTS
            NSLog(@"Evaluating completion, document.readyState is %@", readyState);
#endif
		}
		@catch (NSException *exception) {
			NSLog(@"Failed to evaluate javascript: document.readyState %@ %@", exception, [exception reason]);
		}
	}
	return complete;
}

- (NSNumber*)identifierForResource:(id)resource
{
	return [NSNumber numberWithUnsignedLong:(unsigned long)resource];
}

- (void)startRequest:(id)resource request:(id)httpRequest
{
	NSNumber *resourceId = [self identifierForResource:resource];
	if (!releasing) {
		if ([loadingSet containsObject:resourceId]) {
			//This request was already added.  This looks like a redirect.
			[result handleRedirectForResource:resource];
		}
		else {
			[loadingSet addObject:resourceId];
			++activeRequests;
			
			if (activeRequests == 1) {
				hasStarted = YES;
				[result startDownloading];
			}
		}
		
        //Intercept this 'willSendRequest' method and mark this as 'start load' for this particular resource
		if (result) {
			[result setRequest:(NSMutableURLRequest*)httpRequest forResource:resource];
			[result startRequestForResource:resource];
		}

#if BZ_DEBUG_REQUESTS
		NSLog(@"[Start Request Status] Active: %d Loading Frames: %d Completion: %d", activeRequests, frameLoadingCount, [self checkCompletion]);
#endif
	}
}

- (void)completeRequest:(id)resource response:(id)response
{
	NSNumber *resourceId = [self identifierForResource:resource];
	if (!releasing && [loadingSet containsObject:resourceId]) {
		[loadingSet removeObject:resourceId];
		
		--activeRequests;
#if BZ_DEBUG_REQUESTS
		NSLog(@"[Complete Status] Active: %d Loading Frames: %d Completion: %d", activeRequests, frameLoadingCount, [self checkCompletion]);
        NSLog(@"gotDocComplete: %@, checkCompletion %@", gotDocComplete?@"YES":@"NO", [self checkCompletion]?@"YES":@"NO");
#endif
		if (result) {
			[result completeRequestForResource:resource];
			[result setResponse:response forResource:resource];
		}

        [self checkAndMarkCompletion];
	}
	else {
		NSLog(@"Ignored response: %@ - %@", resource, [response URL]);
	}
}

- (void)checkAndMarkCompletion
{
    if (result && !gotDocComplete)
    {
        if ([self checkCompletion]) 
        {
            //NSLog(@"[Request] Request complete, setting hasRendered to false");
            hasRendered = YES; //Don't render anything after this
            gotDocComplete = YES;
            if (webViewDelegate) {
                [webViewDelegate docComplete];
            }
            [result completeDownloading];
        } 
        else if (activeRequests == 0)
        {
#if BZ_DEBUG_REQUESTS
            NSLog(@"No active requests and no doc complete, scheduling another check in 100ms");
#endif
            // If the doc is not complete, but there are no active requests, 
            // call this method again in a little while
            [self performSelector:@selector(checkAndMarkCompletion) withObject:Nil afterDelay:0.1f];
        }
#if BZ_DEBUG_REQUESTS
        else 
        {  
            NSLog(@"Not rescheduling another check since there are %d activeRequests still", activeRequests);
        }
#endif
    }
    
    if (webViewDelegate && [self isDone]) {
        [webViewDelegate webViewCompletelyFinishedLoading:self];
    }
}

- (void)completeFrameLoading:(id)frame
{
	--frameLoadingCount;
	if (!releasing && webViewDelegate && [self isDone]) {
		[webViewDelegate webViewCompletelyFinishedLoading:self];
	}
}

#pragma mark -
#pragma mark Calculating Load Times

- (BOOL)isDone
{
	//This check exists because some requests actually come in AFTER the UIWebViewDelegate says 'loading complete'
	return ![self isLoading] && activeRequests == 0 && frameLoadingCount == 0 && [self checkCompletion];
}

- (void)webViewDidDraw
{
	//We can calculate start render based on the draw rects from the WebView.
	if (!releasing && hasCleared && hasStarted) {
		++webViewLoads;
        //NSLog(@"[Request] Got Web View Load call number %d, result is %d, hasRendered %d", webViewLoads, result?1:0, hasRendered?1:0);
		
		if (result && !hasRendered /*&& webViewLoads >= 2*/) {
			hasRendered = YES;
            //NSLog(@"[Request] Got Web View 2 Load call number %d", webViewLoads);
			
			[result startRender];
			if (webViewDelegate) {
                //NSLog(@"[Request] Got Web View 3 Load call number %d", webViewLoads);
				[webViewDelegate startRender];
			}
		}
	}
}

- (void)webView:(id)webView resource:(id)resource didFinishLoadingFromDataSource:(id)dataSource
{
#if BZ_DEBUG_REQUESTS
	NSLog(@"[Request] Finished Loading: %@, %@", resource, dataSource);
#endif
	if (!releasing) {
		[super webView:webView resource:resource didFinishLoadingFromDataSource:dataSource];
	
		[self completeRequest:resource response:[dataSource performSelector:@selector(response)]];
	}
}

- (void)webView:(id)webView resource:(id)resource didFailLoadingWithError:(id)error fromDataSource:(id)dataSource
{
#if BZ_DEBUG_REQUESTS
	NSLog(@"[Request] Failed Loading: %@ - %@", resource, error);
#endif
	if (!releasing) {
		[super webView:webView resource:resource didFailLoadingWithError:error fromDataSource:dataSource];
	
		[self completeRequest:resource response:[dataSource performSelector:@selector(response)]];
	}
}

- (void)webView:(id)arg1 resource:(id)arg2 didReceiveAuthenticationChallenge:(id)arg3 fromDataSource:(id)arg4
{
    NSLog(@"In didReceiveAuthenticationChallenge");
    [super webView:arg1 resource:arg2 didReceiveAuthenticationChallenge:arg3 fromDataSource:arg4];    
}

- (void)webView:(id)arg1 resource:(id)arg2 didCancelAuthenticationChallenge:(id)arg3 fromDataSource:(id)arg4
{
    NSLog(@"In didCancelAuthenticationChallenge");
    [super webView:arg1 resource:arg2 didCancelAuthenticationChallenge:arg3 fromDataSource:arg4];    
    
}


- (void)webView:(id)webView didStartProvisionalLoadForFrame:(id)frame
{	
	++frameLoadingCount;
#if BZ_DEBUG_REQUESTS
	NSLog(@"[Frame] Starting, isMainFrame:%@, frame: %@", [frame isMainFrame]?@"YES":@"NO", frame);
#endif
	if (!releasing) {
        if ([frame isMainFrame]) {
            gotDocComplete = NO;
        }
		[super webView:webView didStartProvisionalLoadForFrame:frame];
	}
}

- (void)webView:(id)webView didClearWindowObject:(id)windowObject forFrame:(id)frame
{
#if BZ_DEBUG_REQUESTS
	NSLog(@"[WebView] Did Clear: %@", windowObject);
#endif
	if (!releasing) {
		[super webView:webView didClearWindowObject:windowObject forFrame:frame];
		hasCleared = YES;
	}
}

- (void)webView:(id)webView decidePolicyForMIMEType:(id)policy request:(id)req frame:(id)frame decisionListener:(id)listener
{
#if BZ_DEBUG_REQUESTS
    NSLog(@"In decidePolicyForMimeType %@", listener);
#endif
    [super webView:webView decidePolicyForMIMEType:policy request:req frame:frame decisionListener:listener];    
}


//- (void)webView:(id)webView unableToImplementPolicyWithError:(id)error frame:(id)frame
//{
//#if BZ_DEBUG_REQUESTS
//	NSLog(@"UNABLE %@ - %@", error, frame);
//#endif
//	[super webView:webView unableToImplementPolicyWithError:error frame:frame];
//}

- (void)webView:(id)webView didFailProvisionalLoadWithError:(id)error forFrame:(id)frame
{
#if BZ_DEBUG_REQUESTS
	NSLog(@"[Frame] Provisional Failure: %@", frame);
#endif
	if (!releasing) {
		[self completeFrameLoading:frame];
	
		[super webView:webView didFailProvisionalLoadWithError:error forFrame:frame];
	}
}
- (id)webView:(id)webView connectionPropertiesForResource:(id)resource dataSource:(id)source
{
#if BZ_DEBUG_REQUESTS
	NSLog(@"[Frame] Connection properties for resource: %@", resource);
#endif
    return [super webView:webView connectionPropertiesForResource:resource dataSource:source];    
}

-(void)printCoreReq:(struct _CFURLRequest *)cfReq nsReq:(NSURLRequestInternal*)reqInternal
{
    NSLog(@"reqInternal: 0x%08x", (unsigned int)cfReq);

}

-(void)printResReq:(struct ResourceRequest *)resReq 
{
    NSLog(@"resReq: 0x%08x", (unsigned int)resReq);
    
}

- (id)webView:(id)webView resource:(id)identifier willSendRequest:(id)httpRequest redirectResponse:(id)redirectResponse fromDataSource:(id)dataSource
{
#if BZ_DEBUG_REQUESTS
    struct ResourceRequest *pResReq = (struct ResourceRequest*)identifier;
    [self printResReq:pResReq];
	NSLog(@"[Request] Will send: %@", httpRequest);
    Ivar reqIntIvar = class_getInstanceVariable([httpRequest class], "_internal");
     id reqInternal = object_getIvar(httpRequest, reqIntIvar);
     Ivar cfReqIvar = class_getInstanceVariable([reqInternal class], "request");
     struct _CFURLRequest *cfReq = (struct _CFURLRequest *)object_getIvar(reqInternal, cfReqIvar);
     
     [self printCoreReq:cfReq nsReq:(NSURLRequestInternal*)reqInternal];
#endif
	if (!releasing) {
		[self startRequest:identifier request:httpRequest];
		return [super webView:webView resource:identifier willSendRequest:httpRequest redirectResponse:redirectResponse fromDataSource:dataSource];
	}
	return nil;
}

- (void)webView:(id)webView didFinishLoadForFrame:(id)webFrame
{
#if BZ_DEBUG_REQUESTS
	NSLog(@"[Frame] Success: %@", webFrame);
#endif
	if (!releasing) {
		[self completeFrameLoading:webFrame];
	
		[super webView:webView didFinishLoadForFrame:webFrame];
	}
}

- (void)webView:(id)webView didFailLoadWithError:(id)error forFrame:(id)frame
{
#if BZ_DEBUG_REQUESTS
	NSLog(@"[Frame] Failure: %@ - %@", frame, error);
#endif
	if (!releasing) {
		[self completeFrameLoading:frame];
	
		[super webView:webView didFailLoadWithError:error forFrame:frame];
	}
}

- (void)reset
{
	cachedRun = YES;
	hasStarted = NO;
	hasRendered = NO;
    gotDocComplete = NO;
	hasCleared = NO;
	webViewLoads = 0;
}


@end