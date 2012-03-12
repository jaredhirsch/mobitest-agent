/*
 * Blaze Android Agent
 * 
 * Copyright Blaze 2010
 */
package com.blaze.android.agent.model;

import java.io.File;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Map;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.util.Log;

/**
 * Groups all results for a job.  This may contain multiple <code>Run</code>s which will contain multiple <code>Resource</code>s.
 * 
 * @author Joshua Tessier
 *
 */
public class JobResult {
	private static final String BZ_JOB_RESULT = "BZ-JobResult";

	private static final String ID_START = "page_";
	private static final String STARTED_DATE_TIME = "startedDateTime";
	private static final String ID = "id";
	private static final String TITLE = "title";
	private static final String PAGEREF = "pageref";
	private static final String PAGES = "pages";
	private static final String ENTRIES = "entries";
	private static final String CREATOR = "creator";
	private static final String NAME = "name";
	private static final String VERSION = "version";
	private static final String LOG = "log";
	private static final String BROWSER = "browser";
	
	private static final String DATE_FORMAT = "yyyy-MM-dd'T'HH:mm:ss.SSSZ";
	
	private ArrayList<Run> runs;
	private Run activeRun;
	
	public JobResult() {
		runs = new ArrayList<Run>(4);
	}
	
	public void prepareRun(String identifier, int runNumber, int subRunNumber, String baseFolder, String videoFolder) {
		activeRun = new Run(identifier, runNumber, subRunNumber);
		activeRun.setBaseFolder(baseFolder);
		activeRun.setVideoFolder(videoFolder);
		runs.add(activeRun);
	}
	
	public void startRun() {
		activeRun.setStart(new Date().getTime());
	}
	
	public void docComplete() {
		getCurrentRun().setDocComplete((new Date()).getTime());
	}
	
	public List<Run> getRuns() {
		return runs;
	}
	
	public Run getCurrentRun() {
		return activeRun;
	}
	
