/*
 * Blaze Android Agent
 * 
 * Copyright Blaze 2010
 */
package com.blaze.android.agent.managers;

/**
 * Listener for job updates
 * 
 * @author Joshua Tessier
 */
public interface JobListener {
	public void jobListUpdated(boolean isListEmpty);
	public void failedToFetchJobs(String reason);
	public void publishSucceeded();
	public void publishFailed(String reason);
}
