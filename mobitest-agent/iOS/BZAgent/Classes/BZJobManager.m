//
//  BZJobManager.m
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-17.
//

#import "BZJobManager.h"

//Constants
#import "BZConstants.h"

//Model
#import "BZModel+JSON.h"

//Additions
#import "BZModel+ZIP.h"

static BZJobManager *sharedInstance;

@interface BZJobManager ()
@property (nonatomic, retain) BZHTTPURLConnection *activeRequest;
@property (nonatomic, retain) BZHTTPURLConnection *activeUploadHarRequest;
// The last time we got a valid response from the server for polling
@property (nonatomic, readonly) NSInteger lastValidResponseTime;
@end

@implementation BZJobManager

@synthesize activeRequest;
@synthesize activeUploadHarRequest;
@synthesize lastValidResponseTime;

+ (void)initialize
{
	//Note that this is a "Good Enough" singleton.  This does not guard against
	//someone deciding to release this singleton, for whatever reason.
	if (self == [BZJobManager class]) {
		sharedInstance = [[BZJobManager alloc] init];
	}
}

- (id)init
{
	self = [super init];
	if (self) {
		currentJobs = [[NSMutableArray alloc] initWithCapacity:4];
        lastValidResponseTime = [NSDate timeIntervalSinceReferenceDate];
	}
	return self;
}

+ (BZJobManager*)sharedInstance
{
	return sharedInstance;
}

- (void)dealloc
{
	[activeRequest release];
	[activeUploadHarRequest release];
	[currentJobs release];
	[super dealloc];
}

#pragma mark -
#pragma mark Properties

- (NSInteger)jobCount
{
	return [currentJobs count];
}

- (BOOL)hasJobs
{
	return [currentJobs count] > 0;
}
 
- (BOOL)pollForJobs:(NSString*)url fromAuto:(BOOL)fromAuto
{
    @synchronized(self) 
    {
        // If we had no valid responses in the last 10 minutes, restart
        int maxOfflineSecs = [[[NSUserDefaults standardUserDefaults] objectForKey:kBZMaxOfflineSecsSettingsKey] intValue];
        NSInteger curTime = [NSDate timeIntervalSinceReferenceDate];
        if (fromAuto && maxOfflineSecs > 0 && (curTime - lastValidResponseTime) > maxOfflineSecs) 
        {
            NSLog(@"Too long (%d seconds) since last valid response, restarting app",(curTime-lastValidResponseTime));
            if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"BlazeRecoverAgent://"]]) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"BlazeRecoverAgent://"]];
                kill(getpid(), 1);
            }

        }
        
        // If there's another request in the queue, do nothing
        if (activeRequest) {
            return false;
        }
        
        NSString *pattern;
        if ([url characterAtIndex:[url length] - 1] == '/') {
            pattern = @"work/getwork.php?recover=1&pc=%@&location=%@&key=%@";
        }
        else {
            pattern = @"/work/getwork.php?recover=1&pc=%@&location=%@&key=%@";
        }
        url = [url stringByAppendingFormat:pattern, 
               [[NSUserDefaults standardUserDefaults] objectForKey:kBZJobsAgentNameSettingsKey],
               [[NSUserDefaults standardUserDefaults] objectForKey:kBZJobsLocationSettingsKey],
               [[NSUserDefaults standardUserDefaults] objectForKey:kBZJobsLocationKeySettingsKey], nil];
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0f];
        self.activeRequest = [[[BZHTTPURLConnection alloc] initWithType:BZHTTPURLConnectionTypeGetWork request:request delegate:self]   autorelease];
        // If we failed to create a request, restart the app
        if (self.activeRequest == nil) {
            NSLog(@"Failed to set the activeRequest");
            return false;
        }
        return true;
    }
}

- (BZJob*)nextJob:(BOOL)shouldRemove
{
	BZJob *nextJob = nil;
	@synchronized (self) {
		if ([currentJobs count] > 0) {
			if (shouldRemove) {
				nextJob = [[[currentJobs objectAtIndex:0] retain] autorelease];
				[currentJobs removeObjectAtIndex:0];
			}
			else {
				nextJob = [currentJobs objectAtIndex:0];
			}
		}
	}
	return nextJob;
}

