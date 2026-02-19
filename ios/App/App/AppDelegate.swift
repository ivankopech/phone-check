import UIKit
import Capacitor

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Run security checks before anything else
        performSecurityCheck()
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Re-check security when app comes to foreground
        performSecurityCheck()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Re-check security when app becomes active
        performSecurityCheck()
    }

    func applicationWillTerminate(_ application: UIApplication) {
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }

    // MARK: - Security

    private func performSecurityCheck() {
        let result = DeviceIntegrityChecker.performAllChecks()

        if !result.isSecure {
            DispatchQueue.main.async { [weak self] in
                self?.showBlockingScreen(reasons: result.failureReasons)
            }
        } else {
            // Remove blocking screen if it was previously shown
            DispatchQueue.main.async { [weak self] in
                self?.removeBlockingScreen()
            }
        }

        // Also run App Attest asynchronously
        Task {
            let attestResult = await AppAttestService.shared.performAttestation()
            if !attestResult.success {
                var reasons = result.failureReasons
                reasons.append("App Attest failed: \(attestResult.error ?? "unknown")")
                DispatchQueue.main.async { [weak self] in
                    self?.showBlockingScreen(reasons: reasons)
                }
            }
        }
    }

    private func showBlockingScreen(reasons: [String]) {
        guard let window = self.window else { return }

        // Remove existing blocking view if any
        window.viewWithTag(SecurityBlockingView.viewTag)?.removeFromSuperview()

        let blockingView = SecurityBlockingView(reasons: reasons)
        blockingView.frame = window.bounds
        blockingView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(blockingView)
        window.bringSubviewToFront(blockingView)
    }

    private func removeBlockingScreen() {
        guard let window = self.window else { return }
        window.viewWithTag(SecurityBlockingView.viewTag)?.removeFromSuperview()
    }
}
