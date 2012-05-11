/*
 * Blaze Android Agent
 * 
 * Copyright Blaze 2010
 */
package com.blaze.android.agent.managers;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Vector;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

import org.apache.http.HttpRequest;
import org.apache.http.HttpResponse;
import org.apache.http.HttpVersion;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.conn.scheme.PlainSocketFactory;
import org.apache.http.conn.scheme.Scheme;
import org.apache.http.conn.scheme.SchemeRegistry;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.impl.conn.tsccm.ThreadSafeClientConnManager;
import org.apache.http.params.BasicHttpParams;
import org.apache.http.params.HttpConnectionParams;
import org.apache.http.params.HttpParams;
import org.apache.http.params.HttpProtocolParams;

import android.content.Context;
import android.os.Handler;
import android.util.Log;

import com.blaze.android.agent.WebActivity;
import com.blaze.android.agent.model.Job;
import com.blaze.android.agent.model.Job.JobParseException;
import com.blaze.android.agent.model.Run;
import com.blaze.android.agent.requests.AsyncRequest;
import com.blaze.android.agent.requests.ResponseListener;
import com.blaze.android.agent.util.SettingsUtil;
import com.blaze.android.agent.util.WebpageTestPostBuilder;
import com.blaze.android.agent.util.ZipUtil;

/**
 * Manages all interactions with the Webpagetest API and creates/parses jobs. It is also responsible for publishing results in the appropriate formats.
 * 
 * @author Joshua Tessier
 */
public final class JobManager implements ResponseListener {
	private static final String BZ_JOB_MANAGER = "BZ-JobManager";
	private static JobManager instance;
	private HttpClient client;
	private LinkedList<Job> queue;
	private List<JobListener> listeners;
	private ThreadPoolExecutor executor;
	private boolean pollingEnabled;
	private boolean awaitingReq = false;
	
	public static synchronized JobManager getInstance() {
		if (instance == null) {
			instance = new JobManager();
		}
		return instance;
	}

	private JobManager() {
		SchemeRegistry supportedSchemes = new SchemeRegistry(); 
        supportedSchemes.register(new Scheme("http", PlainSocketFactory.getSocketFactory(), 80)); 

        HttpParams params = new BasicHttpParams();
        HttpProtocolParams.setVersion(params, HttpVersion.HTTP_1_1); 
        HttpProtocolParams.setUseExpectContinue(params, false); 
        HttpConnectionParams.setConnectionTimeout(params, 30*1000);
        HttpConnectionParams.setSoTimeout(params, 5*60*1000);

        ThreadSafeClientConnManager connectionManager = new ThreadSafeClientConnManager(params, supportedSchemes);
        client = new DefaultHttpClient(connectionManager, params);
        queue = new LinkedList<Job>();
		listeners = new LinkedList<JobListener>();
		executor = new ThreadPoolExecutor(2, 4, 10*60, TimeUnit.SECONDS, new ArrayBlockingQueue<Runnable>(4));
	}

	public boolean isPollingEnabled() {
		return pollingEnabled;
	}

	public void setPollingEnabled(boolean pollingEnabled) {
		this.pollingEnabled = pollingEnabled;
	}

	public void stopAllPolling() {
		setPollingEnabled(false);
	}

	// Get the file into which jobs will be polled
	private File getJobPollFile() {
		return new File(SettingsUtil.getBasePath(context) + "jobPoll.txt");
	}
	
	// The context for reading settings
	private Context context = null;
	public void setContext(Context context) {
		this.context = context;
	}
	
	private int currentJobUrlIndex = 0;
	
	public void advanceJobUrl() {
		// getcurJobUrl handles the array size
		currentJobUrlIndex++;
	}
	
	public String getCurJobUrl()
	{
		Vector<String> jobUrls = SettingsUtil.getJobUrls(context);
		if (jobUrls.size() == 0) {
			return "";
		}
		currentJobUrlIndex = currentJobUrlIndex % jobUrls.size();
		return jobUrls.get(currentJobUrlIndex);
	}
	
	private String BuildServerUrlWithPath(String path)
	{
		String baseUrl = getCurJobUrl();
		if (baseUrl.length() == 0)
			return "";

		StringBuilder urlBuilder = new StringBuilder();
		
		// If no protocol is specified, assume http.
		if (!baseUrl.startsWith("http://") && !baseUrl.startsWith("https://")) {
		  urlBuilder.append("http://");
		}
		
		urlBuilder.append(baseUrl);
		
		if (!baseUrl.endsWith("/"))
		  urlBuilder.append("/");
		
		urlBuilder.append(path);
		return urlBuilder.toString();
	}

	/**
	 * Returns and removes the next job in the queue (at the beginning of the list, FIFO)
	 */
	public Job nextJob() {
		Job job = null;
		synchronized (queue) {
			if (!queue.isEmpty()) {
				job = queue.removeFirst();
			}
		}
		return job;
	}

	/**
	 * Peeks at the first element in the queue
	 * 
	 * @return
	 */
	public Job peekJob() {
		Job job = null;
		synchronized (queue) {
			if (!queue.isEmpty()) {
				job = queue.getFirst();
			}
		}
		return job;
	}

