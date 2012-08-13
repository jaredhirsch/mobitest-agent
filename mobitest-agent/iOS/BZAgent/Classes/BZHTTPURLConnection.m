//
//  BZHTTPURLConnection.m
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-17.
//

#import "BZHTTPURLConnection.h"

@implementation BZHTTPURLConnection

@synthesize type;
@synthesize receivedData = data;
@synthesize url;
@synthesize response;

- (id)initWithType:(BZHTTPURLConnectionType)aType request:(NSURLRequest*)request delegate:(id)delegate;
{
	self = [super initWithRequest:request delegate:delegate];
	if (self) {
		type = aType;
		data = [[NSMutableData alloc] initWithCapacity:10];
		url = [[request URL] retain];
	}
	return self;
}

- (void)dealloc
{
	[data release];
	[url release];
	[super dealloc];
}

#pragma mark -
#pragma mark Data Methods

- (void)clearData
{
	[data setLength:0];
}

- (void)appendData:(NSData*)newData
{
	[data appendData:newData];
}

@end
