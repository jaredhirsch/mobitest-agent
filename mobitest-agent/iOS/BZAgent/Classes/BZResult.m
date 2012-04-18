//
//  BZResult.m
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-17.
//  Copyright 2010 Blaze. All rights reserved.
//

#import "BZResult.h"

//Additions
#import "BZModel+JSON.h"

//Constants
#import "BZConstants.h"

@interface BZResult ()
@property (nonatomic, retain) BZSession *currentRun;
@end

@implementation BZResult

@synthesize currentRun;
@synthesize jobId;
@synthesize screenShotImageQuality;

- (id)init
{
	self = [super init];
	if (self) {
		runs = [[NSMutableArray alloc] initWithCapacity:4];
	}
	return self;
}

- (void)dealloc
{
	[jobId release];
	[runs release];
	[currentRun release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Session Management

- (void)startSession:(NSString*)title identifier:(NSString*)identifier videoFolder:(NSString*)folder
{
	if (currentRun) {
		NSLog(@"Programmer error -- session already started!");
	}
	else {
		self.currentRun = [[[BZSession alloc] init] autorelease];
		currentRun.title = title;
		currentRun.identifier = identifier;
		currentRun.videoFolder = folder;
		[runs addObject:currentRun];
		[currentRun start];
	}
}

- (void)cleanupSession
{
	//Use property, make sure we release
	self.currentRun = nil;
}

- (void)endSession
{
	if (currentRun) {
		[currentRun end];
	}
}

- (void)endSessionAsTimeout
{
	if (currentRun) {
		[currentRun endAndMarkAsTimedOut];
	}
	
	[self cleanupSession];
}

- (void)setContentLength:(int)length
{
	[currentRun setContentLength:length];
}

- (BZResource*)resourceForIdentifier:(NSObject*)identifier shouldCreate:(BOOL)createIfNil
{
	NSNumber *key = [NSNumber numberWithInt:(unsigned long)identifier];
	BZResource *resource = [currentRun resourceForIdentifier:key];
	if (createIfNil && resource == nil) {
		resource = [[[BZResource alloc] init] autorelease];
		resource.pageRef = currentRun;
		[currentRun setResource:resource forIdentifier:key];
	}
	return resource;
}

- (void)setResource:(BZResource*)resource forIdentifier:(NSObject*)object
{
	if (resource && object) {
		NSNumber *key = [NSNumber numberWithInt:(unsigned long)object];
#if BZ_DEBUG_REQUESTS
		NSLog(@"[Set Resource] Associating %@ with %@", resource, key);
#endif
		resource.pageRef = currentRun;
		[currentRun setResource:resource forIdentifier:key];
	}
}

//Used to track download times
- (void)startRequestForResource:(NSString*)identifier
{
	BZResource *resource = [self resourceForIdentifier:identifier shouldCreate:YES];
    if (resource) {
        // Don't reset an existing time, but log the fact we got two starts
        if (resource.startTime != 0) { 
            // TODO: Looks like the two start times are the "enqueue" time and the real start time, meaning blocking time. Should note it.
            //NSLog(@"Got two start times for resource %@", resource.requestURL);
        } else {
            resource.startTime = [NSDate date];
        }
    }
    else {
        NSLog(@"[Start Request] Unknown resource: %@", identifier);
    }
}

- (void)completeRequestForResource:(NSObject*)identifier
{
	BZResource *resource = [self resourceForIdentifier:identifier shouldCreate:NO];
	if (resource) {
        // Don't reset an existing time, but log the fact we got two starts
        if (resource.endTime != 0) { 
            // TOOD: Find out what the two end times mean - are these the indications the send completed?
            //NSLog(@"Got two end times for resource %@", resource.requestURL);
        } else {
            resource.endTime = [NSDate date];
        }
	}
	else {
		NSLog(@"[Complete Request] Unknown resource: %@", identifier);
    }
}

- (void)handleRedirectForResource:(NSObject*)identifier
{
	[currentRun removeResourceForIdentifier:[NSNumber numberWithInt:(unsigned long)identifier]];
}

- (NSNumber*)getRequestHash:(NSURLRequest*)request
{
    NSURL *url = request?[request URL]:nil;
    NSString *path = url?[url absoluteString]:@"";
    NSString *referrer = [request _web_HTTPReferrer];
    NSString *reqHashStr = [NSString stringWithFormat:@"%@,%@",path,referrer?referrer:@""];
    
    // TODO: We still somehow merge results by URL later on, need to figure out where.
    
    return [NSNumber numberWithInt:[reqHashStr hash]];
}
- (BZResource*)setRequest:(NSURLRequest*)request forResource:(NSObject*)identifier
{
    NSURL *url = [request URL];
    NSString *path = [url absoluteString];
    NSNumber *hash = [self getRequestHash:request];
    
	BZResource *resource = [self resourceForIdentifier:identifier shouldCreate:NO];
	if (!resource) {
		//Try by url
		resource = [currentRun resourceForHash:hash forUrl:Nil];
		if (!resource) {
			resource = [[[BZResource alloc] init] autorelease];
		}
		[self setResource:resource forIdentifier:identifier];
		[currentRun setResource:resource forHash:hash forUrl:path];
	}
	
	if (resource) {
		if (path) {
			resource.requestURL = path;
		}
		else {
			//We didn't have an absolute path... try relative
			path = [url path];
			if (!path) {
				path = @"/";
			}
			resource.requestURL = path;
		}
#if BZ_DEBUG_REQUESTS
		NSLog(@"<----- (Update)Received a request %@", path);
#endif
		NSCachedURLResponse *response = [[NSURLCache sharedURLCache] cachedResponseForRequest:request];
		if (response) {
			NSURLResponse *urlResponse = [response response];
			if ([urlResponse isKindOfClass:[NSHTTPURLResponse class]]) {
				NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)urlResponse;
				NSDictionary *headers = [httpResponse allHeaderFields];
				NSString *etag = [headers objectForKey:@"ETag"];
				//Looks like the cache messes with capitalization here
				etag = etag == nil ? [headers objectForKey:@"Etag"] : etag;
				resource.beforeRequestEtag = etag;
				
				NSString *expires = [headers objectForKey:@"Expires"];
				//Be safe here
				expires = expires == nil ? [headers objectForKey:@"expires"] : expires;
				resource.beforeRequestExpires = expires;
			}
		}
		
		[currentRun setResource:resource forHash:hash forUrl:[url absoluteString]];
		// TODO: Why is this here?
		/*NSString *referer = [[request allHTTPHeaderFields] objectForKey:@"Referer"];
        if (referer) {
			[currentRun setResource:resource forHash:nil forUrl:referer];
		}*/
		resource.requestHttpMethod = [request HTTPMethod];
		
		//Get cookies
		resource.requestCookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:url];
		
		//Get all headers
		NSMutableDictionary *headers = [[[NSMutableDictionary alloc] initWithDictionary:[request allHTTPHeaderFields]] autorelease];
		
		//WebKit does not allow you to specify Host, Connection and Content-Length.  So simply specify what we /expect/
		if ([url host]) {
			[headers setObject:[url host] forKey:@"Host"];
		}
		
		//This represents the content from a POST -- use it as the Content Length
		if ([request HTTPBody]) {
			resource.requestBodySize = [[request HTTPBody] length];
			//[headers setObject:[NSString stringWithFormat:@"%d", [[request HTTPBody] length]] forKey:@"Content-Length"];
		}
		
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		NSString *accept = [defaults stringForKey:kBZAcceptSettingsKey];
		accept = accept == nil ? @"" : accept;
		[headers setObject:accept forKey:@"Accept"];
		
		NSString *acceptEncoding = [defaults stringForKey:kBZAcceptEncodingSettingsKey];
		acceptEncoding = acceptEncoding == nil ? @"" : acceptEncoding;
		[headers setObject:acceptEncoding forKey:@"Accept-Encoding"];
		
		NSString *acceptLanguage = [defaults stringForKey:kBZAcceptLanguageSettingsKey];
        acceptLanguage = acceptLanguage == nil ? @"" : acceptLanguage;
		[headers setObject:acceptLanguage forKey:@"Accept-Language"];

		resource.requestHeadersDict = headers;
		
		//Get HTTP Version
		resource.requestHttpVersion = @"HTTP/1.1";
		
		//Get Query String (may be nil)
		resource.requestQueryString = [url query];
	}
	else {
		NSLog(@"[Set Request] Unknown resource: %@", identifier);
	}
	
	return resource;
}

