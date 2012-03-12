/*
 * Blaze Android Agent
 * 
 * Copyright Blaze 2010
 */
package com.blaze.android.agent.views;

import android.content.Context;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.widget.LinearLayout;

/**
 * Basic view for displaying a WebView.
 * 
 * @author Joshua Tessier
 */
public class BrowserView extends LinearLayout {
	private WebView webView;
	
	public BrowserView(Context context) {
		super(context);
		
		setOrientation(LinearLayout.VERTICAL);
		webView = new WebView(context);
		WebSettings settings = webView.getSettings();
		settings.setSupportZoom(true);
		settings.setJavaScriptEnabled(true);
		settings.setBuiltInZoomControls(true);
		settings.setUseWideViewPort(true);
		webView.setScrollBarStyle(WebView.SCROLLBARS_INSIDE_OVERLAY);
		webView.setInitialScale(1);
		webView.setLayoutParams(new LayoutParams(LayoutParams.FILL_PARENT, LayoutParams.FILL_PARENT));
		webView.setKeepScreenOn(true);
		addView(webView);
		
		setLayoutParams(new LayoutParams(LayoutParams.FILL_PARENT, LayoutParams.WRAP_CONTENT));
	}

	public WebView getWebView() {
		return webView;
	}
}
