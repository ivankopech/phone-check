import UIKit
import Capacitor

class AppViewController: CAPBridgeViewController {

    override open func capacitorDidLoad() {
        super.capacitorDidLoad()

        // Register our local security plugin instance
        let securityPlugin = DeviceSecurityPlugin()
        bridge?.registerPluginInstance(securityPlugin)
    }
}
