/*
 * Blaze Android Agent
 * 
 * Copyright Blaze 2010
 */
package com.blaze.android.agent;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.lang.reflect.Method;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.Date;

import android.app.Activity;
import android.graphics.Bitmap;
import android.graphics.Picture;
import android.net.http.SslError;
import android.os.Bundle;
import android.os.CountDownTimer;
import android.os.Handler;
import android.util.Log;
import android.view.View;
import android.view.Window;
import android.webkit.CacheManager;
import android.webkit.CookieManager;
import android.webkit.CookieSyncManager;
import android.webkit.HttpAuthHandler;
import android.webkit.JsPromptResult;
import android.webkit.JsResult;
import android.webkit.SslErrorHandler;
import android.webkit.WebChromeClient;
import android.webkit.WebView;
import android.webkit.WebView.PictureListener;
import android.webkit.WebViewClient;

import com.blaze.android.agent.managers.JobManager;
import com.blaze.android.agent.managers.ProcessManager;
import com.blaze.android.agent.model.Job;
import com.blaze.android.agent.model.JobResult;
import com.blaze.android.agent.model.Run;
import com.blaze.android.agent.util.SettingsUtil;
import com.blaze.android.agent.views.BrowserView;

/**
 * This is the WebActivity; responsible for loading websites, recording the download process and then generating results.
 * 
 * @author Joshua Tessier
 */
public class WebActivity extends Activity {
	private static final String BZ_WEB_ACTIVITY = "BZ-WebActivity";

	private BrowserView view;
	private Job job;
	private JobResult result;

	private int currentRun;
	private int currentSubRun;
	private boolean preCacheRun;
	
	private Handler recordingTimer;
	private Handler timeoutHandler;
	private Handler completeHandler;
	private Runnable timeoutRunnable;
	private Runnable completionRunnable = new Runnable() {
		public void run() {
			completeStopRun();
		}
	};
	private FrameCapturer frameCapturer = null;

	// Run-specific state
	private boolean startRender;
	private boolean shouldCaptureImportantScreens;

	// Indication whether we already captured the current drawing cache
	private boolean didCaptureCurrentDrawingCache = true;
	
	/**
	 * Class FrameCapturer uses a periodic timer to capture an image of the
	 * loading web view at a regular interval.  It uses a CountDownTimer,
	 * which guarantees that the callback that captures the screen is never
	 * called unless the previous call has already returned.  All callbacks
	 * run on the thread that calls startRecording.
	 *
	 * The implementation of CountDownTimer can be seen here:
	 * http://grepcode.com/file/repository.grepcode.com/java/ext/com.google.android/android/2.3.7_r1/android/os/CountDownTimer.java
	 *
	 * @author skerner
	 *
	 * TODO(skerner): Before the webview first paints, the contents of the
	 * previous page load are captured.  Make the webview blank before the
	 * first paint.
	 */
	private class FrameCapturer
	{
		private static final long MS_PER_SECOND = 1000;
		private static final long ONE_HOUR_IN_MS = 60 * 60 * MS_PER_SECOND;

		private WebActivity parentActivity = null;
		private long millisPerFrame = 0;
		private boolean shouldStop = false;
		private CountDownTimer timer = null;

		// A format string used to generate the file name of the video frame to
		// upload.
		private String fileNameFormatString;
		
		public FrameCapturer(WebActivity parentActivity, long millisPerFrame, Run currentRun) {
			this.parentActivity = parentActivity;
			this.millisPerFrame = millisPerFrame;
			this.shouldStop = false;
			this.timer = null;

			// Frames encode the run and time of capture in their name.  Build a
			// format string that will be used to generate the name of each frame.
			StringBuilder fileNameFormatBuilder = new StringBuilder();
			fileNameFormatBuilder.append(currentRun.getRunNumber());
			fileNameFormatBuilder.append("_");
			
			if (!currentRun.isFirstView())
			  fileNameFormatBuilder.append("Cached_");
			
			fileNameFormatBuilder.append("progress_%04d");
			
			this.fileNameFormatString = fileNameFormatBuilder.toString();
		}
		
