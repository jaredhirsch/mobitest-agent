/*
 * Blaze Android Agent
 * 
 * Copyright Blaze 2010
 */
package com.blaze.android.agent.model;

import java.util.HashMap;
import java.util.Map;

import android.util.Log;

import com.blaze.android.agent.Constants;

/**
 * 
 * @author Joshua Tessier
 *
 */
public class Job {
	private String jobId;
	private String url;
	private int runs;
	private boolean firstViewOnly;
	private boolean web10;
	private String login;
	private String password;
	private boolean ignoreSSL;
	private boolean useBasicAuth;
	private boolean captureVideo;
	private boolean captureTcpdump;
	
	private JobResult result;
	
	/**
	 * Creates a Job from a map of values
	 * 
	 * @param keyValueMap
	 */
	public Job(Map<String, String> keyValueMap) {
		this.jobId = keyValueMap.get(Constants.TEST_ID);
		this.url = keyValueMap.get(Constants.URL);
		this.runs = Math.max(intValue(keyValueMap.get(Constants.RUNS)), 1); //We always have at least one run
		this.firstViewOnly = boolValue(keyValueMap.get(Constants.FV_ONLY));
		this.login = keyValueMap.get(Constants.LOGIN);
		this.password = keyValueMap.get(Constants.PASSWORD);
		this.ignoreSSL = boolValue(keyValueMap.get(Constants.IGNORE_SSL));
		this.useBasicAuth = boolValue(keyValueMap.get(Constants.BASIC_AUTH));
		this.captureVideo = boolValue(keyValueMap.get(Constants.CAPTURE_VIDEO));
		this.captureTcpdump = boolValue(keyValueMap.get(Constants.CAPTURE_TCPDUMP));
		
	}

	/**
	 * Creates a job from a string
	 * 
	 * @param string
	 * @return
	 * @throws JobParseException
	 */
	public static Job parseJob(String string) throws JobParseException {
		Log.d("BZ-Job", "Response: " + string);
		
		Job job = null;
		if (string != null && string.trim().length() > 0) {
			String[] lines = string.split("\\n");
			if (lines != null) {
				int index;
				Map<String, String> keyValueMap = new HashMap<String, String>(lines.length);
				for (String line : lines) {
					line = line.replaceAll("\\r", "");
					index = line.trim().indexOf('=');
					if (index != -1) {
						keyValueMap.put(line.substring(0, index), line.substring(index + 1));
					}
				}
				
				job = new Job(keyValueMap);
			}
		}
		
		if (job != null && job.url == null) {
			job = null;
		}
		return job;
	}
	
	public String getJobId() {
		return jobId;
	}
	
	public void setJobId(String jobId) {
		this.jobId = jobId;
	}
	
	public String getUrl() {
		return url;
	}
	
	public void setUrl(String url) {
		this.url = url;
	}
	
	public int getRunCount() {
		return runs;
	}
	
	public void setRuns(int runs) {
		this.runs = runs;
	}
	
	public boolean isFirstViewOnly() {
		return firstViewOnly;
	}
	
	public void setFirstViewOnly(boolean firstViewOnly) {
		this.firstViewOnly = firstViewOnly;
	}
	
	public boolean isWeb10() {
		return web10;
	}
	
	public void setWeb10(boolean web10) {
		this.web10 = web10;
	}
	
	public String getLogin() {
		return login;
	}
	
	public void setLogin(String login) {
		this.login = login;
	}
	
	public String getPassword() {
		return password;
	}
	
	public void setPassword(String password) {
		this.password = password;
	}
	
	public boolean ignoresSSL() {
		return ignoreSSL;
	}
	
	public void setIgnoreSSL(boolean ignoreSSL) {
		this.ignoreSSL = ignoreSSL;
	}
	
	public boolean usesBasicAuth() {
		return useBasicAuth;
	}
	
	public void setUseBasicAuth(boolean useBasicAuth) {
		this.useBasicAuth = useBasicAuth;
	}
	
	public boolean shouldCaptureVideo() {
		return captureVideo;
	}
	
	public boolean shouldCaptureTcpdump() {
		return captureTcpdump;
	}
	
	
	public void setCaptureVideo(boolean captureVideo) {
		this.captureVideo = captureVideo;
	}
	
	public static class JobParseException extends Exception {
		private static final long serialVersionUID = -7918159290079200824L;

		public JobParseException(String reason) {
			super(reason);
		}
	}
	
	/**
	 * Parses an int from a string, returns 0 if it cannot be parsed
	 * 
	 * @param string
	 * @return
	 */
	private int intValue(String string) {
		try {
			return string == null? 0 : Integer.valueOf(string);
		}
		catch (NumberFormatException e) {
			return 0;
		}
	}
	
	/**
	 * Returns true if the string is "true", false otherwise.
	 * 
	 * @param string
	 * @return
	 */
	private boolean boolValue(String string) {
		if (string != null && string.toLowerCase().equals("1")) {
			return true;
		}
		return false;
	}
	
	public String toString() {
		return "[JOB: " + jobId + " - URL: " + url + " - RUNS:" + runs + "]";
	}

	public JobResult getResult() {
		return result;
	}
	
	public void setResult(JobResult result) {
		this.result = result;
	}
}
