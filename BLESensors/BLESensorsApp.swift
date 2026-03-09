import SwiftUI

@main
struct BLESensorsApp: App {
    @State private var store = SensorStore()
    @State private var scanner: BluetoothScanner?

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .task {
                    if scanner == nil {
                        // Start HomeKit bridge
                        do {
                            let bridge = try HomeKitBridge()
                            store.bridge = bridge
                            store.homekitSetupCode = bridge.setupCode
                            print("[HomeKit] Bridge started, pairing code: \(bridge.setupCode)")
                        } catch {
                            print("[HomeKit] Bridge failed to start: \(error)")
                        }

                        // Start BLE scanning
                        scanner = BluetoothScanner(store: store)
                    }
                }
        }
        .windowResizability(.contentSize)
    }
}
