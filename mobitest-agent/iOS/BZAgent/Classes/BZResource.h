//
//  BZResource.h
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-26.
//  Copyright 2010 Blaze. All rights reserved.
//

#import <Foundation/Foundation.h>

//Model
#import "BZSession.h"

@class BZSession;

@interface BZResource : NSObject {
@private
	BZSession *pageRef;
	
	NSObject *identifier;
	NSString *requestURL;
	
	//REQUEST
	NSString *requestHttpMethod;
	NSArray *requestCookies;
	NSDictionary *requestHeadersDict;
	NSString *requestHttpVersion;
	NSString *requestQueryString;
	long requestBodySize;
	
	//RESPONSE
	int responseStatusCode;
	NSString *responseStatusText;
	long responseBodySize;
	NSDictionary *responseHeadersDict;
	NSString *responseHttpVersion;
	NSString *responseRedirectUrl;
	//Represents the byte count for any downloaded pages (only applicable to the main resource)
	long responseContentSizeFromNetwork;
	long responseContentSize;
	NSString *responseMimeType;
	NSArray *responseCookies;

	NSString *beforeRequestEtag;
	NSString *beforeRequestExpires;
	NSString *afterRequestEtag;
	NSString *afterRequestExpires;
	
	NSDate *blockedTime;
	NSDate *dnsTime;
	NSDate *connectTime;
	NSDate *sendTime;
	NSDate *waitTime;
	NSDate *receiveTime;
	NSDate *sslTime;
	
	NSDate *startTime;
	NSDate *endTime;
	
	NSString *comment;
	NSNumber *status;
}

@property (nonatomic, assign) BZSession *pageRef;

//Identifier used by WebKit
@property (nonatomic, retain) NSObject *identifier;
@property (nonatomic, retain) NSString *requestURL;

@property (nonatomic, retain) NSString *requestHttpMethod;
@property (nonatomic, retain) NSArray *requestCookies;
@property (nonatomic, retain) NSDictionary *requestHeadersDict;
@property (nonatomic, retain) NSString *requestHttpVersion;
@property (nonatomic, retain) NSString *requestQueryString;
@property (nonatomic, assign) long requestBodySize;

@property (nonatomic, assign) int responseStatusCode;
@property (nonatomic, retain) NSString *responseStatusText;
@property (nonatomic, assign) long responseBodySize;
@property (nonatomic, retain) NSDictionary *responseHeadersDict;
@property (nonatomic, retain) NSString *responseHttpVersion;
@property (nonatomic, retain) NSString *responseRedirectUrl;
@property (nonatomic, assign) long responseContentSize;
@property (nonatomic, assign) long responseContentSizeFromNetwork;
@property (nonatomic, retain) NSString *responseMimeType;
@property (nonatomic, retain) NSArray *responseCookies;

@property (nonatomic, retain) NSString *beforeRequestEtag;
@property (nonatomic, retain) NSString *beforeRequestExpires;
@property (nonatomic, retain) NSString *afterRequestEtag;
@property (nonatomic, retain) NSString *afterRequestExpires;

@property (nonatomic, retain) NSDate *blockedTime;
@property (nonatomic, retain) NSDate *dnsTime;
@property (nonatomic, retain) NSDate *connectTime;
@property (nonatomic, retain) NSDate *sendTime;
@property (nonatomic, retain) NSDate *waitTime;
@property (nonatomic, retain) NSDate *receiveTime;
@property (nonatomic, retain) NSDate *sslTime;

@property (nonatomic, retain) NSDate *startTime;
@property (nonatomic, retain) NSDate *endTime;
@property (nonatomic, retain) NSString *comment;
@property (nonatomic, retain) NSNumber *status;

@end