	/**
	 * Returns the JSON Representation AND sets the document complete time for each of the runs.
	 * 
	 * TODO: Push doc complete out of here
	 * @return
	 */
	public JSONObject getJsonRepresentation() {
		JSONObject root = new JSONObject();
		JSONObject log = new JSONObject();
		
		//pcap2har divides up each of the hosts as their own site, however we care about grouping them up as a "load" and a "cached load".  So for each run, aggregate the values
		//This means that we actually have to translate all of the start times based off of the startedDateTime
		JSONArray pages = new JSONArray();
		JSONArray entries = new JSONArray();
		
		String mainId = null, runTitle = null;
		Date startTime = null, currentTime = null;;
		JSONObject runLog, finalPage, runPage, runEntry;
		JSONArray runPages, runEntries;
		
		SimpleDateFormat dateFormat = new SimpleDateFormat(DATE_FORMAT);
		
		try {
			if (runs.size() > 0) {
				//First gather all of the JSON
				JSONObject runJson;

				boolean firstRun = true;

				//Go through each run, and collect its data
				File file;
				for (Run run : runs) {
					try {
						runJson = run.readJSON();
						
						if (runJson != null) {
							runLog = runJson.getJSONObject(LOG);

							if (runLog != null) {
								if (firstRun) {
									firstRun = false;
									//Now populate the common attributes
									//Use the first run for the browser object
									JSONObject browser = new JSONObject();
									browser.put("name", "Android-Blaze-Agent");
									browser.put("version", "1.0");
									log.put(BROWSER, browser);
									log.put(VERSION, "1.1");
									
									JSONObject creator = new JSONObject();
									creator.put(VERSION, "1.0");
									creator.put(NAME, "Blaze-Android-Agent");
									log.put(CREATOR, creator);
								}
								
								runPages = runLog.getJSONArray(PAGES);
								JSONObject pageTimings = new JSONObject();
								finalPage = new JSONObject();
								long start = Long.MAX_VALUE;
								
								if (runPages != null) {
									int length = runPages.length();
									for (int i=0; i<length; ++i) {
										runPage = runPages.getJSONObject(i);
										try {
											currentTime = parseDate(dateFormat, runPage.getString(STARTED_DATE_TIME));
										}
										catch (ParseException e) {
											Log.e(BZ_JOB_RESULT, "Invalid date format", e);
											currentTime = null;
										}
										
										if (mainId == null || (currentTime != null && currentTime.before(startTime))) {
											mainId = ID_START + run.getRunNumber() + "_" + run.getSubRunNumber();
											runTitle = runPage.getString(TITLE);
											startTime = currentTime;
											start = startTime.getTime();
										}
									}
								}
								
								//Calculate the doc complete time
								long endTime = 0;
								
								Date lastDate = null;
								runEntries = runLog.getJSONArray(ENTRIES);
								Map<String, Date> resources = run.getResources();
								if (runEntries != null) {
									int length = runEntries.length();
									for (int i=0; i<length; ++i) {
										runEntry = runEntries.getJSONObject(i);
										
										JSONObject request = runEntry.optJSONObject("request");
										if (request != null) {
											if (request.has("url")) {
												resources.remove(request.get("url"));
											}
										}
										request = null;
										
										JSONObject response = runEntry.optJSONObject("response");
										if (response != null) {
											if (response.has("content")) {
												//We remove text since it's optional in the spec AND it takes up a lot of space.
												JSONObject content = response.getJSONObject("content");
												if (content.has("text")) {
													content.remove("text");
												}
											}
										}
										response = null;
										
										try {
											//Clean up the date
											lastDate = parseDate(dateFormat, runEntry.getString(STARTED_DATE_TIME));
											runEntry.put(STARTED_DATE_TIME, formatDate(dateFormat, lastDate));
											
											if (lastDate != null && lastDate.before(startTime)) {
												startTime = lastDate;
												start = lastDate.getTime();
											}
										}
										catch (ParseException e) {
											lastDate = null;
										}
										
										if (lastDate != null) {
											long newTime = lastDate.getTime() + runEntry.getLong("time");
											if (newTime > endTime) {
												endTime = newTime;
											}
										}
										
										runEntry.put(PAGEREF, mainId);
										entries.put(runEntry);
									}
								}
								
								Date date;
								for (String url : resources.keySet()) {
									date = resources.get(url);
									
									if (startTime == null || date != null && date.before(startTime)) {
										startTime = date;
										start = date.getTime();
									}
									
									JSONObject entry = new JSONObject();
									entry.put("pageref", run.getIdentifier());
									entry.put("startedDateTime", formatDate(dateFormat, resources.get(url)));
									entry.put("time", 1);
									
									JSONObject request = new JSONObject();
									request.put("method", "GET");
									request.put("url", url);
									request.put("httpVersion", "HTTP/1.1");
									request.put("cookies", new JSONArray());
									request.put("headers", new JSONArray());
									request.put("queryString", new JSONArray());
									request.put("headersSize", -1);
									request.put("bodySize", -1);
									entry.put("request", request);
									
									JSONObject response = new JSONObject();
									response.put("status", 200);
									response.put("statusText", "OK");
									response.put("httpVersion", "HTTP/1.1");
									response.put("cookies", new JSONArray());
									response.put("headers", new JSONArray());
									JSONObject content = new JSONObject();
									content.put("size", 1);
									content.put("compression", 0);
									content.put("mimeType", "text/html");
									response.put("content", content);
									response.put("redirectURL", "");
									response.put("headersSize", -1);
									response.put("bodySize", -1);
									entry.put("response", response);
									
									entry.put("cache", new JSONObject());
									
									JSONObject timings = new JSONObject();
									timings.put("blocked", -1);
									timings.put("dns", -1);
									timings.put("connect", -1);
									timings.put("send", 0);
									timings.put("wait", 0);
									timings.put("receive", 1);
									entry.put("timings", timings);
									
									entry.put("_dropped", true);
									
									entries.put(entry);
								}
								
								//Add our page entry for this particular page
								finalPage.put(TITLE, runTitle == null ? "Unknown" : runTitle);
								finalPage.put(ID, run.getIdentifier());
								finalPage.put(STARTED_DATE_TIME, formatDate(dateFormat, startTime));
									
								pages.put(finalPage);
								
								run.setFullyLoaded(endTime); //Be a good citizen and put the end time in
								//We calculate the 'fully loaded time' to be the maximum of 'all resources' or doc complete.
								pageTimings.put("onContentLoad", Math.max(run.getDocComplete() - start, -1)); //Doc complete
								//We clamp start render down to doc complete, since in these cases we weren't able to get an accurate start render time.
								pageTimings.put("_onRender", Math.max(Math.min(run.getDocComplete(), run.getStartRender()) - start, -1)); //On render
								pageTimings.put("onLoad", Math.max(Math.max(endTime, run.getDocComplete()) - start, -1));
								finalPage.put("pageTimings", pageTimings);
							}
							
							//Now that we've extracted the data, delete it
							file = new File(run.getHarFile());
							file.delete();
							runJson = null;
							mainId = null;
						}
					}
					catch (OutOfMemoryError e) {
						Log.e(BZ_JOB_RESULT, "Failed to read json files: " + e.getMessage(), e);
					}
				}
				
				log.put(PAGES, pages);
				log.put(ENTRIES, entries);
			}
			root.put(LOG, log);
		}
		catch (JSONException e) {
			Log.e(BZ_JOB_RESULT, "Could not create JSON", e);
		}
		
		return root;
	}

	private String formatDate(SimpleDateFormat dateFormat, Date lastDate) {
		String date = null;
		if (dateFormat != null && lastDate != null) {
			date = dateFormat.format(lastDate);
			if (date != null && date.length() > 2) {
				date = date.substring(0, date.length() - 2) + ":" + date.substring(date.length() - 2);
			}
		}
		return date;
	}

	private Date parseDate(SimpleDateFormat dateFormat, String string) throws ParseException {
		//pcap2har saves dates in a 'weirder' format than we expect.  Trip the milliseconds and fix it up
		int index = string.indexOf('.');
		if (index != -1) {
			String[] split = string.split("\\.");
			return dateFormat.parse(split[0] + "." + split[1].substring(0, 3) + "+0000");
		}
		return dateFormat.parse(string);
	}
}
