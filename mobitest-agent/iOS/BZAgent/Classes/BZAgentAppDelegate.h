//
//  BZAgentAppDelegate.h
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-17.
//

#import <UIKit/UIKit.h>

//Controllers
#import "BZAgentController.h"

@interface BZAgentAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
	BZAgentController *idleController;
}

@property (nonatomic, readonly, retain) UIWindow *window;

@end

