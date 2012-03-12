//
//  BZIdleView.h
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-17.
//  Copyright 2010 Blaze. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BZIdleView;

@protocol BZIdleViewDelegate <NSObject>
- (void)idleViewTouched:(BZIdleView*)view;
@end

@interface BZIdleView : UIView {
@private
	id<BZIdleViewDelegate> delegate;
	
	UIScrollView *scrollPanel;
	
	UIImageView *statusImage;
	UIImageView *brandingImage;
	UILabel *statusLabel;
	UISwitch *enabledSwitch;
	
	UITextField *apiURLField;
	
	UIColor *baseColor;
	
	UIButton *pollNowButton;
	UIButton *wakeupButton;
	
	BOOL screenSaverEnabled;
}

@property (nonatomic, assign) id<BZIdleViewDelegate> delegate;

@property (nonatomic, readonly) UIScrollView *scrollPanel;
@property (nonatomic, readonly) UISwitch *enabledSwitch;
@property (nonatomic, readonly) UITextField *apiURLField;
@property (nonatomic, readonly) UIButton *pollNowButton;

- (void)showDisabled:(NSString*)error;
- (void)showError:(NSString*)error;
- (void)showEnabled:(NSString*)message;
- (void)showPolling:(NSString*)message;
- (void)showUploading:(NSString*)message;

- (void)setScreensaverEnabled:(BOOL)enabled;
@end
