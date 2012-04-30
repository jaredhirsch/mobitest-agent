package com.blaze.android.agent.managers;

import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;

import org.apache.http.HttpEntity;
import org.apache.http.HttpRequest;
import org.apache.http.HttpResponse;
import org.apache.http.entity.mime.MultipartEntity;
import org.apache.http.entity.mime.content.FileBody;

import android.util.Log;

import com.blaze.android.agent.WebActivity;
import com.blaze.android.agent.requests.ResponseListener;

public class Pcap2HarResponseListener implements ResponseListener 
{
	private static final String BZ_PCAP_2_HAR = "BZ-Pcap2Har";
	
	private WebActivity activity = null;
	private String harPath = null;
	private boolean requestIsUsingExperimentalPcap2Har = false;
	private static boolean foo = false;

	public Pcap2HarResponseListener(WebActivity activity, String harPath, boolean requestIsUsingExperimentalPcap2Har)
	{
		this.activity = activity;
		this.harPath = harPath;
		this.requestIsUsingExperimentalPcap2Har = requestIsUsingExperimentalPcap2Har;
	}

	public void responseReceived(HttpRequest request, HttpResponse response,
			String extraInfo) 
	{
		boolean requestFailed = false;
		int statusCode = response.getStatusLine().getStatusCode();
		if (statusCode != 200) {
			// Only log this, we consume anyway to make sure that the connection closes.
			Log.w(BZ_PCAP_2_HAR, "Failed to get har file from pcap [Status code:" + statusCode + "]");
			requestFailed = true;
		}

		Log.i(BZ_PCAP_2_HAR, "Received a response from pcap2har (" + request.getRequestLine() + ") [Status Code: " + statusCode + "]");

		if (requestFailed && requestIsUsingExperimentalPcap2Har) {
			Log.w(BZ_PCAP_2_HAR, "Falling back to stable pcap2har upload.");
			// Start a new request.  true -> The experimental version failed, so fall back to stable.
			activity.startPcap2HarUpload(true);
		} else {
			activity.processNextRunResult();
		}
	}

	public void requestFailed(HttpRequest request, String reason, String extraInfo) 
	{
		Log.w(BZ_PCAP_2_HAR, "Failed to get har file from pcap [Reason:" + reason + ", extra info: " + extraInfo +"]");

		if (requestIsUsingExperimentalPcap2Har) {
			Log.w(BZ_PCAP_2_HAR, "Falling back to stable pcap2har upload.");
			// Start a new request.  true -> The experimental version failed, so fall back to stable.
			activity.startPcap2HarUpload(true);
		} else {
			activity.processNextRunResult();
		}
	}

}