- (void)updateResource:(BZResource*)resource withResponse:(NSURLResponse*)aResponse
{
	if (aResponse && [aResponse isKindOfClass:[NSHTTPURLResponse class]]) {
		NSHTTPURLResponse *response = (NSHTTPURLResponse*)aResponse;
		
		if ([[[response URL] absoluteString] isEqualToString:[resource requestURL]]) {
			//Get status code
			resource.responseStatusCode = [response statusCode];
			
			//Get status text
			//TODO: Figure out how to get this
			resource.responseStatusText = @"";
			
			//Get body size.  We approximate this by saying that it's content size + header size.  We'll calculate this later for now.
			resource.responseBodySize = -1;
			
			//Get all headers
			resource.responseHeadersDict = [response allHeaderFields];
			NSString *etag = [resource.responseHeadersDict objectForKey:@"ETag"];
			//Looks like the cache messes with capitalization here
			etag = etag == nil ? [resource.responseHeadersDict objectForKey:@"Etag"] : etag;
			resource.afterRequestEtag = etag;
			
			NSString *expires = [resource.responseHeadersDict objectForKey:@"Expires"];
			//Be safe here
			expires = expires == nil ? [resource.responseHeadersDict objectForKey:@"expires"] : expires;
			resource.afterRequestExpires = expires;
			
			//Get HTTP version
			//TODO: Figure out how to get the HTTPVersion from an NSURLRequest...
			resource.responseHttpVersion = @"HTTP/1.1";
			
			//Get redirect url
			//TODO: Figure out how to obtain this
			resource.responseRedirectUrl = @"";
			
			//Get content size
			resource.responseContentSize = [response expectedContentLength];
			
			//Get mimetype
			resource.responseMimeType = [response MIMEType];
			
			//Get cookies
			resource.responseCookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[response URL]]; 
		}
	}
	else {
		//We could not connect with the server
		resource.responseStatusCode = 0;
		resource.responseStatusText = @"Could not connect to the server.";
		resource.responseBodySize = -1;
		resource.responseHeadersDict = [NSMutableDictionary dictionary];
		resource.responseHttpVersion = @"";
		resource.responseRedirectUrl = @"";
		resource.responseContentSize = -1;
		resource.responseMimeType = @"";
		resource.responseCookies = [NSArray array];
	}
}