- (BZJob*)nextJob
{
	return [self nextJob:YES];
}

- (BZJob*)peekNextJob
{
	return [self nextJob:NO];
}

#pragma mark -
#pragma mark Parsing

- (BZJob*)jobFromData:(NSData*)data response:(NSHTTPURLResponse*)response
{
	//The job format is actually nothing but a simple 'text file' where each line is Key = Value and the first line is the URL
	NSString *jobData = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];

#if BZ_DEBUG_REQUESTS
	NSLog(@"**** JOB DATA ****\n%@", jobData);
#endif
	
	return [BZJob jobFromString:jobData];
}

- (NSURLRequest*)requestWithUrl:(NSString*)url data:(NSData*)data boundary:(NSString*)boundary formName:(NSString*)formName zipName:(NSString*)zipName
{
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
	[request setHTTPMethod:@"POST"];
	[request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField:@"Content-Type"];
	
	NSMutableData *postData = [NSMutableData dataWithCapacity:[data length] + 128];
	[postData appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"file\"; filename=\"%@\"\r\nContent-Type: application/zip\r\n\r\n", zipName] dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:data];
	[postData appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
	
	[request setHTTPBody:postData];
	
	return request;
}


- (void)postZip:(BZResult*)result url:(NSString*)url
{	
    @synchronized(self) {
        static NSString *kBZBoundary = @"f09wjf09jbananafoiasdfjasdf";
        
    #if BZ_DEBUG_REQUESTS
        NSLog(@"Posting zip");
    #endif
        
        NSData *zipData = [result zipResultData];
        if (zipData) {
            //Send off the video publish request
            self.activeUploadHarRequest = [[[BZHTTPURLConnection alloc] initWithType:BZHTTPURLConnectionTypePublishHarVideo request:[self requestWithUrl:url data:zipData boundary:kBZBoundary formName:@"result" zipName:[NSString stringWithFormat:@"%@-results.zip", result.jobId]] delegate:self] autorelease];
        }
        else {
            self.activeUploadHarRequest = nil;
        }
    }
}

- (void)publishResults:(BZResult*)result url:(NSString*)url
{
#if BZ_DEBUG_REQUESTS
	NSLog(@"Publishing result");
#endif
	//Create the JSON data in a different thread, since it may take a while (it may have sync requests in it)
    data = nil;
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        self->data = [result jsonDataFromResult];
    });
	NSString *cachesFolder = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	//TODO: Clean this up a little, shouldn't have to do this here
	//Now write the data to disk
	[data writeToFile:[cachesFolder stringByAppendingPathComponent:@"results.har"] atomically:YES];
	data = nil;
    
	NSString *pattern;
	if ([url characterAtIndex:[url length] - 1] == '/') {
		pattern = @"work/workdone.php?har=1&done=1&location=%@&key=%@&id=%@&flattenZippedHar=1";
	}
	else {
		pattern = @"/work/workdone.php?har=1&done=1&location=%@&key=%@&id=%@&flattenZippedHar=1";
	}
	
	url = [url stringByAppendingFormat:pattern, [[NSUserDefaults standardUserDefaults] objectForKey:kBZJobsLocationSettingsKey], [[NSUserDefaults standardUserDefaults] objectForKey:kBZJobsLocationKeySettingsKey], result.jobId, nil];

    //Now work package the data
    [self postZip:result url:url];
}
#pragma mark -
#pragma mark Notification Posting

- (void)postError:(NSString*)type reason:(NSString*)reason
{
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:reason, kBZJobsErrorKey, nil];
	[[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:type object:self userInfo:userInfo]];	
}

- (void)postResultUploadComplete
{
	[[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:BZJobUploadedNotification object:self userInfo:nil]];
}

- (void)postFailedToGetJobs:(NSString*)reason
{
	[self postError:BZFailedToGetJobsNotification reason:reason];
}

- (void)postFailedToUpload:(NSString*)reason
{
	[self postError:BZFailedToUploadJobNotification reason:reason];
}

