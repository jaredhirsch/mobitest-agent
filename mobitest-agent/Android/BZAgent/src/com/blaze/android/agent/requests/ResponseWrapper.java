/*
 * Blaze Android Agent
 * 
 * Copyright Blaze 2010
 */
package com.blaze.android.agent.requests;

import org.apache.http.HttpResponse;
import org.apache.http.client.methods.HttpUriRequest;

/**
 * Callback vehicle for Responses
 * 
 * @author Joshua Tessier
 */
public class ResponseWrapper implements Runnable {
	private ResponseListener listener;
	private HttpUriRequest request;
	private HttpResponse response;
	private boolean success;
	private String failureReason;
	private String extraInfo;
	
	public ResponseWrapper(HttpUriRequest request, HttpResponse response, ResponseListener listener, String extraInfo) {
		this.request = request;
		this.response = response;
		this.listener = listener;
		this.success = true;
		this.extraInfo = extraInfo;
	}
	
	public ResponseWrapper(HttpUriRequest request, String failureReason, ResponseListener listener, String extraInfo) {
		this.request = request;
		this.failureReason = failureReason;
		this.listener = listener;
		this.success = false;
		this.extraInfo = extraInfo;
	}
 
	public void run() {
		if (listener != null) {
			if (success) {
				listener.responseReceived(request, response, extraInfo);
			}
			else {
				listener.requestFailed(request, failureReason, extraInfo);
			}
		}
	}
}
