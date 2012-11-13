//
//  BZModel+ZIP.m
//  BZAgent
//
//  Created by Joshua Tessier on 10-12-02.
//

#import "BZModel+ZIP.h"

//Zip Util
#import "ZKFileArchive.h"
#import "NSFileManager+ZKAdditions.h"

//Additions
#import "UIImage+Scaling.h"

//Constants
#import "BZConstants.h"

#define kBZAVSLineFormat @"ImageSource(\"%@\", start = 1, end = %d, fps = %d)"
#define kBZAVSLineContinuation @" + \\\n"

#define kBZDesiredFPS 10

@implementation BZSession (AvisynthExtension)

- (void)scaleDownImages:(NSArray*)imagePaths quality:(float)quality
{
	UIImage *image;
	UIImage *scaledImage;
	NSData *imageData = nil;
    float resizeRatio = [[[NSUserDefaults standardUserDefaults] objectForKey:kBZImageResizeRatioSettingsKey] floatValue];
	for (NSString *imagePath in imagePaths) 
    {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		image = [[UIImage alloc] initWithContentsOfFile:imagePath];
		
		/*if ((image.size.width == 640 && image.size.height == 960) || (image.size.width == 768 && image.size.height == 1024) || (image.size.width == 1024 && image.size.height == 768)) {*/
			scaledImage = [image imageByScalingToSize:CGSizeMake(image.size.width * resizeRatio, image.size.height * resizeRatio)];
			imageData = UIImageJPEGRepresentation(scaledImage, quality);
			if (![imageData writeToFile:imagePath atomically:NO]) {
				NSLog(@"Could not scale %@", imagePath);
			}
		//}
		
		[image release];
        [pool drain];
	}
}

- (void)scaleDownAllImagesWithScreenshotImageQuality:(float)screenShotImageQuality
{
	[self scaleDownImages:screenshotPaths quality:[[[NSUserDefaults standardUserDefaults] objectForKey:kBZImageVideoQualitySettingsKey] floatValue]];
	[self scaleDownImages:importantScreenshotPaths quality:screenShotImageQuality];
}

- (NSInteger)durationForFPS:(int)fps
{
	//Aim for a solid 10 fps
	return kBZDesiredFPS / fps;
}

- (NSString*)transformVideoToAvisynth:(int)fps
{
	NSMutableString *avisynth = [[[NSMutableString alloc] init] autorelease];

	CFIndex newLength, oldLength;
	CFDataRef oldBitmapData;
	
	NSString *previousImagePath = nil;
	UIImage *image;
	int frameDuration = [self durationForFPS:fps];
	
	NSMutableIndexSet *indexSet = [[[NSMutableIndexSet alloc] init] autorelease];
	
	//TOOD: Optimize if possible
	//This currently runs in O(Screenshots * PixelsPerImage)
	int currentPathIndex = 0;
	BOOL firstRun = YES;
	for (NSString *imagePath in screenshotPaths) 
    {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

		image = [[UIImage alloc] initWithContentsOfFile:imagePath];
		
		if (image) {
			//First step compare the images
			if (firstRun) {
				firstRun = NO;
				
				//There was no previous image, simply use this guy
				previousImagePath = [imagePath retain];
				oldBitmapData = CGDataProviderCopyData(CGImageGetDataProvider([image CGImage]));
				oldLength = CFDataGetLength(oldBitmapData);
			}
			else {
				//Compare this image with the previous one.  We do a very primitive comparison with bytes.  If the screen hasn't changed, it should be identical.
				CFDataRef bitmapData = CGDataProviderCopyData(CGImageGetDataProvider([image CGImage]));
				newLength = CFDataGetLength(bitmapData);
				
				const UInt8 *oldBytes = CFDataGetBytePtr(oldBitmapData);
				const UInt8 *newBytes = CFDataGetBytePtr(bitmapData);
				
				//TODO: Optimize this comparison, this is just a brute force byte comparison
				BOOL isEqual = YES;
				if (newLength == oldLength) {
					for (int i=0; isEqual && i<newLength; ++i) {
						isEqual = oldBytes[i] == newBytes[i];
					}
				}
				
				if (isEqual) {
					frameDuration += [self durationForFPS:fps];
					
					//Remove the new image
					//1) Clean up the data provider
					CFRelease(bitmapData);
					
					//2) Add the index to the indexSet
					[indexSet addIndex:currentPathIndex];
					
					//3) Delete this image (from disk, not from the array yet)
					[[NSFileManager defaultManager] removeItemAtPath:imagePath error:nil];
				}
				else {
					//This is a new frame, act accordingly.
					//1) Add the necessary data to the avisynth file
					if ([avisynth length] == 0) {
						[avisynth appendFormat:kBZAVSLineFormat, [previousImagePath lastPathComponent], frameDuration, kBZDesiredFPS];
					}
					else {
						[avisynth appendString:kBZAVSLineContinuation];
						[avisynth appendFormat:kBZAVSLineFormat, [previousImagePath lastPathComponent], frameDuration, kBZDesiredFPS];
					}
					
					//2) Free up the old information and reset the frame duration
					CFRelease(oldBitmapData);
					[previousImagePath release];
					frameDuration = [self durationForFPS:fps];
					
					//3) New -> Old
					oldBitmapData = bitmapData;
					previousImagePath = [imagePath retain];
					oldLength = newLength;
				}
			}
			[image release];
            [pool drain];
		}
        		
		++currentPathIndex;
	}
	
	//Now remove any unecessary pointers to images
	[screenshotPaths removeObjectsAtIndexes:indexSet];
	
	if (!firstRun) {
		//Do one final print
		if ([avisynth length] == 0) {
			[avisynth appendFormat:kBZAVSLineFormat, [previousImagePath lastPathComponent], frameDuration, kBZDesiredFPS];
		}
		else {
			[avisynth appendString:kBZAVSLineContinuation];
			[avisynth appendFormat:kBZAVSLineFormat, [previousImagePath lastPathComponent], frameDuration, kBZDesiredFPS];
		}
		
		//Release anything we may have held on to
		if (oldBitmapData) {
			CFRelease(oldBitmapData);
			[previousImagePath release];
		}
	}
	
	return avisynth;
}

