//
//  BZJob.m
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-17.
//

#import "BZJob.h"

//Constants
#import "BZConstants.h"

@interface BZJob ()
@property (nonatomic, retain) NSString *testId;
@property (nonatomic, retain) NSString *block;
@property (nonatomic, retain) NSString *login;
@property (nonatomic, retain) NSString *password;
@end

@implementation BZJob

@synthesize testId;
@synthesize url;
@synthesize runs;
@synthesize fvOnly;
@synthesize screenShotImageQuality;
@synthesize web10;
@synthesize block;
@synthesize login;
@synthesize password;
@synthesize ignoreSSL;
@synthesize useBasicAuth;
@synthesize captureVideo;

- (id)initWithDictionary:(NSDictionary*)dictionary
{
	self = [super init];
	if (self) {
		//Pull the proper values out of the dictionary
		self.testId = [dictionary objectForKey:BZTestIdKey];
		self.url = [[dictionary objectForKey:BZURLKey] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		NSString *runCount = [dictionary objectForKey:BZRunsKey];
		if (runCount) {
			runs = MAX(MIN([runCount intValue], 20), 1); //Clamp between 1 and 20
		}
		
		NSString *fvOnlyValue = [dictionary objectForKey:BZFVOnlyKey];
		if (fvOnlyValue) {
			fvOnly = [fvOnlyValue boolValue];
		}

		BOOL serverGaveImageQualitySetting = NO;

		NSString *imageQualityValue = [dictionary objectForKey:BZImageQualityKey];
		if (imageQualityValue != nil) {
			// If the server specified a value, use that value.
			// Server should send an integer in [0..100].
			float imageQuality = [imageQualityValue floatValue];
			if (imageQuality >= 0.0 && imageQuality <= 100.0) {
				serverGaveImageQualitySetting = YES;
				screenShotImageQuality = imageQuality / 100.0;
			} else {
				NSLog(@"Server requested image quality %@.  Value must be in the "
							 "range 0..100. Using local preference value instead.",
							 imageQualityValue);
			}
		}

		if (!serverGaveImageQualitySetting) {
			// If the server did not specify a valid value, read preferences.
			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
			screenShotImageQuality = [[defaults objectForKey:kBZImageCheckpointQualitySettingsKey] floatValue];
		}

		NSString *web10Value = [dictionary objectForKey:BZWeb10Key];
		if (web10Value) {
			web10 = [web10Value boolValue];
		}
		
		NSString *blockValue = [dictionary objectForKey:BZBlockKey];
		if (blockValue) {
			self.block = blockValue;
		}
		
		NSString *basicAuthValue = [dictionary objectForKey:BZBasicAuthKey];
		if (basicAuthValue) {
			useBasicAuth = [basicAuthValue boolValue];
			self.login = [dictionary objectForKey:BZUserKey];
			self.password = [dictionary objectForKey:BZPasswordKey];
		}
		
		NSString *videoValue = [dictionary objectForKey:BZCaptureVideoKey];
		if (videoValue) {
			captureVideo = [videoValue boolValue];
		}
		
		NSString *sslKey = [dictionary objectForKey:BZIgnoreSSLKey];
		if (sslKey) {
			ignoreSSL = [sslKey boolValue];
		}
		
		//Do a bit of validation on our end
		if (!url || [url length] == 0) {
			//Make sure that we /at least/ have a URL.
			[self release];
			return nil;
		}
	}
	return self;
}

- (void)dealloc
{
	[testId release];
	[login release];
	[password release];
	[block release];
	[url release];

	[super dealloc];
}

#pragma mark -
#pragma mark Parsing

+ (BZJob*)jobFromString:(NSString*)jobData
{	
	//Job data will be in a key=value setup
	NSArray *lines = [jobData componentsSeparatedByString:@"\n"];
	NSArray *lineComponents = nil;
	
	BZJob *job = nil;	
	if ([lines count] > 0) {
		NSMutableDictionary *keyValues = [[[NSMutableDictionary alloc] initWithCapacity:16] autorelease];
		for (NSString *line in lines) {
			if ([line length] > 0) {
				NSRange splitRange = [line rangeOfString:@"="];
				if (splitRange.location != NSNotFound) {
					lineComponents = [NSArray arrayWithObjects:[line substringToIndex:splitRange.location], [line substringFromIndex:splitRange.location + 1], nil];
					[keyValues setObject:[[lineComponents objectAtIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] forKey:[[lineComponents objectAtIndex:0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
#if BZ_DEBUG_JOB_PARSING
					NSLog(@"Parsed Key:%@ Value:%@", [lineComponents objectAtIndex:0], [lineComponents objectAtIndex:1]);			
#endif
				}
				else {
#if BZ_DEBUG_JOB_PARSING
					NSLog(@"Could not parse line: %@", line);
#endif
				}
			}
		}
		
		//Now that the parsing is complete, create the job
		job = [[[BZJob alloc] initWithDictionary:keyValues] autorelease];
	}
	else {
#if BZ_DEBUG_JOB_PARSING
		NSLog(@"No lines to parse! Could not create job: %@", jobData);	
#endif
	}
	
	return job;
}

@end
