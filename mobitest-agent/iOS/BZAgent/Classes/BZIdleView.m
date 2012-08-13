//
//  BZIdleView.m
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-17.
//

#import "BZIdleView.h"

//Constants
#import "BZConstants.h"

#define kBZBottomBorderHeight 10
#define kBZBottomBorderShadowHeight 5
#define kBZAnimationDuration 10.0f

@implementation BZIdleView

@synthesize delegate;
@synthesize scrollPanel;
@synthesize enabledSwitch;
@synthesize apiURLField;
@synthesize pollNowButton;

- (id)init
{
	NSLog(@"Should use initWithFrame for BZIdleView");
	return [self initWithFrame:CGRectZero];
}

- (id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
		self.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:kBZBackground]];
		self.userInteractionEnabled = YES;
		
		scrollPanel = [[UIScrollView alloc] initWithFrame:self.frame];
		[self addSubview:scrollPanel];
		
		//We lay this out based on what device we're on
		statusImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:kBZDisabledImage]];
		statusImage.contentMode = UIViewContentModeScaleAspectFit;
		if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
			//This is an iphone, we need to scale down the image view
			statusImage.frame = CGRectMake(0, 0, 125, 125);
		}
		else {
			statusImage.frame = CGRectMake(0, 0, 300, 300);
		}
		
		baseColor = [[UIColor colorWithRed:192.0f/255.0f green:80.0f/255.0f blue:0.0f alpha:1.0f] retain];
		
		[scrollPanel addSubview:statusImage];
		
		statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(kBZLeftSidePadding, kBZTopPadding, self.bounds.size.width - 2 * kBZLeftSidePadding, 30)];
		statusLabel.font = [UIFont boldSystemFontOfSize:24.0f];
		statusLabel.textAlignment = UITextAlignmentCenter;
		statusLabel.textColor = [UIColor whiteColor];
		statusLabel.shadowColor = [UIColor grayColor];
		statusLabel.shadowOffset = CGSizeMake(0, -1);
		statusLabel.backgroundColor = [UIColor clearColor];
		statusLabel.adjustsFontSizeToFitWidth = YES;
		[scrollPanel addSubview:statusLabel];
		
		enabledSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(kBZLeftSidePadding, 0, 100, 44)];
		[scrollPanel addSubview:enabledSwitch];
		
		apiURLField = [[UITextField alloc] initWithFrame:CGRectMake(kBZLeftSidePadding, 0, 200, 30)];
		apiURLField.borderStyle = UITextBorderStyleRoundedRect;
		apiURLField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
		apiURLField.returnKeyType = UIReturnKeyDone;
		apiURLField.keyboardType = UIKeyboardTypeURL;
		apiURLField.autocapitalizationType = UITextAutocapitalizationTypeNone;
		apiURLField.autocorrectionType = UITextAutocorrectionTypeNo;
		[scrollPanel addSubview:apiURLField];
		
		pollNowButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
		
		UIImage *pollImage = [UIImage imageNamed:kBZPollButton];
		[pollNowButton setBackgroundImage:pollImage forState:UIControlStateNormal];
		[pollNowButton setBackgroundImage:[UIImage imageNamed:kBZPollButtonPressed] forState:UIControlStateHighlighted];
		pollNowButton.frame = CGRectMake(0, 0, pollImage.size.width, 44);
		[pollNowButton setTitle:@"Poll Now" forState:UIControlStateNormal];
		pollNowButton.titleLabel.font = [UIFont boldSystemFontOfSize:16.0f];
		pollNowButton.titleLabel.shadowColor = [UIColor darkGrayColor];
		pollNowButton.titleLabel.shadowOffset = CGSizeMake(0, 1);
		[scrollPanel addSubview:pollNowButton];
		
		scrollPanel.contentSize = self.bounds.size;
		
		brandingImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:kBZBrandingImage]];
		[self addSubview:brandingImage];
		
		wakeupButton = [UIButton buttonWithType:UIButtonTypeCustom];
		wakeupButton.frame = self.bounds;
		wakeupButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		wakeupButton.hidden = YES;
		[wakeupButton addTarget:self action:@selector(wakeupButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
		[self addSubview:wakeupButton];
		
		[self showDisabled:@"Polling disabled"];
	}
	return self;
}

- (void)dealloc
{
	[scrollPanel release];
	[statusImage release];
	[statusLabel release];
	[enabledSwitch release];
	[apiURLField release];
	[pollNowButton release];
	[baseColor release];
	[super dealloc];
}

