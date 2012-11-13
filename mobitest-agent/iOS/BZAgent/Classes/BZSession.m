//
//  BZSession.m
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-26.
//

#import "BZSession.h"

@interface BZSession ()
@property (retain) NSDate *startLoadTime;
@property (retain) NSDate *stopLoadTime;
@property (retain) NSDate *startRenderTime;
@property (retain) NSDate *startTime;
@property (retain) NSDate *endTime;
@end

@implementation BZSession

@synthesize startLoadTime;
@synthesize stopLoadTime;
@synthesize startRenderTime;
@synthesize startTime;
@synthesize endTime;

@synthesize title;
@synthesize identifier;
@synthesize orderedResources;
@synthesize screenshotPaths;
@synthesize importantScreenshotPaths;
@synthesize videoFolder;

- (id)init
{
	self = [super init];
	if (self) {
		resources = [[NSMutableDictionary alloc] init];
		resourcesByUrl = [[NSMutableDictionary alloc] init];
		resourcesByHash = [[NSMutableDictionary alloc] init];
		orderedResources = [[NSMutableArray alloc] init];
		screenshotPaths = [[NSMutableArray alloc] initWithCapacity:128];
		importantScreenshotPaths = [[NSMutableArray alloc] initWithCapacity:4];
        
        startTime = NULL;
        startLoadTime = NULL;
        startRenderTime = NULL;
	}
	return self;
}

- (void)dealloc
{
	[title release];
	[identifier release];
	[resourcesByUrl release];
	[resourcesByHash release];
	[resources release];
	[orderedResources release];
	[screenshotPaths release];
	[importantScreenshotPaths release];
	[startRenderTime release];
	[startTime release];
	[endTime release];
	[videoFolder release];

	[super dealloc];
}

- (NSArray*)resources
{
	return orderedResources;
}

#pragma mark -
#pragma mark Session Management

- (void)setContentLength:(int)length
{
	if ([orderedResources count] > 0) {
		((BZResource*)[orderedResources objectAtIndex:0]).responseContentSize = length;
	}
}

- (void)start
{
    if (self.startTime == NULL) {
        self.startTime = [NSDate date];
    }
}

- (void)end
{
	self.endTime = [NSDate date];
}

- (void)startLoading
{
    if (self.startLoadTime == NULL) {
        self.startLoadTime = [NSDate date];
    }
}

- (void)render
{
    self.startRenderTime = [NSDate date];
}

- (void)stopLoading
{
	self.stopLoadTime = [NSDate date];
}

- (BZResource*)resourceForIdentifier:(NSObject*)object
{
	return [resources objectForKey:object];
}

- (BZResource*)resourceForHash:(NSNumber*)hash forUrl:(NSString*)url
{
    BZResource *res = [resourcesByHash objectForKey:hash];
    if (!res) {
        res = [resourcesByUrl objectForKey:url];
    }
    return res;
}

- (void)setResource:(BZResource*)resource forHash:(NSNumber*)hash forUrl:(NSString*)url
{
    if (url) {
        [resourcesByUrl setObject:resource forKey:url];
    }
    if (hash) {
        [resourcesByHash setObject:resource forKey:hash];        
    }
}

- (void)removeResourceForIdentifier:(NSObject*)object
{
	[resources removeObjectForKey:object];
}

- (void)setResource:(BZResource*)resource forIdentifier:(NSObject*)object
{
	if (![resources objectForKey:object]) {
		[orderedResources addObject:resource];
		resource.identifier = object;
		[resources setObject:resource forKey:object];
	}
	else {
		NSLog(@"%@ - Already contained", resource);
	}
}

- (void)addScreenshot:(NSString*)filePath
{
	[screenshotPaths addObject:filePath];
}

- (void)addImportantScreenshot:(NSString*)filePath
{
	[importantScreenshotPaths addObject:filePath];
}

@end