		private String FileNameForFrame(long millisSinceStart) {
			// Video frame files encode the time since loading started in their
			// file name.  This allows the server to construct a video of the page
			// loading.  The format is:
			//   <run-prefix>_progress_<zero-padded-time-from-start>.jpg
			// The time is represented as number of 100ms intervals elapsed
			// since the start of the load.  So, we divide the millisSinceStart
			// by 100ms to get the frame number.
			int timeFromStartTenthsOfSeconds = (int)(millisSinceStart / 100L);
			return String.format(this.fileNameFormatString, timeFromStartTenthsOfSeconds);
		}
		
		public void startRecording() {
		  assert this.timer == null : "Can't start a running timer.";
		
			// The CountDownTimer should fire until we stop it, but it requires
			// a time limit.  We set the limit to an hour (ONE_HOUR_IN_MS),
			// which is far longer than any web page should take to load, so
			// that in practice the timer will keep running until we stop it.
			this.timer = new CountDownTimer(ONE_HOUR_IN_MS, millisPerFrame) {
				// CountDownTimer guarantees that onTick() is never called when
				// a previous call to onTick() has not finished.  This avoids
				// common threading problems, but it does mean we might drop
				// frames if onTick() takes longer than the delay between frames.
				// The webpageTest server can deal with dropped frames.
				public void onTick(long millisUntilFinished) {
					//long startOfFrameProcessing = System.currentTimeMillis();
					long millisSinceStart = ONE_HOUR_IN_MS - millisUntilFinished;

					if (shouldStop)
						return;

					//Log.e("BZAgent", String.format("Got frame number %d", timeFromStartTenthsOfSeconds));

					parentActivity.captureScreen(FileNameForFrame(millisSinceStart), false);

					// TODO(skerner): Scale the frames to 1/2 width and height.

					//long msToProcessFrame = (System.currentTimeMillis() - startOfFrameProcessing);
					//Log.e("BZAgent", String.format("Frame number %d took %d ms to capture.",
					//      timeFromStartTenthsOfSeconds, msToProcessFrame));
				}

				@Override
				public void onFinish() {
					// There is no way a page load should take ONE_HOUR_IN_MS.  If
					// onFinish() is called, a bug in the agent must have caused us
					// to fail to cancel the timer.
					assert false : "This timer should be stopped when the page loads.";
				}
		  };
		  this.timer.start();
		}

		public synchronized void stopRecording() {
			shouldStop = true;
			assert this.timer != null : "Don't stop a timer that was never started.";
			this.timer.cancel();
			this.timer = null;
		}
	}
	
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		getWindow().requestFeature(Window.FEATURE_NO_TITLE);

		shouldCaptureImportantScreens = SettingsUtil.getShouldCaptureImportant(getBaseContext());
		
		currentRun = 0;
		currentSubRun = 0;
		preCacheRun = false;
		
		rebuildWebView();

		// Force cookie creation
		CookieSyncManager.createInstance(this);

		// Pull the next job
		this.job = JobManager.getInstance().nextJob();
		this.result = new JobResult();
		if (job != null) {
			job.setResult(result);
		}

