/*
 * Blaze Android Agent
 * 
 * Copyright Blaze 2010
 */
package com.blaze.android.agent;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.nio.channels.FileChannel;
import java.util.List;
import java.util.regex.Pattern;

import org.json.JSONException;
import org.json.JSONObject;

import android.app.Activity;
import android.app.AlarmManager;
import android.app.AlertDialog;
import android.app.PendingIntent;
import android.app.AlertDialog.Builder;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.util.Log;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.TextView;

import com.blaze.android.agent.managers.JobListener;
import com.blaze.android.agent.managers.JobManager;
import com.blaze.android.agent.managers.ProcessManager;
import com.blaze.android.agent.model.Job;
import com.blaze.android.agent.model.Run;
import com.blaze.android.agent.util.AVSUtil;
import com.blaze.android.agent.util.JSONUtil;
import com.blaze.android.agent.util.SettingsUtil;
import com.blaze.android.agent.util.ZipUtil;

/**
 * AgentActivity is the main activity that allows you to configure and set up your agent
 * 
 * @author Joshua Tessier
 * 
 */
public class AgentActivity extends Activity implements JobListener {
	
	private static final String BZ_AGENT = "BZAgent";
	
	public static int GATHER_METRICS_ON_WEBSITE = 0;
	
	public static Context sContext = null;
	public static Context getContext() { return sContext; }

	// Indication whether to clear the timer that restarts the app or not
	private boolean shouldClearRestarTimerOnDestroy = true;
	
	private boolean rootAccess;
	private boolean busy;
	private Handler timer;
	private Handler resultPublisher;
	private Job currentJob;
	
	private Runnable pollingRunnable = new Runnable() {
		public void run() {
			if (JobManager.getInstance().isPollingEnabled()) {
				Log.i(BZ_AGENT, "**** Polling is enabled ****");
				
				if (!busy) {
					Log.i(BZ_AGENT, "**** Not busy -- calling pollNow ****");
					pollNow();
				}
				
				if (timer != null) {
					timer.postDelayed(this, SettingsUtil.getPollingFrequency(getBaseContext()) * 1000);
				}
				else {
					Log.i(BZ_AGENT, "**** Timer died, restarting it ****");
					timer = new Handler();
					timer.postDelayed(this, SettingsUtil.getPollingFrequency(getBaseContext()) * 1000);
				}
			}
		}
	};
     
	/** Called when the activity is first created. */
	@Override
	public void onCreate(Bundle savedInstanceState) 
	{
		super.onCreate(savedInstanceState);
		
		Log.i(BZ_AGENT, "**** Creating the AgentActivity");
		
		// Allow the context to be statically reachable
		sContext = getBaseContext();		
		
		setupCrashRecovery();
		
		setContentView(R.layout.main);

		resultPublisher = new Handler();
		JobManager manager = JobManager.getInstance();
		manager.addListener(this);
		manager.setContext(getBaseContext());
		
		// Make sure we have super user access
		rootAccess = ProcessManager.getInstance().testRootPermissions();

		Button pollNowButton = (Button) findViewById(R.id.pollButton);
		pollNowButton.setOnClickListener(new OnClickListener() {
			public void onClick(View v) {
				Log.i(BZ_AGENT, "**** Poll now pressed");
				pollNow();
			}
		});
		
		if (SettingsUtil.getShouldAutopollOnLaunch(getBaseContext())) {
			startPolling();
		}
	}
	
	private void setupCrashRecovery() 
	{
		final PendingIntent intent = getRestartIntent();
		Thread.setDefaultUncaughtExceptionHandler(new Thread.UncaughtExceptionHandler() {
			
			public void uncaughtException(Thread thread, Throwable ex) 
			{
				Log.e(BZ_AGENT, "**** Crashed with uncaught exception, setting time to restart", ex);
				AlarmManager mgr = (AlarmManager) getSystemService(Context.ALARM_SERVICE);
				mgr.set(AlarmManager.RTC_WAKEUP, System.currentTimeMillis() + 30000, intent);
				System.exit(2);
			}
		});
		
		// Create an alarm that will rerun the agent every 5 minutes, 
		// since the exception doesn't always catch (no harm in running it twice)
		Log.i(BZ_AGENT, "**** BZAgent setting repeat rerun timer");
		AlarmManager mgr = (AlarmManager) getSystemService(Context.ALARM_SERVICE);
		int interval = 5*60*1000; // 5 minutes
		mgr.setRepeating(AlarmManager.RTC_WAKEUP, 
				System.currentTimeMillis() + interval,interval, intent);
		
		shouldClearRestarTimerOnDestroy = true;
	}

