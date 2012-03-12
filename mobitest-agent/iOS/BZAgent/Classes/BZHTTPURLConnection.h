//
//  BZHTTPURLConnection.h
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-17.
//  Copyright 2010 Blaze. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
	BZHTTPURLConnectionTypeGetWork,
	BZHTTPURLConnectionTypePublishHarVideo
} BZHTTPURLConnectionType;

//
// Helper class to wrap some common functionality within a URL Connection
//
@interface BZHTTPURLConnection : NSURLConnection {
@private
	BZHTTPURLConnectionType type;
	
	NSMutableData *data;
	NSURL *url;
	NSHTTPURLResponse *response;
}

@property (nonatomic, readonly) BZHTTPURLConnectionType type;
@property (nonatomic, readonly) NSData *receivedData;
@property (nonatomic, retain) NSURL *url;
@property (nonatomic, retain) NSHTTPURLResponse *response;

- (id)initWithType:(BZHTTPURLConnectionType)type request:(NSURLRequest*)request delegate:(id)delegate;

- (void)clearData;
- (void)appendData:(NSData*)data;

@end
