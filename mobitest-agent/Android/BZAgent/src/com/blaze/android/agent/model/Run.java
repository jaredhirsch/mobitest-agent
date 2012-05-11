/*
 * Blaze Android Agent
 * 
 * Copyright Blaze 2010
 */
package com.blaze.android.agent.model;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

import org.json.JSONException;
import org.json.JSONObject;

import android.util.Log;

/**
 * Represents information about a single run.  A run represents
 * a pass at a website (first view + cached, if specified).
 * 
 * @author Joshua Tessier
 */
public class Run {
	private static long UNSET_TIMESTAMP = -1;
	
	private String identifier;
	private String pcapFile;
	private String harFile;
	private String baseFolder;
	private String videoFolder;
	
	private int runNumber;
	private int subRunNumber;
	
	private long fullyLoaded = UNSET_TIMESTAMP;
	private long docComplete = UNSET_TIMESTAMP;
	private long startRender = UNSET_TIMESTAMP;
	private long start = UNSET_TIMESTAMP;
	
	public class ScreenshotInfo
	{
		String path;
		long timestamp;
		
		public ScreenshotInfo(String path, long timestamp) {
			this.path = path;
			this.timestamp = timestamp;
		}
		
		public String getPath() { return path; }
		public long getTimestamp() { return timestamp; }
	}
	
	private List<ScreenshotInfo> screenshotPaths;
	private Map<String, Date> resources;
	
	public Run(String identifier, int runNumber, int subRunNumber) {
		this.identifier = identifier;
		this.runNumber = runNumber;
		this.subRunNumber = subRunNumber;
		this.screenshotPaths = new ArrayList<ScreenshotInfo>(32); 
		this.resources = new HashMap<String, Date>(32);
	}

	public String getIdentifier() {
		return identifier;
	}
	
	public int getRunNumber() {
		return runNumber;
	}

	// TODO(skerner): Is subRunNumber ever not 0 or 1?  Consider replacing
	// with boolean isFirstView, for consistency with server and windows agent
	// code.
	public int getSubRunNumber() {
		return subRunNumber;
	}

	public boolean isFirstView() {
	  return subRunNumber == 0;
	}

	public String getHarFile() {
		return harFile;
	}

	public void setHarFile(String harFile) {
		this.harFile = harFile;
	}

	public String getPcapFile() {
		return pcapFile;
	}

	public void setPcapFile(String pcapFile) {
		this.pcapFile = pcapFile;
	}

	public String getBaseFolder() {
		return baseFolder;
	}

	public void setBaseFolder(String baseFolder) {
		this.baseFolder = baseFolder;
	}
	
	public String getVideoFolder() {
		return videoFolder;
	}
	
	public void setVideoFolder(String videoFolder) {
		this.videoFolder = videoFolder;
	}

	public long getFullyLoaded() {
		return this.fullyLoaded;
	}

	public void setFullyLoaded(long fullyLoaded) {
		this.fullyLoaded = fullyLoaded;
	}
	
	/**
	 * Build a map from event name (as expressed in a .har file) to the
	 * number of milliseconds from the start of the page load to the event.
	 * As in a .har file, unknown values are set to -1.
	 */
	public Map<String,Long> GetEventTimes() {
		Map<String, Long> timings = new TreeMap<String, Long>();

		long onContentLoaded = -1;
		if (this.start != UNSET_TIMESTAMP &&
		    this.docComplete != UNSET_TIMESTAMP) {
			onContentLoaded = this.docComplete - this.start;
			assert onContentLoaded >= 0 : "If timings are set, events happen after starting.";
		}
		timings.put("onContentLoad", onContentLoaded);

		long onRender = -1;
		if (this.start != UNSET_TIMESTAMP &&
		    this.startRender != UNSET_TIMESTAMP) {
		  onRender = this.startRender - this.start;
		  assert onRender >= 0 : "If timings are set, events happen after starting.";
		}
		timings.put("_onRender", onRender);

		// TODO(skerner): Add "onLoad".
		timings.put("onLoad", (long)-1);
		return timings;
	}

	public long getDocComplete() {
		return docComplete;
	}

	public void setDocComplete(long docComplete) {
		this.docComplete = docComplete;
	}

	public long getStartRender() {
		return startRender;
	}

	public void setStartRender(long startRender) {
		this.startRender = startRender;
	}
	
	public long getStart() {
		return start;
	}
	
	public void setStart(long start) {
		this.start = start;
	}

	public void addScreenshotPath(String path, long timestamp) {
		screenshotPaths.add(new ScreenshotInfo(path, timestamp));
	}
	
	public List<ScreenshotInfo> getScreenshotPaths() {
		return screenshotPaths;
	}
	
	public void startResource(String url) {
		resources.put(url, new Date());
	}
	
	public Map<String, Date> getResources() {
		return resources;
	}
	
	public JSONObject readJSON() {
		BufferedReader reader = null;
		FileReader fileReader = null;
		
		//Read in the file
		String harFile = null;
		try {
			File file = new File(getHarFile());
			if (file.exists()) {
				fileReader = new FileReader(file);
				reader = new BufferedReader(fileReader);
				
				harFile = readFile(reader);
			}
		}
		catch (IOException e) {
			Log.w("BZ-Run", "Could not populate from har.", e);
		}
		finally {
			try {
				reader.close();
			}
			catch (Exception e) {
				//Swallow
			}
			
			try {
				fileReader.close();
			}
			catch (Exception e) {
				//Swallow
			}
		}
		
		if (harFile != null) {
			try {
				return new JSONObject(harFile);
			}
			catch (JSONException e) {
				Log.e("BZ-Run", "Could not read JSON", e);
			}
		}
		return null;
	}

	/**
	 * Given a buffered reader, pulls in an entire file as a string
	 * 
	 * @param reader
	 * @return
	 * @throws IOException
	 */
	private String readFile(BufferedReader reader) throws IOException {
		String harFile;
		StringBuilder builder = new StringBuilder();
		String line = reader.readLine();
		while (line != null) {
			builder.append(line);
			line = reader.readLine();
		}
		harFile = builder.toString();
		return harFile;
	}
}