	private PendingIntent getRestartIntent() 
	{
		// Setup the exception handler to rerun the agent 10 seconds after
		final PendingIntent intent = PendingIntent.getActivity(getBaseContext(), 
				PendingIntent.FLAG_UPDATE_CURRENT,
	            new Intent(getIntent()), getIntent().getFlags());
		return intent;
	}

	@Override
	protected void onDestroy() 
	{
		JobManager manager = JobManager.getInstance();
		manager.removeListener(this);

		if (timer != null) {
			Log.i(BZ_AGENT, "Agent Destroying");
			timer.removeCallbacks(pollingRunnable);
			timer = null;
		}

		if (shouldClearRestarTimerOnDestroy) 
		{
			// Clear the timer rerunning this app
			Log.i(BZ_AGENT, "**** BZAgent Cancelling repeat rerun timer");
			final PendingIntent intent = getRestartIntent();
			AlarmManager mgr = (AlarmManager) getSystemService(Context.ALARM_SERVICE);
			mgr.cancel(intent);
		}
		
		super.onDestroy();
	}
	
	@Override
	protected void onActivityResult(final int requestCode, final int resultCode, final Intent data) {
		if (requestCode == GATHER_METRICS_ON_WEBSITE) {
			if (resultCode == RESULT_CANCELED) {
				Log.w(BZ_AGENT, "Cancelled");
			}
			else if (resultCode == RESULT_OK) {
				//Let the activity finish, then post the result
				resultPublisher.postDelayed(new Runnable() {
					public void run() {
						((ImageView)findViewById(R.id.statusImage)).setImageResource(R.drawable.upload);
						((TextView)findViewById(R.id.statusLabel)).setText(R.string.status_uploading);
						packageUpResults();
					}
				}, 500);
			}
		}
		else {
			super.onActivityResult(requestCode, resultCode, data);
		}
	}

	/**
	 * Polls immediately for jobs
	 */
	public void pollNow() {
		//Always update this flag on rootAccess.  We do this to avoid the Toast that appears whenever a you gain root permissions so that it's not recorded at all.
		rootAccess = ProcessManager.getInstance().testRootPermissions();
		if (rootAccess) {
			runOnUiThread(new Runnable() {
				public void run() {
					((ImageView)findViewById(R.id.statusImage)).setImageResource(R.drawable.polling);
					((TextView)findViewById(R.id.statusLabel)).setText(R.string.status_polling);
				}
			});
			try {
				JobManager.getInstance().pollForJobs(SettingsUtil.getLocation(getBaseContext()), SettingsUtil.getLocationKey(getBaseContext()), SettingsUtil.getUniqueName(getBaseContext()));
			} catch(Exception ex) { 
				Log.w(BZ_AGENT, "Failed to poll for jobs", ex);
			}
		}
		else {
			Log.i(BZ_AGENT, "**** No root access setting busy to false");
			showNoRootError();
			busy = false;
		}
	}
	
	/**
	 * Enables polling timer that, if the agent is not busy, will poll every N seconds where N is defined in settings.
	 */
	public void startPolling() {
		if (rootAccess) {
			JobManager.getInstance().setPollingEnabled(true);
			
			//User a handler here, Timers (unlike on a Sun/Oracle VM) do not fire on the event dispatching thread, but on a background process.
			//In other words, we can't update the UI from a background thread.  It'll just explode.
			timer = new Handler();
			timer.postDelayed(pollingRunnable, 1000);
		}
		else {
			Log.i(BZ_AGENT, "**** No root access; cannot start polling");
			showNoRootError();
		}
		
		update();
	}
	
	/**
	 * Disables polling and destroys the timer
	 */
	public void stopPolling() {
		Log.i(BZ_AGENT, "**** stopPolling called");
		
		JobManager.getInstance().setPollingEnabled(false);
		
		if (timer != null) {
			timer.removeCallbacks(pollingRunnable);
			timer = null;
		}
		
		update();
	}
	
	public void update() {
		runOnUiThread(new Runnable() {
			public void run() {
				if (JobManager.getInstance().isPollingEnabled()) {
					((ImageView)findViewById(R.id.statusImage)).setImageResource(R.drawable.waiting);
					((TextView)findViewById(R.id.statusLabel)).setText(R.string.status_enabled);
				}
				else {
					((ImageView)findViewById(R.id.statusImage)).setImageResource(R.drawable.disabled);
					((TextView)findViewById(R.id.statusLabel)).setText(R.string.status_disabled);
				}
			}
		});
	}

