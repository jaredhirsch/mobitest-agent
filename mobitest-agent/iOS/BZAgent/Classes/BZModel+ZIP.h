//
//  BZModel+ZIP.h
//  BZAgent
//
//  Created by Joshua Tessier on 10-12-02.
//  Copyright 2010 Blaze. All rights reserved.
//

#import <Foundation/Foundation.h>

//Model
#import "BZResult.h"

@interface BZResult (ZIPExtension)
/**
 *
 *Takes the screenshots for each application and prepares them for transmission in a zip file.
 *
 *Note that this is a destructive operation that calls BZSession's -(void)transformVideoToAvisynth; as a form of compression.
 *
 */
- (NSData*)zipResultData;
@end

@interface BZSession (AvisynthExtension)
/*
 *Takes the screenshots gathered by the application and turns it into avisynth format
 *
 *Important: This is a destructive operation and will perform the following operations (this should be refactored, but convenient for now)
 *	1) Delete all unused/duplicate images
 *  2) Inserts a video.avs file into the video folders
 */
- (NSString*)transformVideoToAvisynth:(int)recordedFps;
/*
 * Scales all images to a proper size
 *		Currently only scales down iPhone4 images
 */
- (void)scaleDownAllImages;

@end