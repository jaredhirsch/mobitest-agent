//
//  BZResult.h
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-17.
//  Copyright 2010 Blaze. All rights reserved.
//

#import <Foundation/Foundation.h>

//Model
#import "BZSession.h"

//
//A BZResult models an entire Job's results
//This will include 1-20 sessions.
//Each session will contain N resources
//
@interface BZResult : NSObject {
@private
	NSString *jobId;
	NSMutableArray *runs;
	
	// What image quality setting should be used to encode screenshots?
	float screenShotImageQuality;

	BZSession *currentRun;
}

@property (nonatomic, retain) NSString *jobId;
@property (nonatomic) float screenShotImageQuality;
@property (nonatomic, readonly, retain) BZSession *currentRun;

- (void)startSession:(NSString*)title identifier:(NSString*)identifier videoFolder:(NSString*)folder;

//Used to track download times
- (void)startRequestForResource:(NSString*)identifier;
- (void)completeRequestForResource:(NSObject*)identifier;

- (NSNumber*)getRequestHash:(NSURLRequest*)request;
- (BZResource*)resourceForHash:(NSNumber*)hash forUrl:(NSString*)url;

- (BZResource*)setRequest:(NSURLRequest*)request forResource:(NSObject*)identifier;
- (void)setResponse:(NSURLResponse*)aResponse forResourceByHash:(NSNumber*)hash url:(NSString*)url;
- (void)setResponse:(NSURLResponse*)response forResource:(NSObject*)identifier;
- (void)setContentLength:(int)length;
- (void)startDownloading;
- (void)startRender;
- (void)completeDownloading;
- (void)handleError:(NSError*)error;

- (void)handleRedirectForResource:(NSObject*)identifier;
- (void)addImportantScreenshot:(NSString*)filePath;
- (void)addScreenshot:(NSString*)filePath;

- (void)cleanupSession;
- (void)endSession;
- (void)endSessionAsTimeout;

@end