@end

@implementation BZResult (ZIPExtension)

- (NSData*)zipResultData
{
    NSString *cachesFolder = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    NSString *resultFolder = [cachesFolder stringByAppendingPathComponent:@"result"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:resultFolder]) {
		NSLog(@"Missing caches result folder");
	}

	NSString *archiveLocation = [[resultFolder stringByDeletingLastPathComponent] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-results.zip", jobId]];

#if BZ_DEBUG_REQUESTS
	NSLog(@"Creating Avisynth File");
#endif
	//Go through each of the sessions and compress them
	NSString *avisynth;
	int fps = [[[NSUserDefaults standardUserDefaults] objectForKey:kBZFPSSettingsKey] intValue];
	for (BZSession *session in runs) 
    {
#if BZ_DEBUG_REQUESTS
        NSLog(@"Processing run session");
#endif
		avisynth = [session transformVideoToAvisynth:fps];
		if ([avisynth length] > 0) {
			[avisynth writeToFile:[[resultFolder stringByAppendingPathComponent:session.videoFolder] stringByAppendingPathComponent:@"video.avs"] atomically:NO encoding:NSUTF8StringEncoding error:nil];
			[[NSString stringWithFormat:@"%d",fps] writeToFile:[[resultFolder stringByAppendingPathComponent:session.videoFolder] stringByAppendingPathComponent:@"realfps.txt"] atomically:NO encoding:NSUTF8StringEncoding error:nil];
		}
#if BZ_DEBUG_REQUESTS
        NSLog(@"Scaling down images");
#endif
		[session scaleDownAllImagesWithScreenshotImageQuality:screenShotImageQuality];
	}
	
#if BZ_DEBUG_REQUESTS
    NSLog(@"Creating zip archive");
#endif
	//Create the archive.  This will pick up the har file
	ZKFileArchive *archive = [ZKFileArchive archiveWithArchivePath:archiveLocation];
	archive.useZip64Extensions = YES;
	NSArray *files = [archive.fileManager contentsOfDirectoryAtPath:resultFolder error:nil];
	NSString *fullPath;
	for (NSString *file in files) {
#if BZ_DEBUG_REQUESTS
        NSLog(@"Adding file %@ to archive", file);
#endif
		fullPath = [resultFolder stringByAppendingPathComponent:file];
		if ([archive.fileManager zk_isDirAtPath:fullPath]) {
			[archive deflateDirectory:fullPath relativeToPath:resultFolder usingResourceFork:NO];
            NSDirectoryEnumerator *en = [[[NSFileManager defaultManager] enumeratorAtPath:fullPath] retain];
            [en release];
		}
		else {
			[archive deflateFile:fullPath relativeToPath:resultFolder usingResourceFork:NO];
		}
	}

#if BZ_DEBUG_REQUESTS
    NSLog(@"Reading data of file");
#endif
	//Grab its data
	NSData *data = [NSData dataWithContentsOfFile:archiveLocation];
	
#if BZ_DEBUG_REQUESTS
    NSLog(@"Deleting old file");
#endif
	//Delete the old one
	[[NSFileManager defaultManager] removeItemAtPath:archiveLocation error:nil];
	
	return data;
}

@end
