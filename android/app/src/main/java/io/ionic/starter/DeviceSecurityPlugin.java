package com.softing.photo;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import com.google.android.play.core.integrity.IntegrityManager;
import com.google.android.play.core.integrity.IntegrityManagerFactory;
import com.google.android.play.core.integrity.IntegrityTokenRequest;
import com.google.android.play.core.integrity.IntegrityTokenResponse;
import com.google.android.gms.tasks.Task;

import android.app.Activity;
import android.os.Build;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.TimeZone;

@CapacitorPlugin(name = "DeviceSecurity")
public class DeviceSecurityPlugin extends Plugin {

    // MARK: - Check Device Integrity (manual checks only)

    @PluginMethod
    public void checkDeviceIntegrity(PluginCall call) {
        DeviceIntegrityChecker.IntegrityResult result =
            DeviceIntegrityChecker.performAllChecks(getContext());

        JSObject ret = new JSObject();
        ret.put("isRooted", result.isRooted);
        ret.put("isJailbroken", result.isRooted); // Alias for cross-platform compatibility
        ret.put("isEmulator", result.isEmulator);
        ret.put("isDebugged", result.isDebugged);
        ret.put("isDeveloperModeEnabled", result.isDeveloperModeEnabled);
        ret.put("isSecure", result.isSecure);

        com.getcapacitor.JSArray reasons = new com.getcapacitor.JSArray();
        for (String reason : result.failureReasons) {
            reasons.put(reason);
        }
        ret.put("failureReasons", reasons);

        call.resolve(ret);
    }

    // MARK: - Attest Device (Play Integrity API)

    @PluginMethod
    public void attestDevice(PluginCall call) {
        try {
            IntegrityManager integrityManager = IntegrityManagerFactory.create(getContext());

            // Generate a nonce for this request
            String nonce = UUID.randomUUID().toString();

            Task<IntegrityTokenResponse> integrityTokenResponse = integrityManager
                .requestIntegrityToken(
                    IntegrityTokenRequest.builder()
                        .setNonce(nonce)
                        .build()
                );

            integrityTokenResponse
                .addOnSuccessListener(response -> {
                    String token = response.token();
                    JSObject ret = new JSObject();
                    ret.put("success", true);
                    ret.put("error", "");
                    ret.put("token", token);
                    call.resolve(ret);
                })
                .addOnFailureListener(e -> {
                    JSObject ret = new JSObject();
                    ret.put("success", false);
                    ret.put("error", "Play Integrity failed: " + e.getMessage());
                    ret.put("token", "");
                    call.resolve(ret);
                });

        } catch (Exception e) {
            JSObject ret = new JSObject();
            ret.put("success", false);
            ret.put("error", "Play Integrity unavailable: " + e.getMessage());
            ret.put("token", "");
            call.resolve(ret);
        }
    }

    // MARK: - Is Secure (combined: manual checks + Play Integrity)

    @PluginMethod
    public void isSecure(PluginCall call) {
        DeviceIntegrityChecker.IntegrityResult integrityResult =
            DeviceIntegrityChecker.performAllChecks(getContext());

        try {
            IntegrityManager integrityManager = IntegrityManagerFactory.create(getContext());
            String nonce = UUID.randomUUID().toString();

            Task<IntegrityTokenResponse> integrityTokenResponse = integrityManager
                .requestIntegrityToken(
                    IntegrityTokenRequest.builder()
                        .setNonce(nonce)
                        .build()
                );

            integrityTokenResponse
                .addOnSuccessListener(response -> {
                    boolean overallSecure = integrityResult.isSecure; // Play Integrity succeeded
                    List<String> allReasons = integrityResult.failureReasons;

                    resolveSecurityResult(call, overallSecure, integrityResult,
                        true, "", allReasons);
                })
                .addOnFailureListener(e -> {
                    List<String> allReasons = new ArrayList<>(integrityResult.failureReasons);
                    allReasons.add("Play Integrity failed: " + e.getMessage());

                    resolveSecurityResult(call, false, integrityResult,
                        false, e.getMessage(), allReasons);
                });

        } catch (Exception e) {
            List<String> allReasons = new ArrayList<>(integrityResult.failureReasons);
            allReasons.add("Play Integrity unavailable: " + e.getMessage());

            resolveSecurityResult(call, false, integrityResult,
                false, e.getMessage(), allReasons);
        }
    }

    // MARK: - Screenshot Detection

    @PluginMethod
    public void enableScreenshotDetection(PluginCall call) {
        // On Android, FLAG_SECURE in MainActivity prevents screenshots at the window level.
        // On Android 14+ (API 34), we can also detect screenshot attempts via ScreenCaptureCallback.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            Activity activity = getActivity();
            if (activity != null) {
                try {
                    activity.registerScreenCaptureCallback(
                        activity.getMainExecutor(),
                        () -> {
                            JSObject data = new JSObject();
                            SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US);
                            sdf.setTimeZone(TimeZone.getTimeZone("UTC"));
                            data.put("timestamp", sdf.format(new Date()));
                            notifyListeners("screenshotDetected", data);
                        }
                    );
                } catch (Exception e) {
                    // Silently fail - FLAG_SECURE still prevents screenshots
                }
            }
        }

        JSObject ret = new JSObject();
        ret.put("enabled", true);
        call.resolve(ret);
    }

    private void resolveSecurityResult(PluginCall call, boolean secure,
            DeviceIntegrityChecker.IntegrityResult integrityResult,
            boolean attestSuccess, String attestError, List<String> allReasons) {

        JSObject ret = new JSObject();
        ret.put("secure", secure);

        JSObject integrityCheck = new JSObject();
        integrityCheck.put("isJailbroken", integrityResult.isRooted);
        integrityCheck.put("isEmulator", integrityResult.isEmulator);
        integrityCheck.put("isDebugged", integrityResult.isDebugged);
        integrityCheck.put("isDeveloperModeEnabled", integrityResult.isDeveloperModeEnabled);
        ret.put("integrityCheck", integrityCheck);

        JSObject attestation = new JSObject();
        attestation.put("success", attestSuccess);
        attestation.put("error", attestError != null ? attestError : "");
        ret.put("attestation", attestation);

        com.getcapacitor.JSArray reasons = new com.getcapacitor.JSArray();
        for (String reason : allReasons) {
            reasons.put(reason);
        }
        ret.put("failureReasons", reasons);

        call.resolve(ret);
    }
}
