//
//  BZModel+JSON.m
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-27.
//

#import "BZModel+JSON.h"

//Constants
#import "BZConstants.h"

//Extensions
#import "CJSONSerializer.h"
#import "NSDate+Formatting.h"
#import "NSData+Base64.h"

//Requests
#import "ASIHTTPRequest.h"

@interface NSMutableDictionary (Safety)
- (void)setObjectSafely:(NSObject*)valueOrNil forKey:(NSString*)key defaultValue:(NSObject*)defaultValue;
@end

@implementation NSMutableDictionary (Safety)

- (void)setObjectSafely:(NSObject*)valueOrNil forKey:(NSString*)key defaultValue:(NSObject*)defaultValue
{
	if (valueOrNil) {
		[self setObject:valueOrNil forKey:key];
	}
	else {
		[self setObject:defaultValue forKey:key];
	}
}

@end


@interface NSDate (RFC3339)
- (NSString*)formatDate;
@end

@implementation BZResult (JSONExtension)

- (NSMutableDictionary*)rootDictionary
{
	//Create the base with: Version of Har, Creator and Browser info.
	return [NSMutableDictionary dictionaryWithObjectsAndKeys:
														@"1.7", @"version",
			
														[NSDictionary dictionaryWithObjectsAndKeys:	@"Mobitest", @"name",
																									@"1.7", @"version", nil], @"creator",
			
														[NSDictionary dictionaryWithObjectsAndKeys: @"iOS - WebKit/Safari", @"name",
																									[[UIDevice currentDevice] systemVersion], @"version", nil], @"browser",
			
														nil];
}

- (NSDictionary*)dictionaryFromResult
{
	NSMutableDictionary *root = [self rootDictionary];
	
	NSMutableArray *pagesArray = [[[NSMutableArray alloc] init] autorelease];
	NSMutableArray *entriesArray = [[[NSMutableArray alloc] init] autorelease];
    NSMutableDictionary *urlToLen = [[[NSMutableDictionary alloc] init] autorelease]; 
	for (BZSession *session in runs) {
		[pagesArray addObject:[session dictionaryFromSession]];
		
		for (BZResource *resource in session.resources) {
			[entriesArray addObject:[resource dictionaryFromResource:urlToLen]];
		}
	}
	[root setObject:pagesArray forKey:@"pages"];
	[root setObject:entriesArray forKey:@"entries"];
	
	return [NSMutableDictionary dictionaryWithObjectsAndKeys:root, @"log", nil];
}

- (NSData*)jsonDataFromResult
{
	NSError *error = nil;
	NSData *json = [[CJSONSerializer serializer] serializeDictionary:[self dictionaryFromResult] error:&error];
	if (error) {
		json = nil;
	}
	return json;
}

- (NSString*)jsonStringFromResult
{
	return [[[NSString alloc] initWithData:[self jsonDataFromResult] encoding:NSUTF8StringEncoding] autorelease];
}

@end


@implementation BZSession (JSONExtension)

- (NSString*)base64Image:(NSString*)path
{
	NSData *data = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:path]];
	NSString *dataString = nil;
	//UIImage *image = [[UIImage alloc] initWithData:data];
	if (data) {
		dataString = [data base64EncodedString];
	}
	//[image release];
	return dataString;
}

- (NSDictionary*)dictionaryFromSession
{
	NSMutableDictionary *session = [[[NSMutableDictionary alloc] init] autorelease];
	
	//We only add information about this particular page load
	NSString *formattedDate = [startLoadTime formatDate];
	[session setObjectSafely:formattedDate forKey:@"startedDateTime" defaultValue:@""];
	[session setObjectSafely:title forKey:@"title" defaultValue:@""];
	[session setObjectSafely:identifier forKey:@"id" defaultValue:@""];
	NSNumber *contentLoadTime = [NSNumber numberWithInt:[stopLoadTime timeIntervalSinceDate:startTime] * 1000]; //timeInterval returns seconds
	NSNumber *startRender = [NSNumber numberWithInt:[startRenderTime timeIntervalSinceDate:startTime] * 1000]; //timeInterval returns seconds
	NSNumber *totalTime = [NSNumber numberWithInt:[endTime timeIntervalSinceDate:startTime] * 1000];
	
	//If contentLoadTime is larger than totalTime, use contentLoadTime for both values
	if ([totalTime intValue] < [contentLoadTime intValue]) {
		totalTime = [NSNumber numberWithInt:[contentLoadTime intValue]];
	}
	
	if (totalTime && contentLoadTime && startRender) {
		[session setObject:[NSDictionary dictionaryWithObjectsAndKeys:totalTime, @"onLoad", contentLoadTime, @"onContentLoad", startRender, @"_onRender", nil] forKey:@"pageTimings"];
	}
	
	return session;
}

