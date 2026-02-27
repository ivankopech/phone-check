import Foundation
import Capacitor
import UIKit

@objc(DeviceSecurityPlugin)
public class DeviceSecurityPlugin: CAPInstancePlugin, CAPBridgedPlugin {

    public let identifier = "DeviceSecurityPlugin"
    public let jsName = "DeviceSecurity"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "checkDeviceIntegrity", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "attestDevice", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "isSecure", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "enableScreenshotDetection", returnType: CAPPluginReturnPromise)
    ]

    private var screenshotObserver: NSObjectProtocol?

    // MARK: - Check Device Integrity (manual checks only)

    @objc func checkDeviceIntegrity(_ call: CAPPluginCall) {
        let result = DeviceIntegrityChecker.performAllChecks()
        call.resolve([
            "isJailbroken": result.isJailbroken,
            "isEmulator": result.isEmulator,
            "isDebugged": result.isDebugged,
            "isDeveloperModeEnabled": result.isDeveloperModeEnabled,
            "isSecure": result.isSecure,
            "failureReasons": result.failureReasons
        ])
    }

    // MARK: - Attest Device (App Attest only)

    @objc func attestDevice(_ call: CAPPluginCall) {
        Task {
            let attestResult = await AppAttestService.shared.performAttestation()
            call.resolve([
                "success": attestResult.success,
                "error": attestResult.error ?? ""
            ])
        }
    }

    // MARK: - Screenshot Detection

    @objc func enableScreenshotDetection(_ call: CAPPluginCall) {
        // Listen for screenshot notifications from the OS
        screenshotObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            self?.notifyListeners("screenshotDetected", data: [
                "timestamp": formatter.string(from: Date())
            ])
        }

        call.resolve(["enabled": true])
    }

    deinit {
        if let observer = screenshotObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Is Secure (combined: manual checks + App Attest)

    @objc func isSecure(_ call: CAPPluginCall) {
        let integrityResult = DeviceIntegrityChecker.performAllChecks()

        Task {
            let attestResult = await AppAttestService.shared.performAttestation()
            let overallSecure = integrityResult.isSecure && attestResult.success

            var allReasons = integrityResult.failureReasons
            if !attestResult.success {
                allReasons.append("App Attest failed: \(attestResult.error ?? "unknown error")")
            }

            call.resolve([
                "secure": overallSecure,
                "integrityCheck": [
                    "isJailbroken": integrityResult.isJailbroken,
                    "isEmulator": integrityResult.isEmulator,
                    "isDebugged": integrityResult.isDebugged,
                    "isDeveloperModeEnabled": integrityResult.isDeveloperModeEnabled
                ],
                "attestation": [
                    "success": attestResult.success,
                    "error": attestResult.error ?? ""
                ],
                "failureReasons": allReasons
            ])
        }
    }
}
