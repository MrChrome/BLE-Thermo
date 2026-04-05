import SwiftUI

struct ContentView: View {
    var store: SensorStore
    @State private var renamingSensor: SensorReading?
    @State private var renameText = ""
    @State private var showRSSI = false
    @State private var eventMonitor: Any?
    @State private var showHomekitCode = false
    @State private var graphSensor: SensorReading?
    @State private var downloadingSensor: SensorReading?
    @State private var historyDownloader = GoveeHistoryDownloader()

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 0) {
            if store.sensors.isEmpty && store.devices.isEmpty && store.rokuTVs.isEmpty {
                ContentUnavailableView(
                    "Scanning for Sensors",
                    systemImage: "sensor.tag.radiowaves.forward",
                    description: Text("Looking for nearby Govee BLE sensors…\(store.mysaEnabled ? "\nMysa cloud polling active." : "")")
                )
                .foregroundStyle(.white)
                .frame(minHeight: 200)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(store.devices) { device in
                            DeviceCell(device: device, showRSSI: showRSSI, ledState: store.ledState)
                                .onTapGesture { toggleLED() }
                        }
                        ForEach(store.rokuTVs) { tv in
                            RokuCell(tv: tv)
                                .onTapGesture { toggleTV(tv) }
                        }
                        ForEach(store.sensors) { sensor in
                            SensorCell(sensor: sensor, showRSSI: showRSSI)
                                .onTapGesture { graphSensor = sensor }
                                .contextMenu {
                                    Button("Rename") {
                                        renameText = sensor.alias.isEmpty ? sensor.name : sensor.alias
                                        renamingSensor = sensor
                                    }
                                    if sensor.source == .govee {
                                        Toggle("HomeKit", isOn: Binding(
                                            get: { sensor.homekit },
                                            set: { enabled in
                                                store.setHomeKit(id: sensor.id, enabled: enabled)
                                                if enabled { showHomekitCode = true }
                                            }
                                        ))
                                    }
                                    Divider()
                                    Button("Graph…") { graphSensor = sensor }
                                    if sensor.source == .govee {
                                        Button("Download History…") {
                                            if let peripheral = store.peripherals[sensor.id],
                                               let ble = store.bleDelegate {
                                                downloadingSensor = sensor
                                                historyDownloader.start(peripheral: peripheral, bleDelegate: ble, sensorName: sensor.displayName, database: store.database)
                                            }
                                        }
                                    }
                                }
                        }
                    }
                    .padding(8)
                }
            }
        }
        .navigationTitle("BLE Thermo")
        .frame(minWidth: 240)
        .background(Color(white: 0.0, opacity: 0.2))
        .overlay(Rectangle().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.1))
        .alert("Rename Sensor", isPresented: Binding(
            get: { renamingSensor != nil },
            set: { if !$0 { renamingSensor = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Save") {
                if let sensor = renamingSensor {
                    store.rename(id: sensor.id, alias: renameText)
                }
                renamingSensor = nil
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let sensor = renamingSensor {
                Text(sensor.name)
            }
        }
        .alert("HomeKit Pairing Code", isPresented: $showHomekitCode) {
            Button("OK", role: .cancel) { }
        } message: {
            if let code = store.homekitSetupCode {
                Text("Pairing code: \(code)")
            } else {
                Text("HomeKit bridge is not running.")
            }
        }
        .sheet(item: $downloadingSensor, onDismiss: {
            historyDownloader.cancel()
        }) { sensor in
            HistoryDebugSheet(sensor: sensor, downloader: historyDownloader)
        }
        .sheet(item: $graphSensor) { sensor in
            NavigationStack {
                GraphWindow(sensorName: sensor.displayName, database: store.database)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { graphSensor = nil }
                        }
                    }
            }
        }
        .onAppear {
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                showRSSI = event.modifierFlags.contains(.shift)
                return event
            }
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
    }

    private func toggleLED() {
        let led = store.bridge?.ledController
        switch store.ledState {
        case .off:
            led?.setPower(true)
            led?.setColorRGB(r: 255, g: 255, b: 255)
            store.ledState = .on
        case .on:
            let color = SolarCalculator.currentColor()
            led?.setPower(true)
            led?.setColorRGB(r: color.r, g: color.g, b: color.b)
            store.bridge?.notifyLEDPowerOn()
            store.ledState = .auto
        case .auto:
            led?.setPower(false)
            store.ledState = .off
        }
    }

    private func toggleTV(_ tv: RokuTV) {
        let newState = !tv.powerOn
        if let idx = store.rokuTVs.firstIndex(where: { $0.id == tv.id }) {
            store.rokuTVs[idx].powerOn = newState
        }
        Task { await tv.controller.setPower(newState) }
    }
}

