//
//  UIImage+Scaling.m
//  BZAgent
//
//  Created by Joshua Tessier on 10-12-02.
//  Copyright 2010 Blaze. All rights reserved.
//

#import "UIImage+Scaling.h"


@implementation UIImage (Scaling)

- (UIImage*)imageByScalingToSize:(CGSize)scaledSize
{
	UIGraphicsBeginImageContext(scaledSize);
	[self drawInRect:CGRectMake(0, 0, scaledSize.width, scaledSize.height)];
	UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	
	return scaledImage;
}

@end
