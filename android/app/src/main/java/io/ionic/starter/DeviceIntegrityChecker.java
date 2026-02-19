package com.softing.photo;

import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Debug;
import android.provider.Settings;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.List;

public class DeviceIntegrityChecker {

    // MARK: - Result Class

    public static class IntegrityResult {
        public final boolean isRooted;
        public final boolean isEmulator;
        public final boolean isDebugged;
        public final boolean isDeveloperModeEnabled;
        public final boolean isSecure;
        public final List<String> failureReasons;

        public IntegrityResult(boolean isRooted, boolean isEmulator, boolean isDebugged,
                               boolean isDeveloperModeEnabled, List<String> failureReasons) {
            this.isRooted = isRooted;
            this.isEmulator = isEmulator;
            this.isDebugged = isDebugged;
            this.isDeveloperModeEnabled = isDeveloperModeEnabled;
            this.failureReasons = failureReasons;
            this.isSecure = !isRooted && !isEmulator && !isDebugged && !isDeveloperModeEnabled;
        }
    }

    // MARK: - Main Check

    public static IntegrityResult performAllChecks(Context context) {
        List<String> rootReasons = new ArrayList<>();
        List<String> emulatorReasons = new ArrayList<>();
        List<String> debugReasons = new ArrayList<>();
        List<String> devModeReasons = new ArrayList<>();

        boolean isRooted = checkRoot(rootReasons);
        boolean isEmulator = checkEmulator(emulatorReasons);
        boolean isDebugged = checkDebugger(context, debugReasons);
        boolean isDeveloperMode = checkDeveloperMode(context, devModeReasons);

        List<String> allReasons = new ArrayList<>();
        allReasons.addAll(rootReasons);
        allReasons.addAll(emulatorReasons);
        allReasons.addAll(debugReasons);
        allReasons.addAll(devModeReasons);

        return new IntegrityResult(isRooted, isEmulator, isDebugged, isDeveloperMode, allReasons);
    }

    // MARK: - Root Detection

    private static boolean checkRoot(List<String> reasons) {
        boolean rooted = false;

        if (checkRootFiles()) {
            reasons.add("Root files detected on device");
            rooted = true;
        }

        if (checkRootPackages()) {
            reasons.add("Root management apps detected");
            rooted = true;
        }

        if (checkSuBinary()) {
            reasons.add("SU binary found");
            rooted = true;
        }

        if (checkRootProperties()) {
            reasons.add("Dangerous system properties detected");
            rooted = true;
        }

        if (checkRWPaths()) {
            reasons.add("System partition is writable");
            rooted = true;
        }

        if (checkBusyBox()) {
            reasons.add("BusyBox binary detected");
            rooted = true;
        }

        return rooted;
    }

    private static boolean checkRootFiles() {
        String[] rootPaths = {
            "/system/app/Superuser.apk",
            "/system/app/SuperSU.apk",
            "/system/app/Superuser",
            "/system/app/SuperSU",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/su/bin/su",
            "/su/bin",
            "/system/xbin/daemonsu",
            "/system/etc/init.d/99telecom",
            "/system/lib/libsqlite.so",
            "/system/xbin/mu",
            "/data/adb/magisk",
            "/data/adb/ksu",
            "/data/adb/ap",
            "/sbin/.magisk",
            "/cache/.disable_magisk",
            "/dev/.magisk.unblock",
            "/system/etc/.installed_su_daemon",
            "/data/user_de/0/com.topjohnwu.magisk",
            "/system/addon.d/99-magisk.sh"
        };

        for (String path : rootPaths) {
            if (new File(path).exists()) {
                return true;
            }
        }
        return false;
    }

    private static boolean checkRootPackages() {
        String[] rootPackages = {
            "com.topjohnwu.magisk",
            "com.koushikdutta.superuser",
            "com.noshufou.android.su",
            "com.noshufou.android.su.elite",
            "eu.chainfire.supersu",
            "com.yellowes.su",
            "com.thirdparty.superuser",
            "com.devadvance.rootcloak",
            "com.devadvance.rootcloakplus",
            "de.robv.android.xposed.installer",
            "com.saurik.substrate",
            "com.zachspong.temprootremovejb",
            "com.amphoras.hidemyroot",
            "com.amphoras.hidemyrootadd",
            "com.formyhm.hiderootPremium",
            "com.formyhm.hideroot",
            "me.phh.superuser",
            "eu.chainfire.supersu.pro",
            "com.kingouser.com",
            "com.android.vending.billing.InAppBillingService.LUCK",
            "io.github.vvb2060.magisk",
            "me.weishu.kernelsu",
            "me.bmax.apatch"
        };

        for (String pkg : rootPackages) {
            File pkgDir = new File("/data/data/" + pkg);
            if (pkgDir.exists()) {
                return true;
            }
        }
        return false;
    }

    private static boolean checkSuBinary() {
        String[] places = {
            "/sbin/su", "/system/bin/su", "/system/xbin/su",
            "/data/local/xbin/su", "/data/local/bin/su",
            "/system/sd/xbin/su", "/system/bin/failsafe/su",
            "/data/local/su", "/su/bin/su"
        };

        for (String path : places) {
            if (new File(path).exists()) {
                return true;
            }
        }

        // Try running su command
        try {
            Process process = Runtime.getRuntime().exec(new String[]{"which", "su"});
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            String line = reader.readLine();
            process.destroy();
            if (line != null && !line.isEmpty()) {
                return true;
            }
        } catch (Exception e) {
            // Ignored - su not found is expected
        }

        return false;
    }