		if (job == null) {
			Log.e(BZ_WEB_ACTIVITY, "***** WebActivity started without a job *****");
			setResult(RESULT_CANCELED);
			finish();
		}
		else {
			// The first order of business is to actually empty the data folder, don't combine results.
			File baseFolder = new File(SettingsUtil.getJobBasePath(getBaseContext()));
			if (baseFolder.exists() && baseFolder.isDirectory()) {
				// We need to empty this directory. This means deleting every file in it.
				deleteDirectory(baseFolder);
			}
			baseFolder.mkdirs();
			
			startRun(false);
		}
	}

	@Override
	public void onBackPressed() {
		Log.i(BZ_WEB_ACTIVITY, "**** Back pressed");
		JobManager.getInstance().stopAllPolling();
	}

	private void rebuildWebView() {
		if (view != null) {
			view.getWebView().destroyDrawingCache();

			// Clean up the old
			WebView oldWebView = view.getWebView();
			oldWebView.setWebChromeClient(null);
			oldWebView.setPictureListener(null);
			oldWebView.setWebViewClient(null);
			oldWebView.destroy();
		}

		// To make room for the new
		view = new BrowserView(this);
		view.setKeepScreenOn(true);
		WebView webView = view.getWebView();
		webView.setWebViewClient(new AgentWebViewClient());
		webView.setPictureListener(new AgentPictureListener());
		webView.setWebChromeClient(new AgentChromeClient());
		webView.setInitialScale(1); // Set the initial scale 1. Sites with mobile CSS wil render fine with this, sites without will be dealt with as if they're huge

		// webView.addJavascriptInterface(this, "blazeAgentDocumentCallback");
		setContentView(view);

		view.setDrawingCacheEnabled(true);
		view.buildDrawingCache();
		view.setDrawingCacheQuality(View.DRAWING_CACHE_QUALITY_LOW);
	}

	public void disableCache() {
		Log.i(BZ_WEB_ACTIVITY, "***** DISABLING CACHEMANAGER *****");
		try {
			Method m1 = CacheManager.class.getDeclaredMethod("setCacheDisabled", boolean.class);
			m1.setAccessible(true);
			m1.invoke(null, true);
		}
		catch (Throwable e) {
			Log.i("bzagent", "Reflection failed", e);
		}
	}
	
	public void enableCache() {
		Log.i(BZ_WEB_ACTIVITY, "***** ENABLING CACHEMANAGER *****");
		try {
			Method m1 = CacheManager.class.getDeclaredMethod("setCacheDisabled", boolean.class);
			m1.setAccessible(true);
			m1.invoke(null, false);
		}
		catch (Throwable e) {
			Log.i("bzagent", "Reflection failed", e);
		}
	}
	
	@Override
	protected void onDestroy() {
		view.setDrawingCacheEnabled(false);

		super.onDestroy();
	}

	/**
	 * Empties a directory recursively
	 * 
	 * @param file
	 * @return
	 */
	private boolean deleteDirectory(File file) {
		File[] files = file.listFiles();
		for (int i = 0; i < files.length; ++i) {
			if (files[i].isDirectory()) {
				deleteDirectory(files[i]);
			}
			else {
				files[i].delete();
			}
		}
		return file.delete();
	}

	/**
	 * Completely clears the WebView cache AND history
	 */
	private void clearCache() {
		Log.i(BZ_WEB_ACTIVITY, "***** CLEARING CACHE *****");
		
		// Fully clear the cache
		view.getWebView().clearCache(true);
		view.getWebView().clearHistory();
		view.getWebView().clearFormData();
		CookieManager.getInstance().removeAllCookie();
		
		// Starting in Android 2.3.3, we can't ddelete
		if (android.os.Build.VERSION.SDK_INT < 10) {
			getApplicationContext().deleteDatabase("webview.db");
			getApplicationContext().deleteDatabase("webviewCache.db");
			getApplicationContext().deleteDatabase("webview.db-wal");
			getApplicationContext().deleteDatabase("webview.db-shm");
			getApplicationContext().deleteDatabase("webviewCache.db-wal");
			getApplicationContext().deleteDatabase("webviewCache.db-shm");
		}
		/*Vector<String> cacheFiles = new Vector<String>();
		if (CacheManager.getCacheFileBaseDir() != null)
			cacheFiles.add(CacheManager.getCacheFileBaseDir().getAbsolutePath());
		if (getApplicationContext().getCacheDir() != null)
			cacheFiles.add(getApplicationContext().getCacheDir().getAbsolutePath());
		cacheFiles.add("/dbdata/databases/com.android.browser/cache/");
		cacheFiles.add("/dbdata/databases/com.android.browser/app_appcache/");
		cacheFiles.add("/data/data/com.android.browser/cache/");
		cacheFiles.add("/data/data/com.android.browser/app_appcache/");
		cacheFiles.add("/dbdata/databases/com.android.vending/webviewCache.db");
		cacheFiles.add("/dbdata/databases/com.android.vending/webview.db");
		cacheFiles.add("/data/data/com.android.browser/databases/webview.db");
		cacheFiles.add("/data/data/com.android.browser/databases/webview.db-wal");
		cacheFiles.add("/data/data/com.android.browser/databases/webview.db-shm");
		cacheFiles.add("/data/data/com.android.browser/databases/webviewCache.db");
		cacheFiles.add("/data/data/com.android.browser/databases/webviewCache.db-wal");
		cacheFiles.add("/data/data/com.android.browser/databases/webviewCache.db-shm");
		cacheFiles.add("/data/com.android.vending/databases/webview.db");
		cacheFiles.add("/data/com.android.vending/databases/webview.db-wal");
		cacheFiles.add("/data/com.android.vending/databases/webview.db-shm");
		cacheFiles.add("/data/com.android.vending/databases/webviewCache.db");
		cacheFiles.add("/data/com.android.vending/databases/webviewCache.db-wal");
		cacheFiles.add("/data/com.android.vending/databases/webviewCache.db-shm");*/
	}

	private void startRun(boolean cached) {
		if (currentRun != 0 && currentSubRun != 0) {
			rebuildWebView();
		}

		if (cached) {
			//We need to do a pre-cache run first
			if (!preCacheRun) {
				enableCache();
				preCacheRun = true;
				Log.i(BZ_WEB_ACTIVITY, "***** STARTING PRE-CACHED RUN *****");
			}
			else {
				preCacheRun = false;
				++currentSubRun;
				Log.i(BZ_WEB_ACTIVITY, "***** STARTING CACHED RUN *****");
			}
		}
		else {
			++currentRun;
			currentSubRun = 0;

			clearCache();
			disableCache();
			Log.i(BZ_WEB_ACTIVITY, "***** STARTING RUN *****");
		}

		// Reset runspecific data
		startRender = false;
		didCaptureCurrentDrawingCache  = true;
		startLoading();
	}

	private void startLoading() 
	{
		// First clean up
		WebView webView = view.getWebView();
		webView.clearView();
		webView.clearAnimation();
		webView.clearDisappearingChildren();

		if (!preCacheRun) {
			// Set up the paths
			String baseFolder = SettingsUtil.getJobBasePath(getBaseContext());
			String videoFolder = baseFolder + "video_" + currentRun + (currentSubRun == 0 ? "/" : "_cached/");
	
			// Make sure that both folders exist
			createFolderIfNeeded(baseFolder);
			createFolderIfNeeded(videoFolder);
			result.prepareRun("page_" + currentRun + "_" + currentSubRun, currentRun, currentSubRun, baseFolder, videoFolder);
	
			// Start tcpdmp
			startMonitoringNetwork();
			try {
				// Wait 2 seconds for the process to start up
				Thread.sleep(2000);
			}
			catch (InterruptedException e1) {
				// Do nothing
			}
		}

		// Set up the timeout handler
		startTimeoutHandler();

		// Start everything
		timeoutHandler.postDelayed(timeoutRunnable, SettingsUtil.getTimeout(getBaseContext()) * 1000);

		if (!preCacheRun && job.shouldCaptureVideo()) {
			startRecording();
		}

		if (!preCacheRun) {
			result.startRun();
		}
		
		try {
			webView.loadUrl(new URL(job.getUrl()).toExternalForm());
			// Display display = ((WindowManager) getSystemService(Context.WINDOW_SERVICE)).getDefaultDisplay();
			// webView.loadData("<html>" +
			// "<head><style type='text/css'>.blazeFullPage { height:" + display.getHeight() + "px; width:" + display.getWidth() + "px; }</style></head>" +
			// "<body>" +
			// "<script type=\"text/javascript\">" +
			// "var iframe = document.createElement('iframe');" +
			// "iframe.src = \"" + new URL(job.getUrl()).toExternalForm() + "\";" +
			// "iframe.onload = function () { blazeAgentDocumentCallback.documentComplete(); };" +
			// "iframe.className = 'blazeFullPage';" +
			// "document.body.appendChild(iframe);" +
			// "</script>" +
			// "</body>" +
			// "</html>", "text/html", "UTF-8");
		}
		catch (MalformedURLException e) {
			// Treat this like a timed out
			Log.w(BZ_WEB_ACTIVITY, "Malformed URL", e);
			timedOut(currentRun, currentSubRun);
		}
	}

	private void startTimeoutHandler() {
		timeoutHandler = new Handler();
		final int run = currentRun;
		final int subRun = currentSubRun;
		timeoutRunnable = new Runnable() {
			public void run() {
				timedOut(run, subRun);
			}
		};
	}

	private void timedOut(int currentRun, int currentSubRun) {
		if (this.currentRun == currentRun && this.currentSubRun == currentSubRun) {
			Log.i(BZ_WEB_ACTIVITY, "**** TIMED OUT ****");
			stopRun();
		}
	}

	private void stopRun() {
		timeoutHandler.removeCallbacks(timeoutRunnable);
		Log.i(BZ_WEB_ACTIVITY, "****** DOCUMENT COMPLETE (Could be called again -- Otherwise ending in " + SettingsUtil.getEndDelaySecs(getBaseContext()) + " seconds) ******");
		if (!preCacheRun) {
			result.docComplete();
		}
		
		// Based on our settings, wait a bit before stopping
		completeHandler = new Handler();
		completeHandler.postDelayed(completionRunnable, 
				SettingsUtil.getEndDelaySecs(getBaseContext())*1000);
	}

	/**
	 * Second half of stop run, use 'stopRun' instead.
	 */
	private void completeStopRun() {
		//Clean up before continuing
		completeHandler = null;
		
		if (!preCacheRun) {
			stopMonitoringNetwork();
			stopRecording();

			Log.i(BZ_WEB_ACTIVITY, "***** MONITORING ENDED, CALCULATING FULLY LOADED ******");

			if (shouldCaptureImportantScreens) {
				// Now take a picture!
				if (currentSubRun == 0) {
					captureScreen(currentRun + "_screen", true);
				}
				else {
					captureScreen(currentRun + "_Cached_screen", true);
				}
			}
		}

		// Run completed.
		if (!job.isFirstViewOnly() && currentSubRun == 0) {
			// Run a cached run.
			startRun(true);
		}
		else if (currentRun < job.getRunCount()) {
			// Run a regular run
			startRun(false);
		}
		else {
			view.getWebView().destroy();

			// We're done, wrap it up.
			curProcessedRun = -1;
			processNextRunResult();
		}
	}
	private int curProcessedRun = 0;
	public void processNextRunResult()
	{
		curProcessedRun++;
		if (curProcessedRun < result.getRuns().size()) {
			startPcap2HarUpload(false);  // false -> No request failed yet.
		} else {
			setResult(RESULT_OK);
			finish();
		}
	}

	public void startPcap2HarUpload(boolean experimentalPcap2HarFailed)
	{
		Run run = result.getRuns().get(curProcessedRun);
		String harFile = SettingsUtil.getJobBasePath(getBaseContext()) + job.getJobId() + "_" + run.getRunNumber() + "_" + run.getSubRunNumber() + ".har";
		run.setHarFile(harFile);
		
		String location = SettingsUtil.getLocation(getBaseContext());
		String locationKey = SettingsUtil.getLocationKey(getBaseContext());
		JobManager.getInstance().asyncPcap2har(
			this, this.job, run, location, locationKey, experimentalPcap2HarFailed);
	}

	private void startMonitoringNetwork() {
		String path = SettingsUtil.getJobBasePath(getBaseContext()) + job.getJobId() + "_" + currentRun + "_" + currentSubRun + ".pcap";
		result.getCurrentRun().setPcapFile(path);
		ProcessManager.getInstance().startNetworkMonitor(path, 
				SettingsUtil.getNetworkInterface(getBaseContext()),
				SettingsUtil.getTcpdumpPriority(getBaseContext()));
	}

	private void stopMonitoringNetwork() {
		// Zoom out as much as we can
		ProcessManager.getInstance().stopNetworkMonitor();
	}

	private void captureScreen(String fileName, boolean important) 
	{
		didCaptureCurrentDrawingCache = true;
		
		// If we didn't refresh the drawing cache since the last "onNewPicture" call, do so now.
		Bitmap screenshot = view.getDrawingCache();
		FileOutputStream fos = null;
		try {

			if (screenshot != null) { // The drawing cache may not always be populated.
				String basePath = important ? result.getCurrentRun().getBaseFolder() : result.getCurrentRun().getVideoFolder();
				// TODO: Add setting to swap between jpg and png
				String fullPath = basePath + fileName + ".jpg";
				fos = new FileOutputStream(fullPath);
				screenshot.compress(Bitmap.CompressFormat.JPEG, 70, fos);
				fos.flush();

				if (!important) {
					result.getCurrentRun().addScreenshotPath(fullPath, (new Date()).getTime());
				}
			}
			else {
				Log.e(BZ_WEB_ACTIVITY, "Screenshot is null: " + fileName + " " + important);
			}
		}
		catch (IllegalStateException e) {
			Log.e(BZ_WEB_ACTIVITY, "Failed to record screenshot", e);
		}
		catch (IOException e) {
			Log.e(BZ_WEB_ACTIVITY, "Failed to record screenshot", e);
		}
		finally {
			if (fos != null) {
				try {
					fos.close();
				}
				catch (IOException e) {
					Log.e(BZ_WEB_ACTIVITY, "Failed to close screenshot stream", e);
				}
			}
		}
	}

	private void startRecording() {
		// Now start the timer
		recordingTimer = new Handler();
		final long millisPerVideoFrame =
		    (long)(1000.0f / (float) SettingsUtil.getFps(getBaseContext()));
		frameCapturer = new FrameCapturer(this, millisPerVideoFrame, this.result.getCurrentRun());
		frameCapturer.startRecording();
	}

	private void stopRecording() 
	{
		//Log.e("BZAgent","Stopping recording");
		if (recordingTimer != null) {
			frameCapturer.stopRecording();
			recordingTimer = null;
		}
	}

	/**
	 * Utility method to create a folder if it's necessary
	 * 
	 * @param baseFolder
	 */
	private void createFolderIfNeeded(String baseFolder) {
		File file = new File(baseFolder);
		if (!file.exists()) {
			if (!file.mkdirs()) {
				Log.e(BZ_WEB_ACTIVITY, "Failed to create temporary directory " + baseFolder);
			}
		}
	}

	private class AgentWebViewClient extends WebViewClient {
		@Override
		public void onPageStarted(WebView view, String url, Bitmap favicon) {
			Log.i(BZ_WEB_ACTIVITY, "***** PAGE STARTED");
			
			if (completeHandler != null) {
				completeHandler.removeCallbacks(completionRunnable);
				completeHandler = null;
				
				//Restart the timeout handler if need be
				startTimeoutHandler();
				
				Log.i(BZ_WEB_ACTIVITY, "***** CANCELLED COMPLETION - Could be caused by redirects *****");
			}
			
			result.getCurrentRun().startResource(url);
			
			super.onPageStarted(view, url, favicon);
		}
		
		@Override
		public void onPageFinished(WebView view, String url) {
			Log.i(BZ_WEB_ACTIVITY, "**** \"PAGE FINISHED\" " + url + " ****");
			stopRun();

			super.onPageFinished(view, url);
		}

		@Override
		public void onReceivedHttpAuthRequest(WebView view, HttpAuthHandler handler, String host, String realm) {
			// Handle basic authentication
			if (job.usesBasicAuth() && job.getLogin() != null && job.getPassword() != null) {
				Log.i(BZ_WEB_ACTIVITY, "Received an auth request with: " + job.getLogin() + " " + job.getPassword());
				handler.proceed(job.getLogin(), job.getPassword());
			}
			else {
				super.onReceivedHttpAuthRequest(view, handler, host, realm);
			}
		}

		@Override
		public void onReceivedError(WebView view, int errorCode, String description, String failingUrl) {
			if (job.ignoresSSL()) {
				Log.i(BZ_WEB_ACTIVITY, "Received a generic error, ignoring");
				// ...
			}
			else {
				super.onReceivedError(view, errorCode, description, failingUrl);
			}
		}

		@Override
		public void onReceivedSslError(WebView view, SslErrorHandler handler, SslError error) {
			if (job.ignoresSSL()) {
				Log.i(BZ_WEB_ACTIVITY, "Received ssl error, proceeding");
				handler.proceed();
			}
			else {
				Log.i(BZ_WEB_ACTIVITY, "Received ssl error, failing");
				super.onReceivedSslError(view, handler, error);
			}
		}

		@Override
		public void onLoadResource(WebView view, String url) {
			result.getCurrentRun().startResource(url);
			
			super.onLoadResource(view, url);
		}

		@Override
		public boolean shouldOverrideUrlLoading(WebView view, String url) {
			boolean shouldOverride = super.shouldOverrideUrlLoading(view, url);
			
			result.getCurrentRun().startResource(url);

			return shouldOverride;
		}
	}

	/**
	 * Listener to detect picture changes on the screen.
	 * 
	 * @author Joshua Tessier
	 */
	private class AgentPictureListener implements PictureListener {
		public void onNewPicture(WebView webView, Picture picture) 
		{
			if (view != null) {
				//Keep the drawing cache up to date for video
				Log.i(BZ_WEB_ACTIVITY, "**** NEW PICTURE ****");

				// If we already captured the current drawing cache, destroy it and create a new one
				if (didCaptureCurrentDrawingCache) {
					// Refresh the drawing cache, otherwise we constantly get the same picture
					view.destroyDrawingCache();
					view.buildDrawingCache();
					didCaptureCurrentDrawingCache = false;
				}
				
				//
				// try {
				// //Here we approximate Android's 'zoom in' algorithm
				// int width = ((Integer)webView.getClass().getMethod("getContentWidth", new Class[] {}).invoke(webView, new Object[] {})).intValue();
				// float targetScale = (float)webView.getWidth() / (float)width;
				//
				// System.out.println("Scale: " + targetScale);
				//
				// Method method;
				// try {
				// //2.1
				// method = webView.getClass().getDeclaredMethod("zoomWithPreview", new Class[] {float.class});
				// method.setAccessible(true);
				// method.invoke(webView, Float.valueOf(targetScale));
				// }
				// catch (NoSuchMethodException e){
				// //2.2 +
				// method = webView.getClass().getDeclaredMethod("zoomWithPreview", new Class[] {float.class, boolean.class});
				// method.setAccessible(true);
				// method.invoke(webView, Float.valueOf(targetScale), Boolean.TRUE);
				// }
				//
				// // float currentScale;
				// // while (shouldZoom) {
				// // currentScale = webView.getScale();
				// // if (currentScale + 0.10 > targetScale && targetScale > currentScale - 0.25) {
				// // shouldZoom = false;
				// // }
				// // else if (currentScale > targetScale) {
				// // shouldZoom = webView.zoomOut();
				// // }
				// // else if (currentScale < targetScale) {
				// // shouldZoom = webView.zoomIn();
				// // }
				// // }
				// }
				// catch (Exception e) {
				// e.printStackTrace();
				// }
			}

			// if (!cleared) {
			// cleared = true;
			// } else
			if (!startRender) {
				startRender = true;

				Log.i(BZ_WEB_ACTIVITY, "**** START RENDER ****");

				// Set the time!
				result.getCurrentRun().setStartRender((new Date()).getTime());

				if (shouldCaptureImportantScreens) {
					// Now take a picture!
					if (currentSubRun == 0) {
						captureScreen(currentRun + "_screen_render", true);
					}
					else {
						captureScreen(currentRun + "_Cached_screen_render", true);
					}
				}
			}
		}
	}

	/**
	 * Client used to surpress any javascript alerts
	 * 
	 * @author Joshua Tessier
	 */
	private class AgentChromeClient extends WebChromeClient {
		@Override
		public boolean onJsAlert(WebView view, String url, String message, JsResult result) {
			Log.i(BZ_WEB_ACTIVITY, "**** Blocking Javascript Alert");
			return false;
		}

		@Override
		public boolean onJsConfirm(WebView view, String url, String message, JsResult result) {
			Log.i(BZ_WEB_ACTIVITY, "**** Blocking Javascript Confirmation");
			return false;
		}

		@Override
		public boolean onJsPrompt(WebView view, String url, String message, String defaultValue, JsPromptResult result) {
			Log.i(BZ_WEB_ACTIVITY, "**** Blocking Javascript Prompt");
			return false;
		}

		@Override
		public boolean onJsBeforeUnload(WebView view, String url, String message, JsResult result) {
			Log.i(BZ_WEB_ACTIVITY, "**** Javascript before unload");
			return false;
		}

		@Override
		public boolean onJsTimeout() {
			Log.i(BZ_WEB_ACTIVITY, "**** Javascript timeout");
			return false;
		}
	}
}
