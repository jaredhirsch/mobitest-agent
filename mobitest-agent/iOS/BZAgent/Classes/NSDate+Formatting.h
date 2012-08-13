//
//  NSDate+Formatting.h
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-27.
//

#import <Foundation/Foundation.h>

//
// Efficient methods to produce formatted strings and date from strings.  This uses cached date formatters and calendars.
//
@interface NSDate (DateFormatting)

//
// Produce a date from a string using the specified format
//
// String and Format cannot be nil
//
+ (NSDate*)dateFromString:(NSString*)string format:(NSString*)format;


//
// Returns a string with the proper date format
//
- (NSString*)formattedStringUsingFormat:(NSString*)dateFormat;

@end
