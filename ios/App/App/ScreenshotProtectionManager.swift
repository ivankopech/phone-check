import UIKit

/// Prevents screenshots and screen recording by leveraging the iOS secure text field layer trick.
///
/// How it works:
/// 1. A UITextField with isSecureTextEntry=true creates an internal secure sublayer
///    that iOS automatically blanks during screen capture.
/// 2. We move field.layer to be a sibling of window.layer (in the root superlayer).
/// 3. We then reparent window.layer INTO the secure sublayer.
/// 4. Final hierarchy: rootLayer → field.layer → secureLayer → window.layer → (all content)
/// 5. Since all app content is nested under the secure layer, iOS blanks everything during capture.
class ScreenshotProtectionManager {

    static let shared = ScreenshotProtectionManager()

    private var secureField: UITextField?
    private var isProtectionEnabled = false

    private init() {}

    func enableProtection(in window: UIWindow) {
        guard !isProtectionEnabled else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.setupProtection(in: window)
        }
    }

    private func setupProtection(in window: UIWindow) {
        guard let windowSuperlayer = window.layer.superlayer else { return }

        let field = UITextField()
        field.isSecureTextEntry = true

        // Temporarily add the field as a subview of the window
        window.addSubview(field)
        field.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            field.centerYAnchor.constraint(equalTo: window.centerYAnchor),
            field.centerXAnchor.constraint(equalTo: window.centerXAnchor)
        ])

        // Step 1: Move field.layer OUT of window.layer and into window's superlayer.
        // addSublayer automatically removes the layer from its current parent first.
        // Before: rootLayer → window.layer → field.layer → secureLayer
        // After:  rootLayer → [window.layer, field.layer → secureLayer]
        windowSuperlayer.addSublayer(field.layer)

        // Step 2: Move window.layer INTO the secure sublayer of field.layer.
        // The secure sublayer is what iOS blanks during screen capture.
        // Before: rootLayer → [window.layer, field.layer → secureLayer]
        // After:  rootLayer → field.layer → secureLayer → window.layer → (all content)
        field.layer.sublayers?.last?.addSublayer(window.layer)

        self.secureField = field
        self.isProtectionEnabled = true
    }

    func disableProtection() {
        guard isProtectionEnabled, let field = secureField else { return }
        field.isSecureTextEntry = false
        isProtectionEnabled = false
    }

    func reEnableProtection() {
        guard !isProtectionEnabled, let field = secureField else { return }
        field.isSecureTextEntry = true
        isProtectionEnabled = true
    }
}
