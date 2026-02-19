import Foundation
import UIKit
import MachO
import Darwin

// MARK: - Integrity Result

struct IntegrityResult {
    let isJailbroken: Bool
    let isEmulator: Bool
    let isDebugged: Bool
    let isDeveloperModeEnabled: Bool
    let isSecure: Bool
    let failureReasons: [String]
}

// MARK: - Device Integrity Checker

class DeviceIntegrityChecker {

    // MARK: - Main Check

    static func performAllChecks() -> IntegrityResult {
        let (jailbroken, jailbreakReasons) = checkJailbreak()
        let (emulator, emulatorReasons) = checkSimulator()
        let (debugged, debugReasons) = checkDebugger()
        let (devMode, devModeReasons) = checkDeveloperMode()

        var allReasons: [String] = []
        if jailbroken { allReasons.append(contentsOf: jailbreakReasons) }
        if emulator { allReasons.append(contentsOf: emulatorReasons) }
        if debugged { allReasons.append(contentsOf: debugReasons) }
        if devMode { allReasons.append(contentsOf: devModeReasons) }

        let isSecure = !jailbroken && !emulator && !debugged && !devMode

        return IntegrityResult(
            isJailbroken: jailbroken,
            isEmulator: emulator,
            isDebugged: debugged,
            isDeveloperModeEnabled: devMode,
            isSecure: isSecure,
            failureReasons: allReasons
        )
    }

    // MARK: - Jailbreak Detection

    private static func checkJailbreak() -> (Bool, [String]) {
        var reasons: [String] = []

        if checkJailbreakFiles() {
            reasons.append("Jailbreak files detected on device")
        }
        if checkSandboxViolation() {
            reasons.append("Sandbox integrity compromised")
        }
        if checkSuspiciousDylibs() {
            reasons.append("Suspicious dynamic libraries detected")
        }
        if checkForkAvailability() {
            reasons.append("Process forking available (sandbox broken)")
        }
        if checkSymbolicLinks() {
            reasons.append("Suspicious symbolic links detected")
        }
        if checkURLSchemes() {
            reasons.append("Jailbreak app URL schemes detected")
        }

        return (!reasons.isEmpty, reasons)
    }

    private static func checkJailbreakFiles() -> Bool {
        let suspiciousPaths = [
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/Applications/Zebra.app",
            "/Applications/Installer.app",
            "/Applications/Filza.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/Library/MobileSubstrate/DynamicLibraries/Veency.plist",
            "/Library/MobileSubstrate/DynamicLibraries/LiveClock.plist",
            "/bin/bash",
            "/bin/sh",
            "/usr/sbin/sshd",
            "/usr/bin/ssh",
            "/usr/bin/sshd",
            "/usr/libexec/sftp-server",
            "/usr/libexec/ssh-keysign",
            "/etc/apt",
            "/etc/apt/sources.list.d/",
            "/private/var/lib/apt/",
            "/private/var/lib/cydia",
            "/private/var/stash",
            "/private/var/mobile/Library/SBSettings/Themes",
            "/private/var/tmp/cydia.log",
            "/private/var/log/syslog",
            "/System/Library/LaunchDaemons/com.ikey.bbot.plist",
            "/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
            "/var/binpack",
            "/var/checkra1n.dmg",
            "/var/cache/apt",
            "/var/lib/dpkg",
            "/Library/PreferenceBundles/LibertyPref.bundle",
            "/Library/PreferenceBundles/ShadowPreferences.bundle",
            "/Library/PreferenceBundles/ABypassPrefs.bundle",
            "/Library/PreferenceBundles/FlyJBPrefs.bundle",
            "/usr/lib/libjailbreak.dylib",
            "/usr/lib/libhooker.dylib",
            "/usr/lib/libsubstitute.dylib",
            "/usr/lib/substrate",
            "/usr/lib/TweakInject"
        ]

        let fileManager = FileManager.default
        for path in suspiciousPaths {
            if fileManager.fileExists(atPath: path) {
                return true
            }
        }

        // Also check using open() which can bypass some hooks
        for path in suspiciousPaths {
            let file = open(path, O_RDONLY)
            if file != -1 {
                close(file)
                return true
            }
        }

        return false
    }

