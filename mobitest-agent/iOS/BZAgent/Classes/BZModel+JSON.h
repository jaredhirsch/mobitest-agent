//
//  BZModel+JSON.h
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-27.
//

#import <Foundation/Foundation.h>

//Model
#import "BZResult.h"
#import "BZSession.h"
#import "BZResource.h"

@interface BZResult (JSONExtension)
- (NSDictionary*)dictionaryFromResult;
- (NSData*)jsonDataFromResult;
- (NSString*)jsonStringFromResult;
@end

@interface BZSession (JSONExtension)
- (NSDictionary*)dictionaryFromSession;
@end

@interface BZResource (JSONExtension)
- (NSDictionary*)dictionaryFromResource:(NSMutableDictionary*)urlToLen;
@end