	public synchronized boolean pollForJobs(String location, String locationKey, String uniqueName) 
	{
		boolean success = false;
		if (!awaitingReq) 
		{
			// Advance the URL we're polling
			advanceJobUrl();
			String url = BuildServerUrlWithPath("work/getwork.php?recover=1&location=" + location + "&key=" + locationKey + "&pc=" + uniqueName);
			if (url != null && url.length() > 0)
			{
				Log.i(BZ_JOB_MANAGER, "Polling: " + url);
	
				// Executes a request and eventually returns, on this thread (not the new one)
				HttpGet getJobs = new HttpGet(url);
				
				awaitingReq = true;
				executor.execute(new AsyncRequest(getJobs, this, client, new Handler(), null, getJobPollFile()));
			}
		}
		return success;
	}

	public synchronized void publishResults(String jobId, String location, String locationKey, File zip) 
	{
		String url = BuildServerUrlWithPath("work/workdone.php");
		if (!awaitingReq && url != null && url.length() > 0) {
			Log.i(BZ_JOB_MANAGER, "Publishing: " + url);
			
			WebpageTestPostBuilder postBuilder = new WebpageTestPostBuilder();
			
			// If har processing is done on the server, then we did not create one,
			// and are not uploading one. If it is done locally, the har will be in
			// zip file we are uploading.
			boolean uploadingHar = !SettingsUtil.getShouldProcessHarsOnServer(context);
			HttpPost publishResult = null;
			try {
				postBuilder.addFileContents("file", jobId + "-results.zip", zip, "application/zip");
				postBuilder.addBooleanParamIfTrue("done", true);
				postBuilder.addBooleanParamIfTrue("har", uploadingHar);
				postBuilder.addStringParam("location", location);
				postBuilder.addStringParam("key", locationKey);
				postBuilder.addStringParam("id", jobId);
			}
			catch (UnsupportedEncodingException ex) {
				Log.e(BZ_JOB_MANAGER,
				      "Got encoding exception while creating multipart. " +
				      "Because we use a common encoding, this should not happen.", ex);
				awaitingReq = false;
				return;
			}
			publishResult = postBuilder.BuildPostForUrl(url);
			
			//Executes a request and eventually returns, on this thread (not the new one)
			awaitingReq = true;
			executor.execute(new AsyncRequest(publishResult, this, client, new Handler(), zip.getAbsolutePath(), null));
		}
	}
	
	public HttpClient getClient() {
		return client;
	}

	public void asyncPcap2har(final WebActivity activity, final Job job, final Run run, String location, String locationKey, boolean experimentalPcap2HarFailed)
	{
		// Rather than invoking the pcap2har script, we hit a web service.
		boolean shouldProcessHarsOnServer = SettingsUtil.getShouldProcessHarsOnServer(context);
		String urlPath = (shouldProcessHarsOnServer ? "work/workdone.php" : "mobile/pcap2har.php");
		String url = BuildServerUrlWithPath(urlPath);
		if (url == "")
		{
			Log.e(BZ_JOB_MANAGER, "Can't upload work.  No server url.  Set one in 'settings'");
			activity.processNextRunResult();
			return;
		}
		// Zip up the pcapPath.  If |experimentalPcap2HarFailed|, then the zip file
		// is already present from the first try.
		File zipPcapFile = new File(run.getPcapFile() + ".zip");
		if (!experimentalPcap2HarFailed &&
		    !ZipUtil.zipFile(zipPcapFile, run.getPcapFile(), zipPcapFile.getParent(), null))
		{
			Log.e(BZ_JOB_MANAGER, "Failed to zip up pcap file to path " + zipPcapFile.getAbsolutePath());
			activity.processNextRunResult();
			return;
		}
		
		// Rather than invoking the pcap2har script, we hit a web service.
		WebpageTestPostBuilder pcapPostBuilder = new WebpageTestPostBuilder();
		Map<String, Long> pageTimings = run.GetEventTimes();
		try {
			pcapPostBuilder.addStringParam("location", location);
			pcapPostBuilder.addStringParam("key", locationKey);
			pcapPostBuilder.addStringParam("id", job.getJobId());
			pcapPostBuilder.addBooleanParamIfTrue("pcap", true);
			pcapPostBuilder.addIntegerParam("_runNumber", run.getRunNumber());
			pcapPostBuilder.addBooleanParamAlways("_cacheWarmed", !run.isFirstView());
			
			for (Map.Entry<String, Long> entry : pageTimings.entrySet()) {
				// 2^31 milliseconds = 24.85 days, so integer timestamps are fine.
				int duration = entry.getValue().intValue();
				pcapPostBuilder.addIntegerParam(entry.getKey(), duration);
			}
			pcapPostBuilder.addStringParam("_urlUnderTest", job.getUrl());
			// Do not set "done".  Screen shot and video frame upload will do that.
		}
		catch (UnsupportedEncodingException ex) {
			Log.e(BZ_JOB_MANAGER,
			      "Got encoding exception while creating pcap2har upload." +
			      "We use utf8, so this shoudl not happen.", ex);
		}
		boolean useExperimentalPcap2Har = false;
		if (!experimentalPcap2HarFailed &&
		    SettingsUtil.getShouldUseExperimentalPcap2har(context)) {
			try {
				pcapPostBuilder.addBooleanParamIfTrue("useLatestPCap2Har", true);
				useExperimentalPcap2Har = true;
			}
			catch (UnsupportedEncodingException ex) {
				Log.w(BZ_JOB_MANAGER,
				      "Got exception while creating pcap2har upload." +
				      "Falling back to stable pcap2har version.", ex);
				// Send anyway: Better to fall back to the stable pcap2har than to quit.
			}
		}
		
		pcapPostBuilder.addFileContents("file", "results.pcap.zip", zipPcapFile, "application/zip");
		Log.i(BZ_JOB_MANAGER, "Preparing a POST request for pcap2har (" + url + ")");
		HttpPost pcap2harRequest = pcapPostBuilder.BuildPostForUrl(url);
		
		Pcap2HarResponseListener responseListner = new Pcap2HarResponseListener(activity, run.getHarFile(), useExperimentalPcap2Har);
		executor.execute(new AsyncRequest(pcap2harRequest, responseListner, client, new Handler(), null, new File(run.getHarFile())));
	}
	