    private static func checkSandboxViolation() -> Bool {
        let testPath = "/private/jailbreak_integrity_test_\(UUID().uuidString).txt"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            // If write succeeded, sandbox is broken
            try? FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            return false
        }
    }

    private static func checkSuspiciousDylibs() -> Bool {
        let suspiciousLibs = [
            "MobileSubstrate",
            "CydiaSubstrate",
            "SubstrateLoader",
            "SubstrateInserter",
            "TweakInject",
            "libhooker",
            "substitute",
            "Electra",
            "Liberty",
            "Shadow",
            "FlyJB",
            "ABypass",
            "SSLKillSwitch",
            "FridaGadget",
            "frida",
            "cycript",
            "libcycript"
        ]

        let imageCount = _dyld_image_count()
        for i in 0..<imageCount {
            if let imageName = _dyld_get_image_name(i) {
                let name = String(cString: imageName)
                for suspicious in suspiciousLibs {
                    if name.lowercased().contains(suspicious.lowercased()) {
                        return true
                    }
                }
            }
        }

        return false
    }

    private static func checkForkAvailability() -> Bool {
        // On a properly sandboxed iOS device, fork() should fail
        let forkPtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "fork") // RTLD_DEFAULT
        if let forkFunc = unsafeBitCast(forkPtr, to: (@convention(c) () -> Int32)?.self) {
            let pid = forkFunc()
            if pid >= 0 {
                if pid > 0 {
                    // Parent: kill child process
                    kill(pid, SIGTERM)
                }
                return true
            }
        }
        return false
    }

    private static func checkSymbolicLinks() -> Bool {
        let pathsToCheck = [
            "/Applications",
            "/var/stash/Library/Ringtones",
            "/var/stash/Library/Wallpaper",
            "/var/stash/usr/include",
            "/var/stash/usr/libexec",
            "/var/stash/usr/share",
            "/var/stash/usr/arm-apple-darwin9"
        ]

        let fileManager = FileManager.default
        for path in pathsToCheck {
            do {
                let attrs = try fileManager.attributesOfItem(atPath: path)
                if let type = attrs[.type] as? FileAttributeType, type == .typeSymbolicLink {
                    return true
                }
            } catch {
                continue
            }
        }

        return false
    }

    private static func checkURLSchemes() -> Bool {
        let schemes = [
            "cydia://package/com.example.package",
            "sileo://package/com.example.package",
            "zbra://packages/com.example.package",
            "filza:///"
        ]

        for scheme in schemes {
            if let url = URL(string: scheme) {
                if UIApplication.shared.canOpenURL(url) {
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Simulator / Emulator Detection

    private static func checkSimulator() -> (Bool, [String]) {
        var reasons: [String] = []

        #if targetEnvironment(simulator)
        reasons.append("Running on iOS Simulator")
        return (true, reasons)
        #endif

        // Runtime checks as fallback
        let env = ProcessInfo.processInfo.environment
        if env["SIMULATOR_DEVICE_NAME"] != nil ||
           env["SIMULATOR_ROOT"] != nil ||
           env["SIMULATOR_HOST_HOME"] != nil ||
           env["SIMULATOR_RUNTIME_VERSION"] != nil {
            reasons.append("Simulator environment variables detected")
        }

        // Check machine architecture
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        if machine == "x86_64" || machine == "i386" {
            reasons.append("Simulator architecture detected (\(machine))")
        }

        // Check for known simulator model identifiers
        if machine.contains("Simulator") || machine.contains("simulator") {
            reasons.append("Simulator model identifier detected")
        }

        return (!reasons.isEmpty, reasons)
    }

    // MARK: - Debugger Detection (Connected Device)

    private static func checkDebugger() -> (Bool, [String]) {
        var reasons: [String] = []

        #if !DEBUG
        if isDebuggerAttached() {
            reasons.append("Debugger attached to process")
        }

        if checkPtrace() {
            reasons.append("Debug tracing detected")
        }
        #endif

        if checkDYLDInsertLibraries() {
            reasons.append("DYLD_INSERT_LIBRARIES environment variable set")
        }

        if checkReverseEngineeringTools() {
            reasons.append("Reverse engineering tools detected")
        }

        return (!reasons.isEmpty, reasons)
    }

    private static func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride

        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        if result != 0 {
            return false
        }

        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    private static func checkPtrace() -> Bool {
        // Try to deny debugger attachment via ptrace
        let PT_DENY_ATTACH: Int32 = 31
        if let ptracePtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "ptrace") {
            typealias PtraceFunc = @convention(c) (Int32, Int32, Int32, Int32) -> Int32
            let ptrace = unsafeBitCast(ptracePtr, to: PtraceFunc.self)
            let result = ptrace(PT_DENY_ATTACH, 0, 0, 0)
            // If ptrace returns -1 with ENOTSUP, it means a debugger is already attached
            if result == -1 && errno == ENOTSUP {
                return true
            }
        }
        return false
    }

    private static func checkDYLDInsertLibraries() -> Bool {
        return ProcessInfo.processInfo.environment["DYLD_INSERT_LIBRARIES"] != nil
    }

    private static func checkReverseEngineeringTools() -> Bool {
        // Check for Frida server
        let fridaPorts = [27042, 27043]
        for port in fridaPorts {
            if canConnectToPort(port) {
                return true
            }
        }

        // Check for Frida in loaded dylibs
        let imageCount = _dyld_image_count()
        for i in 0..<imageCount {
            if let imageName = _dyld_get_image_name(i) {
                let name = String(cString: imageName).lowercased()
                if name.contains("frida") || name.contains("cycript") {
                    return true
                }
            }
        }

        return false
    }

    private static func canConnectToPort(_ port: Int) -> Bool {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock != -1 else { return false }
        defer { close(sock) }

        // Set a short timeout for the connection attempt
        var timeout = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        return result == 0
    }

    // MARK: - Developer Mode Detection

    private static func checkDeveloperMode() -> (Bool, [String]) {
        var reasons: [String] = []

        if checkProvisioningProfile() {
            reasons.append("Development provisioning profile detected")
        }

        if checkDeveloperDiskImage() {
            reasons.append("Developer disk image mounted")
        }

        return (!reasons.isEmpty, reasons)
    }

    private static func checkProvisioningProfile() -> Bool {
        // Check for embedded.mobileprovision (development builds have this)
        guard let profilePath = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") else {
            return false // No provisioning profile = App Store build (not development)
        }

        // Read the provisioning profile to check for development indicators
        guard let profileData = FileManager.default.contents(atPath: profilePath),
              let profileString = String(data: profileData, encoding: .ascii) else {
            return false
        }

        // Check for get-task-allow entitlement (true in development builds)
        if profileString.contains("<key>get-task-allow</key>") {
            // Find if get-task-allow is set to true
            if let range = profileString.range(of: "<key>get-task-allow</key>") {
                let afterKey = profileString[range.upperBound...]
                if afterKey.contains("<true/>") {
                    let trueRange = afterKey.range(of: "<true/>")!
                    let falseRange = afterKey.range(of: "<false/>")
                    // Check if <true/> comes before <false/> or any other key
                    if falseRange == nil || trueRange.lowerBound < falseRange!.lowerBound {
                        return true
                    }
                }
            }
        }

        return false
    }

    private static func checkDeveloperDiskImage() -> Bool {
        // Check for paths that exist when developer disk image is mounted
        let developerPaths = [
            "/Developer",
            "/usr/lib/libMobileGestalt.dylib" // More accessible on dev-mounted devices
        ]

        let fileManager = FileManager.default
        for path in developerPaths {
            if fileManager.fileExists(atPath: path) {
                // /Developer directory typically only exists with dev disk image
                if path == "/Developer" {
                    return true
                }
            }
        }

        return false
    }
}

