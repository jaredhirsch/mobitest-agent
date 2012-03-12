package com.blaze.android.agent.util;

import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.List;

import android.graphics.Bitmap;
import android.graphics.drawable.BitmapDrawable;
import android.util.Log;

import com.blaze.android.agent.model.Run;

/**
 * Creates Avisynth files
 * 
 * @author Joshua Tessier
 */
public class AVSUtil {
	/**
	 * Creates an avisynth out of the the run's screenshots and saves it to the locationToSave.
	 * 
	 * @param run
	 * @param locationToSave
	 */
	public static void createAvisynthFile(Run run, String locationToSave, int fps) {
		List<Run.ScreenshotInfo> screenshots = run.getScreenshotPaths();
		if (!screenshots.isEmpty()) {
			BufferedOutputStream bos = null;
			FileOutputStream fos = null;
			
			int framerateAdjustment = 10 / fps;
			
			try {
				fos = new FileOutputStream(new File(locationToSave + "video.avs"));
				bos = new BufferedOutputStream(fos);
				
				BitmapDrawable imageDrawable;
				Bitmap newImage = null, image = null;
				boolean equal = true;
				File file;
				String oldName = null;
				int frameDuration = 1;
				for (Run.ScreenshotInfo screenshot : screenshots) {
					newImage = null;
					String screenshotPath = screenshot.getPath();
					imageDrawable = new BitmapDrawable(screenshotPath);
					newImage = imageDrawable.getBitmap();

					if (image != null) {
						//We need to compare
						int width = image.getWidth();
						int height = image.getHeight();
						if (width == newImage.getWidth() && height == newImage.getHeight()) {
							int[] newPixels = new int[width * height];
							int[] oldPixels = new int[width * height];
							newImage.getPixels(newPixels, 0, width, 0, 0, width, height);
							image.getPixels(oldPixels, 0, width, 0, 0, width, height);
							int currentOffset = 0;
							for (int i=0; equal && i<width; ++i) {
								currentOffset = i * width;
								for (int j=0; equal && j<height; ++j) {
									equal = newPixels[currentOffset + j] == oldPixels[currentOffset + j];
								}
							}
						}
						else {
							equal = false;
						}
						
						if (equal) {
							++frameDuration;
							
							newImage.recycle();
							
							//Delete 'new image'
							file = new File(screenshotPath);
							file.delete();
							file = null;
						}
						else {
							//Replace the old image with the new
							//First, write the file to the avisynth
							bos.write(("ImageSource(\"" + oldName + "\", start = 1, end = " + frameDuration * framerateAdjustment + ", fps = 10) + \\\n").getBytes());

							oldName = getFileNameAndPath(screenshotPath);
							image = newImage;
							
							frameDuration = 1;
						}
					}
					else {
						oldName = getFileNameAndPath(screenshotPath);
						
						frameDuration = 1;
						
						image = newImage;
					}
				}
				
				if (oldName != null) {
					//Add the last valid image to the file as a "grande finale"
					//Set up the new image, this is the first line
					bos.write(("ImageSource(\"" + oldName + "\", start = 1, end = " + frameDuration + ", fps = 10)").getBytes());
				}
				
				bos.flush();
			}
			catch (IOException e) {
				Log.e("BZ-AVS", "Could not write avisynth file", e);
			}
			catch (OutOfMemoryError e) {
				Log.e("BZ-AVS", "Failed to save the avisynth file", e);
			}
			finally {
				if (bos != null) {
					try {
						bos.close();
					}
					catch (IOException e) {}
				}
				
				if (fos != null) {
					try {
						fos.close();
					}
					catch (IOException e) {}
				}
			}
		}
	}
	
	public static String getFileNameAndPath(String path) {
		int index = path.lastIndexOf('/');
		return index == -1 || index == (path.length() - 1)? path : path.substring(index + 1);
	}
}