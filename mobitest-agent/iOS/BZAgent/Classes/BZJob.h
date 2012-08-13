//
//  BZJob.h
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-17.
//

#import <Foundation/Foundation.h>


@interface BZJob : NSObject {
@private
	NSString *testId;
	
	NSString *url;
	//NSString *location; Not supported, this is only local
	int runs;
	BOOL fvOnly;
	float screenShotImageQuality;
	//NSString *domElement; Not supported, could potentially be added in
	//BOOL privateFlag; Not supported as of yet
	//NSInteger numberOfConcurrentConnections; Not supported
	BOOL web10;
	//NSString *script; Not supported
	NSString *block; //Supported using a filtered URL cache
	NSString *login;
	NSString *password;
	BOOL ignoreSSL;
	BOOL useBasicAuth;
	BOOL captureVideo;
	//NSString *format; Not supported, outputs only JSON HAR
	//NSString *notify; Not supported, this agent should not be used like this
	//NSString *callback; Not supported, currently publishes to a well known address
	//float bwDown; Not supported, no control
	//float bwUp; Not supported, no control
	//float latency; Not supported, no control
	//float packetLossRate; Not supported no control
}

@property (nonatomic, readonly, retain) NSString *testId;
@property (nonatomic, retain) NSString *url;
@property (nonatomic, readonly) int runs;
@property (nonatomic, readonly) BOOL fvOnly;
@property (nonatomic, readonly) float screenShotImageQuality;
@property (nonatomic, readonly) BOOL web10;
@property (nonatomic, readonly, retain) NSString *block;
@property (nonatomic, readonly, retain) NSString *login;
@property (nonatomic, readonly, retain) NSString *password;
@property (nonatomic, readonly) BOOL ignoreSSL;
@property (nonatomic, readonly) BOOL useBasicAuth;
@property (nonatomic, readonly) BOOL captureVideo;

- (id)initWithDictionary:(NSDictionary*)dictionary;
+ (BZJob*)jobFromString:(NSString*)jobData;

@end