@end

@implementation BZResource (JSONExtension)

- (NSArray*)arrayFromCookiesArray:(NSArray*)cookies
{
	NSMutableArray *cookiesArray = [[[NSMutableArray alloc] init] autorelease];
	for (NSHTTPCookie *cookie in cookies) {
		[cookiesArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:cookie.name, @"name", cookie.value, @"value", nil]];
	}
	return cookiesArray;
}

- (NSArray*)arrayFromHeaders:(NSDictionary*)headers
{
	NSMutableArray *headersArray = [[[NSMutableArray alloc] init] autorelease];
	for (NSString *key in headers) {
		[headersArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:[headers objectForKey:key], @"value", key, @"name", nil]];
	}
	return headersArray;
}

- (NSArray*)arrayFromQueryString:(NSString*)queryString
{
	NSMutableArray *queryStringArray = [[[NSMutableArray alloc] init] autorelease];
	NSArray *keyValuePairs = [queryString componentsSeparatedByString:@"&"];
	NSArray *split;
	for (NSString *keyValuePair in keyValuePairs) {
		split = [keyValuePair componentsSeparatedByString:@"="];
		if ([split count] == 2) {
			[queryStringArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:[split objectAtIndex:1], @"value", [split objectAtIndex:0], @"name", nil]];
		}
	}
	return queryStringArray;
}

- (NSInteger)lengthFromHeaders:(NSDictionary*)headers
{
	NSInteger totalLength = 0;
	if ([headers count] > 0) {
		for (NSString *key in [headers allKeys]) {
			totalLength += [key length]; //Key length
			totalLength += 4; //Add 2 for ': ' and the trailing slash N
			totalLength += [(NSString*)[headers objectForKey:key] length]; //Value length
		}
	}

	return totalLength + 2; //+2 for an additional slash N (the last header added 2 already)
}

- (NSInteger)lengthFromStatusLine:(int)code
{
	//TODO: Use raw data for this, not an approximation.  Only tackle the major ones for now
	NSInteger length = 13; //HTTP/x.x yyy <textInfo>
	NSInteger textInfo = 0;
	switch (code) {
		case 200:
			//OK
			textInfo = 2;
			break;
		case 201:
			//Created
			textInfo = 7;
			break;
		case 202:
			//Accepted
			textInfo = 8;
			break;
		case 204:
			//No Content
			textInfo = 10;
			break;
		case 205:
			//Reset Content
			textInfo = 13;
			break;
		//300s
		case 300:
			//Multiple Choices
			textInfo = 16;
			break;
		case 301:
			//Moved Permanently
			textInfo = 17;
			break;
		case 302:
			//Found
			textInfo = 5;
			break;
		case 303:
			//See Other
			textInfo = 9;
			break;
		case 304:
			//Not Modified
			textInfo = 12;
			break;
		//400s
		case 400:
			//Bad Request
			textInfo = 11;
			break;
		case 401:
			//Unauthorized
			textInfo = 12;
			break;
		case 403:
			//Forbidden
			textInfo = 9;
			break;
		case 404:
			//Not Found
			textInfo = 9;
			break;
		case 405:
			//Method Not Allowed
			textInfo = 19;
			break;
		//500s
		case 500:
			//Internal sever error
			textInfo = 21;
			break;
		case 501:
			//Not implemented
			textInfo = 15;
			break;
		case 502:
			//Bad gateway
			textInfo = 12;
			break;
	}
	
	return length + textInfo;
}

