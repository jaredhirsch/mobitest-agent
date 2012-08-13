//
//  NSDate+Formatting.m
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-27.
//

#import "NSDate+Formatting.h"

static NSCalendar *gregorianCalendar;
static NSMutableDictionary *cachedDateFormatters;

@implementation NSDate (DateFormatting)

+ (void)initialize
{
	if (self == [NSDate class]) {
		cachedDateFormatters = [[NSMutableDictionary alloc] initWithCapacity:10];
		gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	}
}

+ (NSDate*)dateFromString:(NSString*)string format:(NSString*)format
{
	NSDate *date = nil;
	if (string && format) {
		NSDateFormatter *formatter = [cachedDateFormatters objectForKey:format];
		if (formatter == nil) {
			formatter = [[NSDateFormatter alloc] init];
			[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease]];
			[formatter setDateFormat:format];
			[cachedDateFormatters setObject:formatter forKey:format];
			[formatter release];
		}
		
		date = [formatter dateFromString:string];
	}
	
	return date;
}

- (NSString*)formattedStringUsingFormat:(NSString*)dateFormat
{
    NSDateFormatter *formatter = [cachedDateFormatters objectForKey:dateFormat];
	if (formatter == nil) {
		formatter = [[NSDateFormatter alloc] init];
		[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease]];
		[formatter setDateFormat:dateFormat];
		[cachedDateFormatters setObject:formatter forKey:dateFormat];
		[formatter release];
	}
	
    return [formatter stringFromDate:self];
}

@end