- (void)postNoJobs
{
	[[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:BZNoJobsNotification object:self userInfo:nil]];
}

#pragma mark -
#pragma mark NSURLConnectionDelegate Methods

- (void)connection:(BZHTTPURLConnection*)connection didReceiveResponse:(NSURLResponse*)response
{
    @synchronized(self) {
        [connection clearData];
	
        NSHTTPURLResponse *urlResponse = (NSHTTPURLResponse*)response;
        connection.response = urlResponse;
    }
}

- (void)connection:(BZHTTPURLConnection*)connection didReceiveData:(NSData*)data
{
    @synchronized(self) {
        [connection appendData:data];
    }
}

- (void)connectionDidFinishLoading:(BZHTTPURLConnection*)connection
{
    @synchronized(self) 
    {

        NSData *data = [NSData dataWithData:connection.receivedData];
        [connection clearData];
        
        NSInteger statusCode = [[connection response] statusCode];
        
        if (statusCode == 0) {
            //Timeout
#if BZ_DEBUG_REQUESTS
            NSLog(@"Request timed out Type: %d", connection.type);
#endif
            if (connection.type == BZHTTPURLConnectionTypeGetWork) {
                [self postError:BZFailedToGetJobsNotification reason:@"Could not poll: Timed out"];
                self.activeRequest = nil;
            }
            else if (connection.type == BZHTTPURLConnectionTypePublishHarVideo) {
                [self postError:BZFailedToUploadJobNotification reason:@"Could not publish: Timed out"];
            }
        }
        else if (statusCode == 200)
        {
            lastValidResponseTime = [NSDate timeIntervalSinceReferenceDate];
            if (connection.type == BZHTTPURLConnectionTypeGetWork) 
            {
                if ([data length] > 0) {
                    BZJob *job = [self jobFromData:data response:connection.response];
                    
                    if (job) {
                        [currentJobs addObject:job];
                        
                        //Post a notification that we received new jobs
                        [[NSNotificationCenter defaultCenter] postNotificationName:BZNewJobReceivedNotification object:self];
                    }
                    else {
                        [self postFailedToGetJobs:@"Invalid response received"];
                    }
                }
                else {
                    [self postNoJobs];
                }
                //Clear the connection, let it end peacefully
                self.activeRequest = nil;
            }
            else if (connection.type == BZHTTPURLConnectionTypePublishHarVideo) {
                self.activeUploadHarRequest = nil;
                [self postResultUploadComplete];
            }
        }
        else  
        {
            //This was an error
#if BZ_DEBUG_REQUESTS
            NSLog(@"Request failed with status code %d type: %d", statusCode, connection.type);
#endif
            BZHTTPURLConnectionType connectionType = connection.type;
            [connection cancel];
            
            if (connectionType == BZHTTPURLConnectionTypeGetWork) {
                self.activeRequest = nil;
                [self postFailedToGetJobs:[NSString stringWithFormat:@"Could not poll: [%d]", statusCode]];
            }
            else if (connectionType == BZHTTPURLConnectionTypePublishHarVideo) {
                self.activeUploadHarRequest = nil;
                [self postFailedToUpload:[NSString stringWithFormat:@"Could not publish har: [%d]", statusCode]];
            }
        }
    }
}

- (void)connection:(BZHTTPURLConnection*)connection didFailWithError:(NSError*)error
{
    @synchronized(self) {
#if BZ_DEBUG_REQUESTS
        NSLog(@"%@ failed with %@", connection, error);
#endif
        switch (connection.type) {
            case BZHTTPURLConnectionTypeGetWork:
                if ([error code] <= -998) {
                    [self postFailedToGetJobs:@"Bad URL or no internet connection"];
                }
                else {
                    [self postFailedToGetJobs:[error description]];
                }
                self.activeRequest = nil;
                break;
            case BZHTTPURLConnectionTypePublishHarVideo:
                [self postFailedToUpload:[error description]];
                // Try again            
                break;
            default:
                //Unknown error
                break;
        }
    }
}

@end
