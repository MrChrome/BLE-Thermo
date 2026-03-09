import SwiftUI
import AppKit

@main
struct BLESensorsApp: App {
    @State private var store = SensorStore()
    @State private var scanner: BluetoothScanner?
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // A hidden Settings scene keeps the app running with no dock/window
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var statusMenu: NSMenu?
    var panel: NSPanel?
    var store = SensorStore()
    var scanner: BluetoothScanner?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "thermometer.medium", accessibilityDescription: "BLE Thermo")
            button.action = #selector(handleStatusItemClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Show Window", action: #selector(togglePanel), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit BLE Thermo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem?.menu = nil
        self.statusMenu = menu

        // Floating panel
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 272, height: 300),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "BLE Thermo"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.center()

        let contentView = ContentView(store: store)
            .task {
                if self.scanner == nil {
                    do {
                        let bridge = try HomeKitBridge()
                        self.store.bridge = bridge
                        self.store.homekitSetupCode = bridge.setupCode
                        print("[HomeKit] Bridge started, pairing code: \(bridge.setupCode)")
                    } catch {
                        print("[HomeKit] Bridge failed to start: \(error)")
                    }
                    self.scanner = BluetoothScanner(store: self.store)
                }
            }

        panel.contentView = NSHostingView(rootView: contentView)
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
    }

    @objc func handleStatusItemClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            statusItem?.menu = statusMenu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            togglePanel()
        }
    }

    @objc func togglePanel() {
        guard let panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
