package com.blaze.android.agent.managers;

import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;

import org.apache.http.HttpEntity;
import org.apache.http.HttpRequest;
import org.apache.http.HttpResponse;

import android.util.Log;

import com.blaze.android.agent.WebActivity;
import com.blaze.android.agent.requests.ResponseListener;

public class Pcap2HarResponseListener implements ResponseListener 
{
	private static final String BZ_PCAP_2_HAR = "BZ-Pcap2Har";
	
	private WebActivity activity = null;
	private String harPath = null;
	public Pcap2HarResponseListener(WebActivity activity, String harPath) { 
		this.activity = activity; 
		this.harPath = harPath;
	}

	public void responseReceived(HttpRequest request, HttpResponse response,
			String extraInfo) 
	{
		int statusCode = response.getStatusLine().getStatusCode();
		if (statusCode != 200) {
			//Only log this, we consume anyway to make sure that the connection closes.
			Log.w(BZ_PCAP_2_HAR, "Failed to get har file from pcap [Status code:" + statusCode + "]");
		}
		
		Log.i(BZ_PCAP_2_HAR, "Received a response from pcap2har (" + request.getRequestLine() + ") [Status Code: " + statusCode + "]");
		
		activity.processNextRunResult();
	}

	public void requestFailed(HttpRequest request, String reason, String extraInfo) 
	{
		Log.w(BZ_PCAP_2_HAR, "Failed to get har file from pcap [Reason:" + reason + ", extra info: " + extraInfo +"]");
		activity.processNextRunResult();
	}

}