    private static boolean checkRootProperties() {
        try {
            String[] dangerousProps = {
                "ro.debuggable",
                "ro.secure"
            };

            Process process = Runtime.getRuntime().exec("getprop");
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            String line;
            while ((line = reader.readLine()) != null) {
                for (String prop : dangerousProps) {
                    if (line.contains(prop)) {
                        if (line.contains("[ro.debuggable]: [1]")) {
                            return true;
                        }
                        if (line.contains("[ro.secure]: [0]")) {
                            return true;
                        }
                    }
                }
            }
            process.destroy();
        } catch (Exception e) {
            // Ignored
        }
        return false;
    }

    private static boolean checkRWPaths() {
        try {
            Process process = Runtime.getRuntime().exec("mount");
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            String line;
            while ((line = reader.readLine()) != null) {
                if (line.contains("/system") && line.contains("rw")) {
                    if (!line.contains("tmpfs") && !line.contains("rootfs")) {
                        return true;
                    }
                }
            }
            process.destroy();
        } catch (Exception e) {
            // Ignored
        }
        return false;
    }

    private static boolean checkBusyBox() {
        String[] busyboxPaths = {
            "/system/xbin/busybox",
            "/system/bin/busybox",
            "/sbin/busybox",
            "/data/local/bin/busybox",
            "/data/local/xbin/busybox"
        };

        for (String path : busyboxPaths) {
            if (new File(path).exists()) {
                return true;
            }
        }
        return false;
    }

    // MARK: - Emulator Detection

    private static boolean checkEmulator(List<String> reasons) {
        boolean emulator = false;

        // Check Build properties
        if (Build.FINGERPRINT.startsWith("generic") ||
            Build.FINGERPRINT.startsWith("unknown") ||
            Build.FINGERPRINT.contains("google/sdk_gphone") ||
            Build.FINGERPRINT.contains("vbox") ||
            Build.FINGERPRINT.contains("ttVM_Hdragon")) {
            reasons.add("Emulator fingerprint detected");
            emulator = true;
        }

        if (Build.MODEL.contains("google_sdk") ||
            Build.MODEL.contains("Emulator") ||
            Build.MODEL.contains("Android SDK built for x86") ||
            Build.MODEL.contains("sdk_gphone")) {
            reasons.add("Emulator model detected: " + Build.MODEL);
            emulator = true;
        }

        if (Build.MANUFACTURER.contains("Genymotion") ||
            Build.MANUFACTURER.contains("unknown")) {
            reasons.add("Emulator manufacturer detected: " + Build.MANUFACTURER);
            emulator = true;
        }

        if (Build.HARDWARE.contains("goldfish") ||
            Build.HARDWARE.contains("ranchu") ||
            Build.HARDWARE.contains("vbox86") ||
            Build.HARDWARE.equals("nox")) {
            reasons.add("Emulator hardware detected: " + Build.HARDWARE);
            emulator = true;
        }

        if (Build.PRODUCT.contains("sdk") ||
            Build.PRODUCT.contains("emulator") ||
            Build.PRODUCT.contains("vbox86p") ||
            Build.PRODUCT.equals("nox")) {
            reasons.add("Emulator product detected: " + Build.PRODUCT);
            emulator = true;
        }

        if (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic")) {
            reasons.add("Generic emulator brand/device detected");
            emulator = true;
        }

        // Check for emulator-specific files
        String[] emulatorFiles = {
            "/dev/socket/qemud",
            "/dev/qemu_pipe",
            "/system/lib/libc_malloc_debug_qemu.so",
            "/sys/qemu_trace",
            "/system/bin/qemu-props",
            "/dev/socket/genyd",
            "/dev/socket/baseband_genyd",
            "/dev/goldfish_pipe",
            "fstab.nox",
            "fstab.ranchu",
            "init.nox.rc",
            "/sys/devices/virtual/misc/nox"
        };

        for (String path : emulatorFiles) {
            if (new File(path).exists()) {
                reasons.add("Emulator file detected: " + path);
                emulator = true;
                break;
            }
        }

        // Check for QEMU driver
        try {
            Process process = Runtime.getRuntime().exec("getprop ro.kernel.qemu");
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            String line = reader.readLine();
            process.destroy();
            if (line != null && line.trim().equals("1")) {
                reasons.add("QEMU kernel property detected");
                emulator = true;
            }
        } catch (Exception e) {
            // Ignored
        }

        return emulator;
    }

    // MARK: - Debugger Detection

    private static boolean checkDebugger(Context context, List<String> reasons) {
        boolean debugged = false;

        // Check if debugger is connected
        if (Debug.isDebuggerConnected()) {
            reasons.add("Debugger currently connected");
            debugged = true;
        }

        // Check if waiting for debugger
        if (Debug.waitingForDebugger()) {
            reasons.add("Application waiting for debugger");
            debugged = true;
        }

        // Check USB debugging enabled
        try {
            int adbEnabled = Settings.Global.getInt(
                context.getContentResolver(),
                Settings.Global.ADB_ENABLED, 0
            );
            if (adbEnabled == 1) {
                reasons.add("USB debugging (ADB) is enabled");
                debugged = true;
            }
        } catch (Exception e) {
            // Ignored
        }

        // Check if app is debuggable
        if ((context.getApplicationInfo().flags & android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0) {
            reasons.add("Application is built with debuggable flag");
            debugged = true;
        }

        return debugged;
    }

    // MARK: - Developer Mode Detection

    private static boolean checkDeveloperMode(Context context, List<String> reasons) {
        boolean devMode = false;

        try {
            int devEnabled = Settings.Global.getInt(
                context.getContentResolver(),
                Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0
            );
            if (devEnabled == 1) {
                reasons.add("Developer options are enabled");
                devMode = true;
            }
        } catch (Exception e) {
            // Ignored
        }

        return devMode;
    }
}
