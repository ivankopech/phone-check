package com.softing.photo;

import android.os.Bundle;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.graphics.Color;
import android.graphics.Typeface;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.WindowManager;

import com.getcapacitor.BridgeActivity;

import java.util.List;

public class MainActivity extends BridgeActivity {

    private static final int BLOCKING_VIEW_ID = 99999;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        // Register the security plugin before super.onCreate
        registerPlugin(DeviceSecurityPlugin.class);

        // Prevent screenshots and screen recording (content appears black)
        getWindow().setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        );

        super.onCreate(savedInstanceState);

        // Run security checks immediately
        performSecurityCheck();
    }

    @Override
    public void onResume() {
        super.onResume();
        // Re-check security when app comes to foreground
        performSecurityCheck();
    }

    private void performSecurityCheck() {
        DeviceIntegrityChecker.IntegrityResult result =
            DeviceIntegrityChecker.performAllChecks(this);

        if (!result.isSecure) {
            showBlockingScreen(result.failureReasons);
        } else {
            removeBlockingScreen();
        }
    }

    private void showBlockingScreen(List<String> reasons) {
        // Remove existing blocking view if present
        removeBlockingScreen();

        // Create blocking overlay
        FrameLayout overlay = new FrameLayout(this);
        overlay.setId(BLOCKING_VIEW_ID);
        overlay.setBackgroundColor(Color.WHITE);
        overlay.setClickable(true);
        overlay.setFocusable(true);
        overlay.setElevation(1000f);

        // Content container
        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setGravity(Gravity.CENTER);
        int padding = dpToPx(32);
        content.setPadding(padding, padding, padding, padding);

        FrameLayout.LayoutParams contentParams = new FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.CENTER
        );
        content.setLayoutParams(contentParams);

        // Shield icon (using text as fallback since we don't have SF Symbols on Android)
        TextView iconText = new TextView(this);
        iconText.setText("\u26A0"); // Warning symbol
        iconText.setTextSize(TypedValue.COMPLEX_UNIT_SP, 64);
        iconText.setTextColor(Color.parseColor("#EB445A"));
        iconText.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams iconParams = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        );
        iconParams.bottomMargin = dpToPx(24);
        iconText.setLayoutParams(iconParams);
        content.addView(iconText);

        // Title
        TextView title = new TextView(this);
        title.setText("Security Check Failed");
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 24);
        title.setTypeface(null, Typeface.BOLD);
        title.setTextColor(Color.parseColor("#1A1A1A"));
        title.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams titleParams = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        );
        titleParams.bottomMargin = dpToPx(12);
        title.setLayoutParams(titleParams);
        content.addView(title);

        // Subtitle
        TextView subtitle = new TextView(this);
        subtitle.setText("This app cannot run on this device for security reasons.");
        subtitle.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        subtitle.setTextColor(Color.parseColor("#92949C"));
        subtitle.setGravity(Gravity.CENTER);
        subtitle.setLineSpacing(dpToPx(4), 1f);
        LinearLayout.LayoutParams subtitleParams = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        );
        subtitleParams.bottomMargin = dpToPx(24);
        subtitle.setLayoutParams(subtitleParams);
        content.addView(subtitle);

        // Reasons container
        LinearLayout reasonsContainer = new LinearLayout(this);
        reasonsContainer.setOrientation(LinearLayout.VERTICAL);
        reasonsContainer.setBackgroundColor(Color.parseColor("#F4F5F8"));
        int reasonPadding = dpToPx(16);
        reasonsContainer.setPadding(reasonPadding, reasonPadding, reasonPadding, reasonPadding);

        // Round corners using a GradientDrawable
        android.graphics.drawable.GradientDrawable bg = new android.graphics.drawable.GradientDrawable();
        bg.setColor(Color.parseColor("#F4F5F8"));
        bg.setCornerRadius(dpToPx(12));
        reasonsContainer.setBackground(bg);

        LinearLayout.LayoutParams reasonsParams = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        );
        reasonsContainer.setLayoutParams(reasonsParams);

        for (String reason : reasons) {
            TextView reasonText = new TextView(this);
            reasonText.setText("\u2022 " + reason);
            reasonText.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
            reasonText.setTextColor(Color.parseColor("#EB445A"));
            LinearLayout.LayoutParams reasonItemParams = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            );
            reasonItemParams.bottomMargin = dpToPx(4);
            reasonText.setLayoutParams(reasonItemParams);
            reasonsContainer.addView(reasonText);
        }

        content.addView(reasonsContainer);
        overlay.addView(content);

        // Add overlay to the root view
        ViewGroup rootView = (ViewGroup) getWindow().getDecorView().getRootView();
        rootView.addView(overlay, new FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ));
    }

    private void removeBlockingScreen() {
        ViewGroup rootView = (ViewGroup) getWindow().getDecorView().getRootView();
        View blockingView = rootView.findViewById(BLOCKING_VIEW_ID);
        if (blockingView != null) {
            rootView.removeView(blockingView);
        }
    }

    private int dpToPx(int dp) {
        return (int) TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, dp,
            getResources().getDisplayMetrics()
        );
    }
}
