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
                        scanner = BluetoothScanner(store: store)
                    }
                }
        }
        .windowResizability(.contentSize)
    }
}
