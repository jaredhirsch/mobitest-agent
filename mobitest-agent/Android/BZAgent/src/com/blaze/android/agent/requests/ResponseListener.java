/*
 * Blaze Android Agent
 * 
 * Copyright Blaze 2010
 */
package com.blaze.android.agent.requests;

import org.apache.http.HttpRequest;
import org.apache.http.HttpResponse;

/**
 * Used to inform a client whenever an AsynchronousRequest was fired
 *  
 * @author Joshua Tessier
 */
public interface ResponseListener {
	/**
	 * Receive a response for a specific request
	 * @param request
	 * @param reseponse
	 * @param extraInfo 
	 */
	public void responseReceived(HttpRequest request, HttpResponse reseponse, String extraInfo);
	
	/**
	 * Failed to connect to the specified host
	 * 
	 * @param request
	 */
	public void requestFailed(HttpRequest request, String reason, String extraInfo);
}