- (void)handleError:(NSError*)error
{
	NSDictionary *userInfo = [error userInfo];
	if (userInfo) {
		NSString *url = [userInfo objectForKey:NSErrorFailingURLStringKey];
		BZResource *resource = [currentRun resourceForHash:nil forUrl:url];
		if (resource) {
			NSInteger statusCode = 0;
			NSInteger errorCode = [error code];
			switch (errorCode) {
				case NSURLErrorBadURL:
					resource.comment = @"Bad URL";
					statusCode = 30; //Don't use 0 (0 is no error)
					break;
				case NSURLErrorCancelled: //Cancelled was "we cancelled it because of a timeout" in this particular case
				case NSURLErrorTimedOut:
					resource.comment = @"Timed out";
					statusCode = 1;
					break;
				case NSURLErrorUnsupportedURL:
					resource.comment = @"Unsupported URL";
					statusCode = 2;
					break;
				case NSURLErrorCannotFindHost:
					resource.comment = @"Cannot find host";
					statusCode = 3;
					break;
				case NSURLErrorCannotConnectToHost:
					resource.comment = @"Cannot connect to host";
					statusCode = 4;
					break;
				case NSURLErrorNetworkConnectionLost:
					resource.comment = @"Network connection lost";
					statusCode = 5;
					break;
				case NSURLErrorDNSLookupFailed:
					resource.comment = @"DNS Lookup failed";
					statusCode = 6;
					break;
				case NSURLErrorHTTPTooManyRedirects:
					resource.comment = @"Too many HTTP Redirects";
					statusCode = 7;
					break;
				case NSURLErrorResourceUnavailable:
					resource.comment = @"Resource unavailable";
					statusCode = 8;
					break;
				case NSURLErrorNotConnectedToInternet:
					resource.comment = @"Not connected to the internet";
					statusCode = 9;
					break;
				case NSURLErrorRedirectToNonExistentLocation:
					resource.comment = @"Non existent location";
					statusCode = 10;
					break;
				case NSURLErrorBadServerResponse:
					resource.comment = @"Bad server response";
					statusCode = 11;
					break;
				case NSURLErrorUserCancelledAuthentication:
					resource.comment = @"Cancelled authentication";
					statusCode = 12;
					break;
				case NSURLErrorUserAuthenticationRequired:
					resource.comment = @"Authentication required";
					statusCode = 13;
					break;
				case NSURLErrorZeroByteResource:
					resource.comment = @"Zero byte resource";
					statusCode = 14;
					break;
				case NSURLErrorCannotDecodeRawData:
					resource.comment = @"Cannot decode raw data";
					statusCode = 15;
					break;
				case NSURLErrorCannotDecodeContentData:
					resource.comment = @"Cannot decode content data";
					statusCode = 16;
					break;
				case NSURLErrorCannotParseResponse:
					resource.comment = @"Cannot parse response";
					statusCode = 17;
					break;
				case NSURLErrorFileDoesNotExist:
					resource.comment = @"File does not exist";
					statusCode = 18;
					break;
				case NSURLErrorFileIsDirectory:
					resource.comment = @"File is directory";
					statusCode = 19;
					break;
				case NSURLErrorNoPermissionsToReadFile:
					resource.comment = @"No permissions to read file";
					statusCode = 20;
					break;
				case NSURLErrorDataLengthExceedsMaximum:
					resource.comment = @"Data exceeds maximum length";
					statusCode = 21;
					break;
				case NSURLErrorSecureConnectionFailed:
					resource.comment = @"Secure connection failed";
					statusCode = 22;
					break;
				case NSURLErrorServerCertificateHasBadDate:
					resource.comment = @"SSL Certificate has bad date";
					statusCode = 23;
					break;
				case NSURLErrorServerCertificateUntrusted:
					resource.comment = @"SSL Certificate untrusted";
					statusCode = 24;
					break;
				case NSURLErrorServerCertificateHasUnknownRoot:
					resource.comment = @"SSL Certificate has unknown root";
					statusCode = 25;
					break;
				case NSURLErrorServerCertificateNotYetValid:
					resource.comment = @"SSL Certificate not yet valid";
					statusCode = 26;
					break;
				case NSURLErrorClientCertificateRejected:
					resource.comment = @"SSL Certificate rejected";
					statusCode = 27;
					break;
				case NSURLErrorClientCertificateRequired:
					resource.comment = @"SSL Certificate required";
					statusCode = 28;
					break;
				case NSURLErrorCannotLoadFromNetwork:
					resource.comment = @"Cannot load from network";
					statusCode = 29;
					break;
				case NSURLErrorUnknown:
				default:
					resource.comment = @"Unknown error occured";
					statusCode = -1;
					break;
			}
			
			resource.status = [NSNumber numberWithInt:statusCode];
#if BZ_DEBUG_REQUESTS
			NSLog(@"[Handled Error]: %@ %@ %d %@", url, resource, errorCode, resource.comment);
#endif
		}
		else {
			NSLog(@"[handleError] Handling an error for an unknown URL: %@", url);
		}
	}
}

