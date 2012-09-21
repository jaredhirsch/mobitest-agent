//
//  BZAgentController.h
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-17.
//

#import <Foundation/Foundation.h>

//Views
#import "BZIdleView.h"

/**
 * Controller that is presented when the agent is idle.  This is also handy for quick modifications to the agents for debugging and testing
 * purposes.
 */
@interface BZAgentController : UIViewController {
@private
	BZIdleView *idleView;
	
	NSTimer *pollTimer;
	NSString *activeURL;
	NSInteger activeURLInd;

    NSTimer *screenSaverTimer;

	BOOL isEnabled;
	BOOL keyboardVisible;
	BOOL busy;
}

+ (void)clearCachesFolder;

@end
