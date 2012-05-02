/*
 * Blaze Android Agent
 * 
 * Copyright Blaze 2010
 */
package com.blaze.android.agent.requests;

import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.UnknownHostException;

import org.apache.http.HttpResponse;
import org.apache.http.client.ClientProtocolException;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpUriRequest;

import com.blaze.android.agent.AgentActivity;

import android.content.Context;
import android.net.wifi.WifiManager;
import android.os.Handler;
import android.util.Log;

/**
 * Asynchronous request vehicle.  Create and run to fire the request.
 * 
 * @author Joshua Tessier
 *
 */
public class AsyncRequest implements Runnable 
{
	private static final String BZ_ASYNC_REQUEST = "BZ-AsyncRequest";
	
	private HttpUriRequest request;
	private ResponseListener listener;
	private HttpClient client;
	private Handler handler;
	private String extraInfo;
	private File outFile;
	
	public AsyncRequest(HttpUriRequest request, ResponseListener listener, HttpClient client, Handler handler, String extraInfo, File outFile) {
		this.client = client;
		this.request = request;
		this.listener = listener;
		this.handler = handler;
		this.extraInfo = extraInfo;
		this.outFile = outFile;
	}
	
	public void run() 
	{
		HttpResponse response;
		boolean success = false;
		String failureReason = null;
		
		if (request != null) 
		{
			int nRetries = 3;
			for(int i=0; i<nRetries; i++)
			{
				try {
					synchronized (client) {
						response = client.execute(request);
						if (!(response == null || handler == null)) 
						{
							// If we got an output stream, write all the content to it
							writeOutput(response);
							handler.post(new ResponseWrapper(request, response, listener, extraInfo));
							success = true;
						}
					}
				}
				catch (IllegalStateException e) {
					failureReason = "Invalid URL";
					Log.e(BZ_ASYNC_REQUEST, "Invalid URL");
				}
				catch (ClientProtocolException e) {
					failureReason = e.getMessage();
					Log.e(BZ_ASYNC_REQUEST, "Request failed", e);
				}
				catch (IOException e) {
					if (e instanceof UnknownHostException) {
						failureReason = "Bad URL or no internet";
					}
					else {
						failureReason = e.getMessage();
					}
					Log.e(BZ_ASYNC_REQUEST, "Request failed", e);
				}
				catch (Throwable t) {
					failureReason = "Unknown error occured";
					Log.e(BZ_ASYNC_REQUEST, "Unknown error", t);
				}

				// If we succeeded, break (no need for retries)
				if (success)
					break;
				
				// Request failed, turn wifi off/on.
				//setWifiMode(false);
				//setWifiMode(true);
			}
			if (!success && handler != null) {
				Log.e(BZ_ASYNC_REQUEST, String.format("Final failure for request to URL %s",request.getURI().toString()));
				handler.post(new ResponseWrapper(request, failureReason, listener, extraInfo));
			}
		}
	}
	
	private void writeOutput(HttpResponse response) throws IOException 
	{
		if (outFile == null)
			return;

		InputStream is = null;
		FileOutputStream fos = null;
		BufferedOutputStream bos = null;
		try 
		{
			fos = new FileOutputStream(outFile);
			bos = new BufferedOutputStream(fos, 8096);
			is = response.getEntity().getContent();
			
			Log.i(BZ_ASYNC_REQUEST, "Writing output to passed output stream");
			byte[] buffer = new byte[4096];
			int count = 0;
			int totalBytes = 0;
			while ((count = is.read(buffer)) != -1) {
				bos.write(buffer, 0, count);
				totalBytes += count;
			}
			Log.i(BZ_ASYNC_REQUEST, "Wrote data to output stream, total bytes: " + totalBytes);
		}
		finally 
		{
			if (bos != null) {
				try {
					bos.close();
				}
				catch (IOException e) {
					Log.e(BZ_ASYNC_REQUEST, "Failed to close the buffered output stream", e);
				}
			}
			
			if (fos != null) {
				try {
					fos.close();
				}
				catch (IOException e) {
					Log.e(BZ_ASYNC_REQUEST, "Failed to close the output stream", e);
				}
			}
			
			if (is != null) {
				try {
					is.close();
				}
				catch (IOException e) {
					Log.e(BZ_ASYNC_REQUEST, "Failed to close the input stream");
				}
			}
		}
	}

	public static void setWifiMode(boolean enabled)
	{
		Context context = AgentActivity.getContext();
		WifiManager wifiMgr = (WifiManager)context.getSystemService(Context.WIFI_SERVICE);

		Log.i(BZ_ASYNC_REQUEST, (enabled?"enabling":"disabling") + " wifi");
		wifiMgr.setWifiEnabled(enabled);

		// Wait for the change to take effect
		try { 
			Thread.sleep(5000);
		}catch(InterruptedException ex) {
			Log.w(BZ_ASYNC_REQUEST, "Got interrupted while waiting for wifi mode toggle", ex);
		}
	}
}