	public synchronized void responseReceived(HttpRequest request, HttpResponse response, String extraInfo) 
	{
		awaitingReq = false;
		
		if (request instanceof HttpGet) 
		{
			boolean success = false;
			Job job = null;

			Log.i(BZ_JOB_MANAGER, "Response [Get - " + response.getStatusLine().getStatusCode() + "] received for: " + request.getRequestLine().getUri());
			
			// This was a get jobs request, if we ever introduce more requests we'll have to adjust this
			int statusCode = response.getStatusLine().getStatusCode();
			String statusText = null;
			if (statusCode == 200) 
			{
				success = true;
				FileInputStream fis = null;
				try
				{
					// Expect the job data to be in the output file
					File jobOutputFile = getJobPollFile();
					StringBuffer sb = new StringBuffer((int)jobOutputFile.length());
					fis = new FileInputStream(jobOutputFile);
					int c = -1;
					while ((c = fis.read()) > 0) {
						sb.append((char)c);
					}
					
					// Parse the job and add it to the queue
					job = Job.parseJob(sb.toString());
					if (job != null) {
						synchronized (queue) {
							queue.add(job);
						}
					}
				}
				catch (JobParseException ex)
				{
					statusText = "No valid job returned";
					Log.i(BZ_JOB_MANAGER, "[Job Parsing] Failed to parse Job", ex);
					success = false;
				}
				catch (IOException ex)
				{
					statusText = "No valid job returned";
					Log.i(BZ_JOB_MANAGER, "[Job Parsing] Failed to read Job", ex);
					success = false;
				}
				finally
				{
					if (fis != null) {
						try { fis.close(); } catch (Exception ex) {}
					}
				}
					
			}
			else {
				Log.w(BZ_JOB_MANAGER, "Received a " + statusCode + " response during polling");
			}

			// Inform any listeners
			if (success) {
				postJobFetchSuccess();
			}
			else {
				postJobFetchFailure(statusText);
			}
		}
		else if (request instanceof HttpPost) {
			Log.i(BZ_JOB_MANAGER, "Response [Post - " + response.getStatusLine().getStatusCode() + "] received for: " + request.getRequestLine().getUri());

			File zipFile = new File(extraInfo);
			zipFile.delete();
			synchronized (listeners) {
				for (JobListener listener : listeners) {
					listener.publishSucceeded();
				}
			}
		}
	}

	public synchronized void requestFailed(HttpRequest request, String reason, String extraInfo) 
	{
		awaitingReq = false;
		
		Log.e(BZ_JOB_MANAGER, "Request failed: " + reason);
		if (request instanceof HttpGet) {
			postJobFetchFailure(reason);
		}
		else if (request instanceof HttpPost) {
			if (extraInfo != null) {
				File zipFile = new File(extraInfo);
				zipFile.delete();
			}
			
			synchronized (listeners) {
				for (JobListener listener : listeners) {
					listener.publishFailed(reason);
				}
			}
		}
	}

	private void postJobFetchSuccess() 
	{
		boolean listEmpty = queue.isEmpty();
		synchronized (listeners) {
			for (JobListener listener : listeners) {
				listener.jobListUpdated(listEmpty);
			}
		}
	}

	private void postJobFetchFailure(String reason) 
	{
		synchronized (listeners) {
			for (JobListener listener : listeners) {
				listener.failedToFetchJobs(reason);
			}
		}
	}

	/**
	 * Adds a listener that will be informed of job updates and or job polling failures
	 * 
	 * @param listener
	 */
	public void addListener(JobListener listener) {
		if (listener != null) {
			synchronized (listeners) {
				listeners.add(listener);
			}
		}
	}

	/**
	 * Removes a registered job listener, does nothing if the Listener was not registered.
	 * 
	 * @param listener
	 */
	public void removeListener(JobListener listener) {
		if (listener != null) {
			synchronized (listeners) {
				listeners.remove(listener);
			}
		}
	}
}
