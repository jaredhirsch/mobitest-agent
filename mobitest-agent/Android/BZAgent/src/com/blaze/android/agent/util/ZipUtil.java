package com.blaze.android.agent.util;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.regex.Pattern;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

import android.util.Log;

public class ZipUtil 
{
	private static final String BZ_ZIP_UTIL = "BZZipUtil";
	private static final int BUFFER_SIZE = 2048;

	public static boolean zipFile(File zipFile, String pathToInclude, String basePath, Pattern excludePat)
	{
		//Now we need to zip up the file folders
		ZipOutputStream zos = null;
		FileOutputStream fos = null;
		try {
			fos = new FileOutputStream(zipFile);
			zos = new ZipOutputStream(fos);
			
			ZipUtil.addFileToZip(zos, new File(pathToInclude), basePath, excludePat);
			zos.flush();
			zos.close();
			zos = null;
			
			return true;
		}
		catch (IOException e) {
			Log.e(BZ_ZIP_UTIL, "Failed to create zip", e);
			return false;
		}
		catch (OutOfMemoryError e) {
			Log.e(BZ_ZIP_UTIL, "Failed to create zip", e);
			return false;
		}
		finally {
			if (zos != null) {
				try {
					zos.close();
				}
				catch (Exception e) {}
				
				try {
					fos.close();
				}
				catch (Exception e) {}
			}
		}
	}
	
	/**
	 * Recursively creates a zip file
	 * 
	 * @param zos
	 * @param file
	 * @param base
	 * @throws IOException
	 */
	public static void addFileToZip(ZipOutputStream zos, File file, String basePath, Pattern excludePat) throws IOException 
	{
		if (file.isFile()) 
		{
			String name = file.getAbsolutePath();				
			// Allow certain files to be excluded
			if (excludePat != null && excludePat.matcher(name).find())
				return;
			
			//Add this file to the zip file
			FileInputStream fi = new FileInputStream(file);
			BufferedInputStream bis = null;
			try 
			{
				bis = new BufferedInputStream(fi, BUFFER_SIZE);
				
				name = name.substring(name.indexOf(basePath) + basePath.length());
				ZipEntry entry = new ZipEntry(name);
				zos.putNextEntry(entry);
				int count = 0;
				byte data[] = new byte[BUFFER_SIZE];
				while ((count = bis.read(data, 0, BUFFER_SIZE)) != -1) {
					zos.write(data, 0, count);
				}
				zos.flush();
			}
			finally {
				if (fi != null) {
					fi.close();
				}
				
				if (bis != null) {
					bis.close();
				}
			}
		}
		else if (file.isDirectory()) {
			File[] files = file.listFiles();
			for (File childFile : files) {
				ZipUtil.addFileToZip(zos, childFile, basePath, excludePat);
			}
		}
	}

}
