//
//  BZJobManager.h
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-17.
//

#import <Foundation/Foundation.h>

//Model
#import "BZJob.h"
#import "BZResult.h"

//URL Connections
#import "BZHTTPURLConnection.h"

//
// Maintains a queue of all jobs that have been polled from the service.
//
// This will asynchronously notify any registered controllers when new jobs come in.
//
@interface BZJobManager : NSObject {
@private
	NSMutableArray *currentJobs;
	
	//We only spawn one fetch job request at a time. If needed, this can change to a dictionary and we can add identifiers to the connections
	BZHTTPURLConnection *activeRequest;

    // Active data
    NSData *data;

}

@property (nonatomic, readonly) NSInteger jobCount;
@property (nonatomic, readonly) BOOL hasJobs;

+ (BZJobManager*)sharedInstance;

//
// Fires a 'poll for jobs' request at the location specified.  Returns 'YES' if the request was started
// 
- (BOOL)pollForJobs:(NSString*)url fromAuto:(BOOL)fromAuto;

//
// Gets and returns the next job.  This will remove it from the queue.
//
- (BZJob*)nextJob;

//
// Returns the job without removing it from the queue.
//
- (BZJob*)peekNextJob;

//
// Publishes the results
//
- (void)publishResults:(BZResult*)result url:(NSString*)url;

- (void)postZip:(BZResult*)result url:(NSString*)url;

@end
