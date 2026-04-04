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

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem?
    var statusMenu: NSMenu?
    var panel: NSPanel?
    var allSensorsGraphWindow: NSWindow?
    var settingsWindow: NSWindow?
    var store = SensorStore()
    var scanner: BluetoothScanner?
    var webServer: WebServer?

    // Keys for persisting the panel's screen-relative position
    private let panelScreenFrameKey = "panelSavedScreenFrame"
    private let panelRelativeOriginXKey = "panelRelativeOriginX"
    private let panelRelativeOriginYKey = "panelRelativeOriginY"
    private let panelWidthKey = "panelSavedWidth"
    private let panelHeightKey = "panelSavedHeight"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Start web server if previously enabled
        if UserDefaults.standard.bool(forKey: "webServerEnabled") {
            webServer = WebServer(database: store.database)
            webServer?.start()
        }

        // Menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "thermometer.medium", accessibilityDescription: "BLE Thermo")
            button.action = #selector(handleStatusItemClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Show Window", action: #selector(showPanel), keyEquivalent: "")
        menu.addItem(withTitle: "Graph All…", action: #selector(openAllSensorsGraph), keyEquivalent: "")
        let webItem = NSMenuItem(title: webServerMenuTitle, action: #selector(toggleWebServer), keyEquivalent: "")
        menu.addItem(webItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Reset HomeKit…", action: #selector(resetHomeKit), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit BLE Thermo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem?.menu = nil
        self.statusMenu = menu

        // Floating panel
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 272, height: 300),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.title = ""
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.delegate = self
        restorePanelPosition(panel)

        // Watch for monitors connecting/disconnecting (e.g. after wake from sleep)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        let contentView = ContentView(store: store)
            .task {
                if self.scanner == nil {
                    do {
                        let configs = DeviceAliases.load()
                        let bridge = try HomeKitBridge(knownSensors: Array(configs.values))
                        bridge.store = self.store
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

    private var webServerMenuTitle: String {
        webServer != nil ? "Disable Web Server" : "Enable Web Server"
    }

    @objc func toggleWebServer() {
        if webServer != nil {
            webServer?.stop()
            webServer = nil
            UserDefaults.standard.set(false, forKey: "webServerEnabled")
            print("[Web] Server stopped")
        } else {
            webServer = WebServer(database: store.database)
            webServer?.start()
            UserDefaults.standard.set(true, forKey: "webServerEnabled")
        }
        // Update menu item title
        if let item = statusMenu?.items.first(where: {
            $0.action == #selector(toggleWebServer)
        }) {
            item.title = webServerMenuTitle
        }
    }

    @objc func resetHomeKit() {
        let alert = NSAlert()
        alert.messageText = "Reset HomeKit?"
        alert.informativeText = "This will delete all HomeKit pairing data. You will need to re-pair the bridge in the Home app. The app will quit after resetting."
        alert.addButton(withTitle: "Reset & Quit")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        if let url = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("BLESensors/hap.json") {
            try? FileManager.default.removeItem(at: url)
            print("[HomeKit] Deleted hap.json")
        }

        NSApp.terminate(nil)
    }

    @objc func openAllSensorsGraph() {
        if let existing = allSensorsGraphWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "All Sensors"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: AllSensorsGraphWindow(database: store.database))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        allSensorsGraphWindow = window
    }

    @objc func openSettings() {
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false
        let hostingView = NSHostingView(rootView: SettingsView(store: store))
        hostingView.sizingOptions = .preferredContentSize
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    @objc func showPanel() {
        guard let panel else { return }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func handleStatusItemClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            statusItem?.menu = statusMenu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            // Show window then menu
            if let panel, !panel.isVisible {
                panel.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            statusItem?.menu = statusMenu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        }
    }

    // MARK: - Panel position persistence

    /// Save the panel's position as an offset relative to its current screen origin,
    /// along with the screen's frame so we can re-identify the screen later.
    private func savePanelPosition() {
        guard let panel, let screen = panel.screen else { return }
        let frame = panel.frame
        let screenFrame = screen.frame
        // Store position relative to screen origin so it survives resolution changes
        let relX = frame.origin.x - screenFrame.origin.x
        let relY = frame.origin.y - screenFrame.origin.y
        let defaults = UserDefaults.standard
        defaults.set(relX, forKey: panelRelativeOriginXKey)
        defaults.set(relY, forKey: panelRelativeOriginYKey)
        defaults.set(frame.width, forKey: panelWidthKey)
        defaults.set(frame.height, forKey: panelHeightKey)
        // Encode the screen frame as a string so we can match it on restore
        defaults.set(NSStringFromRect(screenFrame), forKey: panelScreenFrameKey)
    }

    /// Restore the panel to its saved position, or center it if no saved position exists
    /// or the saved screen is not currently available.
    private func restorePanelPosition(_ panel: NSPanel) {
        let defaults = UserDefaults.standard
        guard
            let screenFrameString = defaults.string(forKey: panelScreenFrameKey),
            defaults.object(forKey: panelRelativeOriginXKey) != nil
        else {
            panel.center()
            return
        }

        let savedScreenFrame = NSRectFromString(screenFrameString)
        let relX = defaults.double(forKey: panelRelativeOriginXKey)
        let relY = defaults.double(forKey: panelRelativeOriginYKey)
        let width = defaults.double(forKey: panelWidthKey)
        let height = defaults.double(forKey: panelHeightKey)

        // Find the screen matching the saved screen frame
        if let targetScreen = NSScreen.screens.first(where: { $0.frame == savedScreenFrame }) {
            let origin = CGPoint(
                x: targetScreen.frame.origin.x + relX,
                y: targetScreen.frame.origin.y + relY
            )
            let size = CGSize(width: width > 0 ? width : 272, height: height > 0 ? height : 300)
            panel.setFrame(NSRect(origin: origin, size: size), display: false)
        } else {
            // Saved screen not available yet — center on main screen for now
            panel.center()
        }
    }

    /// Called when monitors connect or disconnect (including after wake from sleep).
    /// If the saved screen has reappeared, silently move the panel back to it.
    @objc private func screensDidChange() {
        guard let panel else { return }
        let defaults = UserDefaults.standard
        guard
            let screenFrameString = defaults.string(forKey: panelScreenFrameKey),
            defaults.object(forKey: panelRelativeOriginXKey) != nil
        else { return }

        let savedScreenFrame = NSRectFromString(screenFrameString)
        let relX = defaults.double(forKey: panelRelativeOriginXKey)
        let relY = defaults.double(forKey: panelRelativeOriginYKey)
        let width = panel.frame.width
        let height = panel.frame.height

        guard let targetScreen = NSScreen.screens.first(where: { $0.frame == savedScreenFrame }) else {
            return // Screen still not available
        }

        let currentScreen = panel.screen
        guard currentScreen?.frame != targetScreen.frame else {
            return // Already on the right screen
        }

        // Silently restore to saved screen
        let origin = CGPoint(
            x: targetScreen.frame.origin.x + relX,
            y: targetScreen.frame.origin.y + relY
        )
        panel.setFrame(NSRect(origin: origin, size: CGSize(width: width, height: height)), display: true, animate: false)
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        guard (notification.object as? NSPanel) === panel else { return }
        savePanelPosition()
    }

    func windowDidResize(_ notification: Notification) {
        guard (notification.object as? NSPanel) === panel else { return }
        savePanelPosition()
    }
}