- (void)setResponse:(NSURLResponse*)aResponse forResourceByHash:(NSNumber*)hash url:(NSString*)url
{
#if BZ_DEBUG_REQUESTS
	NSLog(@"---> Received a response for %@", url);
#endif
	BZResource *resource = [currentRun resourceForHash:hash forUrl:url];
    if (!resource) {
        resource = [[[BZResource alloc] init] autorelease];
        [currentRun setResource:resource forHash:hash forUrl:url];
    }

    [self updateResource:resource withResponse:aResponse];
	resource.endTime = [NSDate date];
}

- (void)setResponse:(NSURLResponse*)aResponse forResource:(NSObject*)identifier
{
	BZResource *resource = [self resourceForIdentifier:identifier shouldCreate:NO];
	if (resource) {
		[self updateResource:resource withResponse:aResponse];	
	}
	else {
		NSLog(@"[Set Response (forResource)] Unknown resource: %@", identifier);
	}
}

- (void)startDownloading
{
	[currentRun startLoading];
}

- (void)startRender
{
	[currentRun render];
}

- (void)completeDownloading
{
	[currentRun stopLoading];
}

- (void)addImportantScreenshot:(NSString*)filePath
{
	[currentRun addImportantScreenshot:filePath];
}

- (void)addScreenshot:(NSString*)filePath
{
	[currentRun addScreenshot:filePath];
}

#pragma mark -
#pragma mark Pretty Printing

- (NSString*)description
{
	return [self jsonStringFromResult];
}

@end