// MARK: - Grid Cells

struct SensorCell: View {
    let sensor: SensorReading
    var showRSSI: Bool

    private var tempColor: Color {
        let t = sensor.tempF
        if t >= 79.95      { return Color(red: 0.95, green: 0.65, blue: 0.65) }
        else if t >= 74.95 { return Color(red: 0.98, green: 0.78, blue: 0.58) }
        else if t >= 69.95 { return Color(red: 0.65, green: 0.92, blue: 0.72) }
        else               { return Color(red: 0.7,  green: 0.88, blue: 1.0)  }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Text(sensor.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                Spacer(minLength: 2)
                if sensor.source == .govee {
                    BatteryView(pct: sensor.battery)
                } else {
                    Image(systemName: "powerplug.fill")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            Text(String(format: "%.1f°", sensor.tempF))
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(tempColor)
            HStack(spacing: 4) {
                Text(String(format: "%.0f%%", sensor.humidity))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                if showRSSI {
                    Text("·").foregroundStyle(.white.opacity(0.4))
                    Text("\(sensor.rssi)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                } else if sensor.lastSeen.timeIntervalSinceNow < -60 {
                    Text("·").foregroundStyle(.white.opacity(0.4))
                    Text(sensor.lastSeen, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct DeviceCell: View {
    let device: DeviceReading
    var showRSSI: Bool
    var ledState: SensorStore.LEDState

    private var sunsetLabel: String {
        guard let sunset = SolarCalculator.sunTimes()?.sunset else { return "Auto" }
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: sunset)
    }

    private var bulbColor: Color {
        switch ledState {
        case .off:  return .white.opacity(0.3)
        case .on:   return .white
        case .auto: return Color(red: 1.0, green: 0.85, blue: 0.4)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Text(device.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                Spacer()
                Image(systemName: ledState == .off ? "lightbulb" : "lightbulb.fill")
                    .foregroundStyle(bulbColor)
            }
            Spacer()
            if ledState == .auto {
                Text("Sunset \(sunsetLabel)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                Text(ledState == .off ? "Off" : "On")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct RokuCell: View {
    let tv: RokuTV

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Text(tv.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                Spacer()
                Image(systemName: tv.powerOn ? "tv.fill" : "tv")
                    .foregroundStyle(tv.powerOn ? .white : .white.opacity(0.3))
            }
            Spacer()
            Text(tv.powerOn ? "On" : "Off")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Supporting Views

struct BatteryView: View {
    let pct: Int

    private var color: Color { .white }
    private var filled: Int  { Int((Double(pct) / 100.0 * 4).rounded()) }

    var body: some View {
        HStack(spacing: 1) {
            HStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(i < filled ? color : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 1)
                                .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                        )
                        .frame(width: 5, height: 9)
                }
            }
            .padding(2)
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.white, lineWidth: 1))

            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white)
                .frame(width: 2, height: 5)
        }
    }
}

struct HistoryDebugSheet: View {
    let sensor: SensorReading
    var downloader: GoveeHistoryDownloader
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(sensor.displayName)
                        .font(.headline)
                    Text(downloader.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            ProgressView(value: downloader.progress)
        }
        .padding()
        .frame(minWidth: 320, minHeight: 80)
    }
}