- (void)layoutSubviews
{
	CGRect bounds = self.bounds;
	statusImage.frame = CGRectMake(bounds.origin.x + roundf(0.5 * (bounds.size.width - statusImage.frame.size.width)), bounds.origin.y + 25, statusImage.frame.size.width, statusImage.frame.size.height);
	statusLabel.frame = CGRectMake(bounds.origin.x, statusImage.frame.origin.y + statusImage.frame.size.height + 10, bounds.size.width, 30);
	enabledSwitch.frame = CGRectMake(bounds.origin.x + roundf(0.5 * (bounds.size.width - enabledSwitch.frame.size.width)), statusLabel.frame.origin.y + statusLabel.frame.size.height + 15, enabledSwitch.frame.size.width, enabledSwitch.frame.size.height);
	CGFloat pollNowWidth = MIN(290, self.bounds.size.width - 2 * kBZLeftSidePadding);
	apiURLField.frame = CGRectMake(bounds.origin.x + roundf(0.5 * (bounds.size.width - pollNowWidth)), enabledSwitch.frame.origin.y + enabledSwitch.frame.size.height + 3 * kBZTopPadding, pollNowWidth, apiURLField.frame.size.height);
	pollNowButton.frame = CGRectMake(apiURLField.frame.origin.x, apiURLField.frame.origin.y + apiURLField.frame.size.height + kBZTopPadding, pollNowWidth, pollNowButton.frame.size.height);
	brandingImage.frame = CGRectMake(bounds.origin.x + roundf(0.5 * (bounds.size.width - brandingImage.frame.size.width)), CGRectGetMaxY(bounds) - kBZBottomBorderHeight - 10 - brandingImage.frame.size.height, brandingImage.frame.size.width, brandingImage.frame.size.height);
}

#pragma mark -
#pragma mark State Changes

- (void)updateStatus:(NSString*)statusMessage image:(UIImage*)image
{
	statusLabel.text = statusMessage;
	statusImage.image = image;
}

- (void)showDisabled:(NSString*)error
{
	[self updateStatus:error image:[UIImage imageNamed:kBZDisabledImage]];
}

- (void)showError:(NSString*)error
{
	[self updateStatus:error image:[UIImage imageNamed:kBZDisabledImage]];
}

- (void)showEnabled:(NSString*)message
{
	[self updateStatus:message image:[UIImage imageNamed:kBZWaitingImage]];
}

- (void)showPolling:(NSString*)message
{
	[self updateStatus:message image:[UIImage imageNamed:kBZPollingImage]];
}

- (void)showUploading:(NSString*)message
{
	[self updateStatus:message image:[UIImage imageNamed:kBZUploadingImage]];
}

- (CGFloat)randomXOrigin
{
	return arc4random() % (int)self.bounds.size.width;
}

- (CGFloat)randomYOrigin
{
	return arc4random() % (int)self.bounds.size.height;
}

- (void)randomizeLayout
{
	NSInteger animationDuration = kBZAnimationDuration;
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationCurve:UIViewAnimationCurveLinear];
	[UIView setAnimationDuration:animationDuration];
	
	//We need to play around with all view components
	brandingImage.frame = CGRectMake([self randomXOrigin], [self randomYOrigin], brandingImage.frame.size.width, brandingImage.frame.size.height);
	
	[UIView commitAnimations];
	
	[self performSelector:@selector(randomizeLayout) withObject:nil afterDelay:animationDuration];
}

- (void)setScreensaverEnabled:(BOOL)enabled
{
	//Cancel the 'randomizeLayout' selector loop (do this all the time so we don't double up)
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[[UIApplication sharedApplication] setStatusBarHidden:enabled animated:YES];
	screenSaverEnabled = enabled;
	wakeupButton.hidden = !screenSaverEnabled;
	
	pollNowButton.hidden = screenSaverEnabled;
	apiURLField.hidden = screenSaverEnabled;
	enabledSwitch.hidden = screenSaverEnabled;
	statusImage.hidden = screenSaverEnabled;
	statusLabel.hidden = screenSaverEnabled;
	
	if (enabled) {
		//Go crazy
		[self randomizeLayout];
	}
	else {
		//Stop any animations and revert to the original layout
		[UIView setAnimationsEnabled:NO];
		[UIView setAnimationsEnabled:YES];
		[self setNeedsLayout];
	}
	
	[self setNeedsDisplay];
}

- (void)wakeupButtonPressed:(id)sender
{
	if (delegate) {
		[delegate idleViewTouched:self];
	}
}

- (void)drawRect:(CGRect)rect
{
	[super drawRect:rect];
	
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (screenSaverEnabled) {
		[[UIColor blackColor] set];
		CGContextFillRect(context, rect);
	}
	else {		
		//Draw a shadow
		static const size_t  kLocationCount = 4;
		static const CGFloat kLocations[]   = { 0.0f, 0.3f, 0.6f, 1.0f };
		static const CGFloat kComponents[]  = { 0.1f, 0.1f, 0.1f, 0.3f,
            0.1f, 0.1f, 0.1f, 0.4f,
            0.1f, 0.1f, 0.1f, 0.1f,
            0.1f, 0.1f, 0.1f, 0.0f };
		
		CGColorSpaceRef rgbColorspace = CGColorSpaceCreateDeviceRGB();
		CGGradientRef gradient = CGGradientCreateWithColorComponents(rgbColorspace, kComponents, kLocations, kLocationCount);
		
		CGContextDrawLinearGradient(context, gradient, CGPointMake(CGRectGetMidX(rect), CGRectGetMaxY(rect) - kBZBottomBorderHeight), CGPointMake(CGRectGetMidX(rect), CGRectGetMaxY(rect) - (kBZBottomBorderHeight + kBZBottomBorderShadowHeight)), 0);
		
		CGGradientRelease(gradient);
		CGColorSpaceRelease(rgbColorspace);
		
		//Now draw the bottom box
		[baseColor set];
		CGContextFillRect(context, CGRectMake(rect.origin.x, rect.origin.y + rect.size.height - kBZBottomBorderHeight, rect.size.width, kBZBottomBorderHeight));
	}
}

@end