	@Override
	public boolean onPrepareOptionsMenu(Menu menu) {
		if (JobManager.getInstance().isPollingEnabled()) {
			menu.findItem(R.id.polling_menu_item).setVisible(false);
			menu.findItem(R.id.stop_polling_menu_item).setVisible(true);
		}
		else {
			menu.findItem(R.id.polling_menu_item).setVisible(true);
			menu.findItem(R.id.stop_polling_menu_item).setVisible(false);
		}
		return super.onPrepareOptionsMenu(menu);
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		MenuInflater inflater = getMenuInflater();
		inflater.inflate(R.menu.agentmenu, menu);
		return true;
	}

	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		// Handle item selection
		boolean handled = false;
		switch (item.getItemId()) {
		case R.id.settings_menu_item:
			Intent intent = new Intent("com.blaze.android.agent.SETTINGS");
			startActivity(intent);
			handled = true;
			break;
		case R.id.polling_menu_item:
			startPolling();
			handled = true;
			break;
		case R.id.stop_polling_menu_item:
			Log.i(BZ_AGENT, "**** Stop polling from menu selected");
			stopPolling();
			handled = true;
			break;
		default:
			handled = super.onOptionsItemSelected(item);
		}
		return handled;
	}

	public void showNoRootError() {
		Builder builder = new AlertDialog.Builder(this);
		builder.setTitle("Root Access");
		builder.setMessage("Unable to obtain root access.  Make sure you are on a rooted device and you allow root access.  If you've denied, you can open 'Superuser' to fix.");
		builder.setNegativeButton("Dismiss", null);
		builder.show();
	}
	
	public void jobListUpdated(boolean isListEmpty) {
		if (isListEmpty) {
			Log.i(BZ_AGENT, "Job list updated but no jobs available");
			update();
		}
		else {
			Log.i(BZ_AGENT, "Job list updated, starting job");
			
			((ImageView)findViewById(R.id.statusImage)).setImageResource(R.drawable.waiting);
			((TextView)findViewById(R.id.statusLabel)).setText("Processing"); //TODO: Move this to strings
			
			currentJob = JobManager.getInstance().peekJob();
			if (currentJob != null) {
				busy = true;
				startActivityForResult(new Intent("com.blaze.android.agent.JOB"), GATHER_METRICS_ON_WEBSITE);
			}
			else {
				Log.i(BZ_AGENT, "No job in job list, cancelling");
			}
		}
	}

	public void failedToFetchJobs(String reason) {
		Log.i(BZ_AGENT, "Failed to fetch jobs: " + reason);
		TextView statusLabel = (TextView) findViewById(R.id.statusLabel);
		if (statusLabel != null) {
			((ImageView)findViewById(R.id.statusImage)).setImageResource(R.drawable.disabled);
			statusLabel.setText(reason);
		}
	}
	
	private void packageUpResults() {
		Log.i(BZ_AGENT, "Packaging up results for job: " + currentJob.getJobId());
		
		new Thread(new Runnable() {
			private void WriteHarToFile(File harFile) {
				//The first step is to write the results.har
				JSONObject result = currentJob.getResult().getJsonRepresentation();
				
				BufferedWriter writer = null;
				try {
					if (harFile.createNewFile()) {
						writer = new BufferedWriter(new FileWriter(harFile));
						//Unfortunately we can't simply call 'result.toString()'; we need to write this efficiently.
						  //writer.write(result.toString());
						JSONUtil.writeJSONObject(writer, result);
					}
					else {
						Log.e(BZ_AGENT, "Could not create results.har");
					}
				}
				catch (JSONException e) {
					Log.e(BZ_AGENT, "Could not serialize JSON", e);
				}
				catch (IOException e) {
					Log.e(BZ_AGENT, "Could not create results.har", e);
				}
				catch (OutOfMemoryError e) {
					Log.e(BZ_AGENT, "Failed to save the har, out of memory", e);
				}
				finally {
					if (writer != null) {
						try {
							writer.close();
						}
						catch (Exception e) {
							//Swallow
						}
						finally {
							writer = null;
						}
					}
				}
			}
			
			public void run() {
				// If we are doing HAR creation locally, the first step is to write
				// the results.har file.
				if (!SettingsUtil.getShouldProcessHarsOnServer(getBaseContext())) {
					File harFile = new File(SettingsUtil.getJobBasePath(getBaseContext()) + "results.har");
					WriteHarToFile(harFile);
				}
				
				//Now that we have the JSON, we need to get the proper screenshots
				for (Run run : currentJob.getResult().getRuns()) {
					saveDocumentCompleteScreenshot(run);
				}
				
				//Now create the avisynth files
				for (Run run : currentJob.getResult().getRuns()) {
					Log.i(BZ_AGENT, "Creating Avisynth file for run: " + run.getIdentifier());
					AVSUtil.createAvisynthFile(run, run.getVideoFolder(), SettingsUtil.getFps(getBaseContext()));
				}
				
				runOnUiThread(new Runnable() {
					public void run() {
						completePackageAndShip();
					}
				});
			}
		}).start();
	}

	private void completePackageAndShip() 
	{
		// Always exclude the pcap files (since we have them zipped)
		String excludePatStr = ".*\\.pcap(.zip)?$";
		if (currentJob.shouldCaptureTcpdump()) {
			// If not uploading the pcap data, exclude the zip files too
			excludePatStr = ".*\\.pcap$";
		}
		Pattern excludePat = Pattern.compile(excludePatStr);
		
		File zipFile = new File(SettingsUtil.getZipPath(getBaseContext()) + currentJob.getJobId() + "-results.zip");
		String basePath = SettingsUtil.getJobBasePath(getBaseContext());
		boolean zipSucc = ZipUtil.zipFile(zipFile, basePath, basePath, excludePat);
		if (zipSucc) {
			JobManager.getInstance().publishResults(currentJob.getJobId(), SettingsUtil.getLocation(getBaseContext()), SettingsUtil.getLocationKey(getBaseContext()), zipFile);
		} else {
			Log.e(BZ_AGENT, "Failed to create results zip");
			publishFailed("Failed to publish results");
		}
	}
	
	private void restartIfNeeded() 
	{
		// If asked, and polling is enabled, restart the app
		if (SettingsUtil.getShouldRestartBetweenJobs(getBaseContext()) && JobManager.getInstance().isPollingEnabled())
		{
			final PendingIntent intent = getRestartIntent();

			Log.e(BZ_AGENT, "**** Restarting agent after job");
			AlarmManager mgr = (AlarmManager) getSystemService(Context.ALARM_SERVICE);
			mgr.set(AlarmManager.RTC_WAKEUP, System.currentTimeMillis() + 3000, intent);
			shouldClearRestarTimerOnDestroy = false;
			System.exit(3);
		}
	}

	/**
	 * Fetch the 'doc complete' image from the pile of screenshots that we took
	 * while recording the video.
	 * 
	 * This will simply not do anything if 
	 * @param run
	 */
	private void saveDocumentCompleteScreenshot(Run run) {
		long documentCompleteTime = run.getDocComplete();
		List<Run.ScreenshotInfo> screenshots = run.getScreenshotPaths();
		
		if (screenshots != null && screenshots.size() > 0) {
			boolean screenshotFound = false;
			
			//First find the 'best fit' screenshot
			String path = null;
			for (int i=0; i<screenshots.size(); ++i) 
			{
				if (screenshots.get(i).getTimestamp() > documentCompleteTime) {
					path = screenshots.get(i).getPath();
					screenshotFound = true;
					break;
				}
			}
			
			//If we didn't find anything, use the last screenshot instead
			if (!screenshotFound) {
				path = screenshots.get(screenshots.size() - 1).getPath();
			}
			
			//Now copy it to the base folder of the run.
			String docCompletePath = run.getBaseFolder();
			if (run.isFirstView()) {
				docCompletePath += run.getRunNumber() + "_screen_doc.jpg";
			}
			else {
				docCompletePath += run.getRunNumber() + "_Cached_screen_doc.jpg";
			}
			
			try {
				copyFile(new File(path), new File(docCompletePath));
			}
			catch (IOException e) {
				Log.w(BZ_AGENT, "Could not write doc complete image from: " + path + " to: " + docCompletePath);
			}
		}
	}
	
	/**
	 * Copies a file from in to out
	 * 
	 * @param in
	 * @param out
	 * @throws IOException
	 */
	private static void copyFile(File in, File out) throws IOException {
		FileInputStream fis = null;
		FileOutputStream fos = null;
		FileChannel inChannel = null;
		FileChannel outChannel = null;
		try {
			fis = new FileInputStream(in);
			inChannel = fis.getChannel();
			
			fos = new FileOutputStream(out);
			outChannel = fos.getChannel();
			
			inChannel.transferTo(0, inChannel.size(), outChannel);
		} 
		catch (IOException e) {
			throw e;
		}
		finally {
			if (fis != null) {
				try {
					fis.close();
				}
				catch (Exception e) {}
			}
			
			if (fos != null) {
				try {
					fos.close();
				}
				catch (Exception e) {}
			}
			
			if (inChannel != null) {
				try {
					inChannel.close();
				}
				catch (Exception e) {}
			}
			
			if (outChannel != null) {
				try {
					outChannel.close();
				}
				catch (Exception e) {}
			}
		}
    }

	
	public void publishSucceeded() {
		Log.i(BZ_AGENT, "**** Publish Succeeded - Setting busy to false");
		update();
		
		restartIfNeeded();
		
		busy = false;
	}
	
	public void publishFailed(String reason) {
		Log.i(BZ_AGENT, "**** Publish failed " + null + " - Setting busy to false");
		
		restartIfNeeded();
		
		busy = false;
		((ImageView)findViewById(R.id.statusImage)).setImageResource(R.drawable.disabled);
		((TextView)findViewById(R.id.statusLabel)).setText(reason);
	}
}