- (NSDictionary*)dictionaryFromResource:(NSMutableDictionary*)urlToLen
{
	NSMutableDictionary *pageEntry = [[[NSMutableDictionary alloc] init] autorelease];
	
	[pageEntry setObjectSafely:pageRef.identifier forKey:@"pageref" defaultValue:@""];
	[pageEntry setObjectSafely:[startTime formatDate] forKey:@"startedDateTime" defaultValue:@""];
	
	NSNumber *totalTime = [NSNumber numberWithInt:[endTime timeIntervalSinceDate:startTime] * 1000]; //timeInterval returns seconds
	[pageEntry setObject:totalTime forKey:@"time"];
	
	if (comment) {
		[pageEntry setObject:comment forKey:@"comment"];
	}
	
	if (status) {
		[pageEntry setObject:status forKey:@"_status"];
	}
	else {
		[pageEntry setObject:[NSNumber numberWithInt:0] forKey:@"_status"];
	}
	
	//Now populate the request object
	NSMutableDictionary *requestDictionary = [[[NSMutableDictionary alloc] init] autorelease];
	[requestDictionary setObjectSafely:requestHttpMethod forKey:@"method" defaultValue:@""];
	[requestDictionary setObjectSafely:requestURL forKey:@"url" defaultValue:@""];
	[requestDictionary setObject:[NSNumber numberWithInt:[self lengthFromHeaders:requestHeadersDict]] forKey:@"headersSize"];
	[requestDictionary setObject:[NSNumber numberWithInt:requestBodySize] forKey:@"bodySize"];
	[requestDictionary setObject:[self arrayFromCookiesArray:requestCookies] forKey:@"cookies"];
	[requestDictionary setObject:[self arrayFromHeaders:requestHeadersDict] forKey:@"headers"];
	[requestDictionary setObjectSafely:requestHttpVersion forKey:@"httpVersion" defaultValue:@""];
	[requestDictionary setObject:[self arrayFromQueryString:requestQueryString] forKey:@"queryString"];
	[pageEntry setObject:requestDictionary forKey:@"request"];
	
	//And the response
	NSMutableDictionary *responseDictionary = [[[NSMutableDictionary alloc] init] autorelease];
	[responseDictionary setObject:[NSNumber numberWithInt:responseStatusCode] forKey:@"status"];
	[responseDictionary setObjectSafely:responseStatusText forKey:@"statusText" defaultValue:@""];
	[responseDictionary setObject:[NSNumber numberWithInt:([self lengthFromHeaders:responseHeadersDict] + [self lengthFromStatusLine:responseStatusCode])] forKey:@"headersSize"];
	
	
	[responseDictionary setObject:[NSNumber numberWithInt:responseContentSize] forKey:@"_realBodySize"];
	
	//Prefer Content-Length over Content Size (From Network) over Content Size (estimated)
	NSString *contentLength = [responseHeadersDict objectForKey:@"Content-Length"];
	if (contentLength && [contentLength intValue] > 0) {
		[responseDictionary setObject:[NSNumber numberWithInt:[contentLength intValue]] forKey:@"bodySize"];
	}
	else  {
		//This is a HTML resource -- we need to fetch it's real value, since we were told the gzipValue (ResponseContentSizeFromNetwork
		NSURL *url = [NSURL URLWithString:requestURL];
		if (url) {
            // Check if the URL was already fetched in a previous loop
            NSNumber *pastLen = [urlToLen objectForKey:url];
            if (pastLen == Nil) 
            {
                //First try to just grab the site itself and use it's size
                ASIHTTPRequest *request = [[[ASIHTTPRequest alloc] initWithURL:url] autorelease];
                [request setCompletionBlock:^{
                    NSNumber *len = [NSNumber numberWithInt:[[request rawResponseData] length]];
                    [responseDictionary setObject:len forKey:@"bodySize"];
                    [urlToLen setObject:len forKey:url];
                }];
                [request startSynchronous];
                
                if ([request error]) {
                    //If there was an error, we'll just use whatever unzipped values we have...
                    [responseDictionary setObject:[NSNumber numberWithInt:responseContentSizeFromNetwork] forKey:@"bodySize"];
                }
            } else {
                [responseDictionary setObject:pastLen forKey:@"bodySize"];
            }
                
		}
		else if (responseContentSizeFromNetwork > 0) {
			[responseDictionary setObject:[NSNumber numberWithInt:responseContentSizeFromNetwork] forKey:@"bodySize"];
		}
	}
	
	[responseDictionary setObject:[self arrayFromHeaders:responseHeadersDict] forKey:@"headers"];
	[responseDictionary setObjectSafely:responseHttpVersion forKey:@"httpVersion" defaultValue:@""];
	[responseDictionary setObject:[NSDictionary dictionaryWithObjectsAndKeys:	[NSNumber numberWithInt:responseContentSize], @"size",
																				(responseMimeType == nil? @"" : responseMimeType), @"mimeType",
																				nil] forKey:@"content"];
	[responseDictionary setObject:[self arrayFromCookiesArray:responseCookies] forKey:@"cookies"];
	[responseDictionary setObject:@"" forKey:@"redirectURL"];
	[pageEntry setObject:responseDictionary forKey:@"response"];

	//Cache and Timings info
	BOOL empty = YES;
	NSMutableDictionary *cacheDictionary = [[[NSMutableDictionary alloc] init] autorelease];
	if (beforeRequestEtag || beforeRequestExpires) {
		NSMutableDictionary *beforeRequest = [[[NSMutableDictionary alloc] init] autorelease];
		[beforeRequest setObject:(beforeRequestEtag == nil ? @"" : beforeRequestEtag) forKey:@"eTag"];
		[beforeRequest setObject:(beforeRequestExpires == nil ? @"" : beforeRequestExpires) forKey:@"expires"];
		[beforeRequest setObject:[NSNumber numberWithInt:0] forKey:@"hitCount"];
		[beforeRequest setObject:[[NSDate date] formatDate] forKey:@"lastAccess"]; //We can't determine this
		[cacheDictionary setObject:beforeRequest forKey:@"beforeRequest"];
		empty = NO;
	}
	else {
		[cacheDictionary setObject:[NSNull null] forKey:@"beforeRequest"];
	}
	
	if (afterRequestEtag || afterRequestExpires) {
		NSMutableDictionary *afterRequest = [[[NSMutableDictionary alloc] init] autorelease];
		[afterRequest setObject:(afterRequestEtag == nil ? @"" : afterRequestEtag) forKey:@"eTag"];
		[afterRequest setObject:(afterRequestExpires == nil ? @"" : afterRequestExpires) forKey:@"expires"];
		
		int hitCount = 0;
		if (beforeRequestEtag && afterRequestEtag && [beforeRequestEtag isEqual:afterRequestEtag]) {
			++hitCount;
		}
		[afterRequest setObject:[NSNumber numberWithInt:hitCount] forKey:@"hitCount"];
		[afterRequest setObject:[[NSDate date] formatDate] forKey:@"lastAccess"]; //We can't determine this
		
		[cacheDictionary setObject:afterRequest forKey:@"afterRequest"];
		empty = NO;
	}
	else {
		[cacheDictionary setObject:[NSNull null] forKey:@"afterRequest"];
	}
	
	[pageEntry setObject:(empty ? [NSDictionary dictionary] : cacheDictionary) forKey:@"cache"];
	
	NSMutableDictionary *timingDictionary = [[[NSMutableDictionary alloc] init] autorelease];
	[timingDictionary setObject:[NSNumber numberWithInt:-1] forKey:@"blocked"];
	[timingDictionary setObject:[NSNumber numberWithInt:-1] forKey:@"dns"];
	[timingDictionary setObject:[NSNumber numberWithInt:-1] forKey:@"connect"];
	[timingDictionary setObject:[NSNumber numberWithInt:0] forKey:@"send"];
	[timingDictionary setObject:[NSNumber numberWithInt:0] forKey:@"wait"];
	[timingDictionary setObject:[NSNumber numberWithInt:[endTime timeIntervalSinceDate:startTime] * 1000] forKey:@"receive"];
	//Don't support this. [timingDictionary setObject:[NSNumber numberWithInt:-1] forKey:@"ssl"];
	
	[pageEntry setObject:timingDictionary forKey:@"timings"];
	
	return pageEntry;
}

@end

@implementation NSDate (RFC3339)

- (NSString*)formatDate;
{
	//We need to be RFC3339 Compliant... so add a : to the time zone
	NSString *dateString = [self formattedStringUsingFormat:(NSString*)BZDateFormat];
	dateString = [NSString stringWithFormat:@"%@:%@", [dateString substringWithRange:NSMakeRange(0, [dateString length] - 2)], [dateString substringFromIndex:[dateString length] - 2]];
	return dateString;
}

@end