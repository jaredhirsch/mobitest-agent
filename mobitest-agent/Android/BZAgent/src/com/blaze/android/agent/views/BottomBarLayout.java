package com.blaze.android.agent.views;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Paint.Style;
import android.graphics.Shader;
import android.util.AttributeSet;
import android.widget.LinearLayout;

import com.blaze.android.agent.R;

public class BottomBarLayout extends LinearLayout {
	private static final int BOTTOM_BAR_HEIGHT = 15;
	private static final int BOTTOM_BAR_SHADOW_HEIGHT = 8;
	private Paint paint;
	private Bitmap logo;
	
	public BottomBarLayout(Context context, AttributeSet attrs) {
		super(context, attrs);
		paint = new Paint();
		paint.setAntiAlias(true);
		
		logo = BitmapFactory.decodeResource(getResources(), R.drawable.blaze_logo);
	}

	@Override
	protected void onDraw(Canvas canvas) {
		super.onDraw(canvas);
		int height = getHeight();
		int width = getWidth();
		if (height > width) {
			float leftSide = ((width - logo.getWidth()) * 0.5f);
			float top = height - BOTTOM_BAR_HEIGHT - BOTTOM_BAR_SHADOW_HEIGHT - 5 - logo.getHeight();
			canvas.drawBitmap(logo, leftSide, top, paint);
			
			Paint gradientPaint = new Paint();
			float[] positions = {0.0f, 0.6f, 1.0f};
			int[] colors = { 0x0, 0x30000000, 0x89000000 };
			gradientPaint.setShader(new LinearGradient(0, height - BOTTOM_BAR_HEIGHT - BOTTOM_BAR_SHADOW_HEIGHT, 0, height - BOTTOM_BAR_HEIGHT, colors, positions, Shader.TileMode.CLAMP));
		    canvas.drawPaint(gradientPaint);
			
			paint.setColor(0xFFE06F1C);
			paint.setStyle(Style.FILL);
			canvas.drawRect(0, height - BOTTOM_BAR_HEIGHT, getWidth(), height, paint);
		}
	}
}
