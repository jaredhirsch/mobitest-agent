//
//  BZSession.h
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-26.
//

#import <Foundation/Foundation.h>

//Model
#import "BZResource.h"

@class BZResource;

//
//A BZSession wraps many BZResources and keeps track of the session's start and end time.
//
@interface BZSession : NSObject {
@private
	NSString *title;
	NSString *identifier;
	NSString *videoFolder;
	
	NSMutableDictionary *resources;
	NSMutableDictionary *resourcesByUrl;
	NSMutableDictionary *resourcesByHash;
	NSMutableArray *orderedResources;
	NSDate *startTime;
	NSDate *endTime;
	NSDate *startLoadTime;
	NSDate *stopLoadTime;
	
	NSDate *startRenderTime;
	
	NSMutableArray *screenshotPaths;
	NSMutableArray *importantScreenshotPaths;
	
	BOOL timedOut;
}

@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *identifier;
@property (nonatomic, retain) NSString *videoFolder;
@property (nonatomic, readonly) NSArray *resources;
@property (nonatomic, readonly) NSArray *orderedResources;
@property (nonatomic, readonly) NSArray *screenshotPaths;
@property (nonatomic, readonly) NSArray *importantScreenshotPaths;

- (void)start;
- (void)end;
- (void)endAndMarkAsTimedOut;

- (void)startLoading;
- (void)render;
- (void)stopLoading;

- (void)setContentLength:(int)length;

- (BZResource*)resourceForHash:(NSNumber*)hash forUrl:(NSString*)url;
- (BZResource*)resourceForIdentifier:(NSObject*)object;
- (void)removeResourceForIdentifier:(NSObject*)identifier;
- (void)setResource:(BZResource*)resource forIdentifier:(NSObject*)object;
- (void)setResource:(BZResource*)resource forHash:(NSNumber*)hash forUrl:(NSString*)url;
- (void)addScreenshot:(NSString*)filePath;
- (void)addImportantScreenshot:(NSString*)filePath;

@end
