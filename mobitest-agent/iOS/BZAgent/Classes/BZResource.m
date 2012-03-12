//
//  BZResource.m
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-26.
//  Copyright 2010 Blaze. All rights reserved.
//

#import "BZResource.h"

@implementation BZResource

@synthesize pageRef;

@synthesize identifier;
@synthesize requestURL;

@synthesize requestHeadersDict;
@synthesize responseHeadersDict;

@synthesize requestHttpMethod;
@synthesize requestCookies;
@synthesize requestHttpVersion;
@synthesize requestQueryString;
@synthesize requestBodySize;

@synthesize responseStatusCode;
@synthesize responseStatusText;
@synthesize responseBodySize;
@synthesize responseHttpVersion;
@synthesize responseRedirectUrl;
@synthesize responseContentSizeFromNetwork;
@synthesize responseContentSize;
@synthesize responseMimeType;
@synthesize responseCookies;

@synthesize beforeRequestEtag;
@synthesize beforeRequestExpires;
@synthesize afterRequestEtag;
@synthesize afterRequestExpires;

@synthesize blockedTime;
@synthesize dnsTime;
@synthesize connectTime;
@synthesize sendTime;
@synthesize waitTime;
@synthesize receiveTime;
@synthesize sslTime;

@synthesize startTime;
@synthesize endTime;

@synthesize comment;
@synthesize status;

- (id)init
{
	self = [super init];
	if (self) {
        self.startTime = 0;
        self.endTime = 0;
		self.responseStatusCode = 0;
		self.responseStatusText = @"";
		self.responseBodySize = -1;
		self.requestHeadersDict = [NSMutableDictionary dictionary];
		self.responseHeadersDict = [NSMutableDictionary dictionary];
		self.responseHttpVersion = @"";
		self.responseRedirectUrl = @"";
		self.responseContentSize = -1;
		self.responseContentSizeFromNetwork = -1;
		self.responseMimeType = @"";
		self.responseCookies = [NSArray array];
		self.status = nil;
		self.comment = nil;
	}
	return self;
}

- (void)dealloc
{	
	[identifier release];
	[requestURL release];
	
	//REQUEST
	[requestHeadersDict release];
	[requestHttpMethod release];
	[requestCookies release];
	[requestHttpVersion release];
	[requestQueryString release];
	
	//RESPONSE
	[responseHeadersDict release];
	[responseStatusText release];
	[responseHttpVersion release];
	[responseRedirectUrl release];
	[responseMimeType release];
	[responseCookies release];
	
	[beforeRequestEtag release];
	[beforeRequestExpires release];
	[afterRequestEtag release];
	[afterRequestExpires release];
	
	[blockedTime release];
	[dnsTime release];
	[connectTime release];
	[sendTime release];
	[waitTime release];
	[receiveTime release];
	[sslTime release];
	
	[startTime release];
	[endTime release];
	
	[comment release];
	[status release];
	
	[super dealloc];
}

@end