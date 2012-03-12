/*
 * Blaze Android Agent
 * 
 * Copyright Blaze 2010
 */
package com.blaze.android.agent;

import android.content.SharedPreferences;
import android.content.SharedPreferences.OnSharedPreferenceChangeListener;
import android.os.Bundle;
import android.preference.PreferenceActivity;
import android.preference.PreferenceManager;

/**
 * The <code>SettingsActivity</code> is used to display, edit and validate the preferences for the Blaze Agent.
 * 
 * @author Joshua Tessier
 */
public class SettingsActivity extends PreferenceActivity implements OnSharedPreferenceChangeListener {
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);

		addPreferencesFromResource(R.xml.preferences);
		
		//Register for changes
		SharedPreferences sp = PreferenceManager.getDefaultSharedPreferences(this);
	    sp.registerOnSharedPreferenceChangeListener(this);
	}

	public void onSharedPreferenceChanged(SharedPreferences sharedPreferences, String key) {
		//TODO: Add validation
	}
}
