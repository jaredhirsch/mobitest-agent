//
//  BZRecoverAgentAppDelegate.h
//  BZRecoverAgent
//
//  Created by Joshua Tessier on 11-02-19.
//

#import <UIKit/UIKit.h>

@interface BZRecoverAgentAppDelegate : NSObject <UIApplicationDelegate> {

}

@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, retain) UIViewController *rootViewController;

- (void)restart;
- (void)scheduleRestart;

@end
