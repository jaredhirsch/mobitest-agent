//
//  BZRecoverAgentAppDelegate.h
//  BZRecoverAgent
//
//  Created by Joshua Tessier on 11-02-19.
//  Copyright 2011 Blaze. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BZRecoverAgentAppDelegate : NSObject <UIApplicationDelegate> {

}

@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, retain) UIViewController *rootViewController;

- (void)restart;
- (void)scheduleRestart;

@end
