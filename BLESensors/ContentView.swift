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

    var body: some View {
        VStack(spacing: 0) {
            if store.sensors.isEmpty && store.devices.isEmpty {
                ContentUnavailableView(
                    "Scanning for Sensors",
                    systemImage: "sensor.tag.radiowaves.forward",
                    description: Text("Looking for nearby Govee BLE sensors…")
                )
                .foregroundStyle(.white)
                .frame(minHeight: 200)
            } else {
                VStack(spacing: 0) {
                    ForEach(store.devices) { device in
                        DeviceRow(device: device, showRSSI: showRSSI, autoColor: store.ledAutoColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                let color = SolarCalculator.currentColor()
                                let led = store.bridge?.ledController
                                led?.setPower(true)
                                led?.setColorRGB(r: color.r, g: color.g, b: color.b)
                                store.bridge?.notifyLEDPowerOn()
                                store.ledAutoColor = true
                            }
                        Divider().padding(.leading, 12)
                    }
                    ForEach(store.sensors) { sensor in
                        SensorRow(sensor: sensor, showRSSI: showRSSI)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                graphSensor = sensor
                            }
                            .contextMenu {
                                Button("Rename") {
                                    renameText = sensor.alias.isEmpty ? sensor.name : sensor.alias
                                    renamingSensor = sensor
                                }
                                Toggle("HomeKit", isOn: Binding(
                                    get: { sensor.homekit },
                                    set: { enabled in
                                        store.setHomeKit(id: sensor.id, enabled: enabled)
                                        if enabled { showHomekitCode = true }
                                    }
                                ))
                                Divider()
                                Button("Graph…") {
                                    graphSensor = sensor
                                }
                                Button("Download History…") {
                                    if let peripheral = store.peripherals[sensor.id],
                                       let ble = store.bleDelegate {
                                        downloadingSensor = sensor
                                        historyDownloader.start(peripheral: peripheral, bleDelegate: ble, sensorName: sensor.displayName, database: store.database)
                                    }
                                }
                            }
                        if sensor.id != store.sensors.last?.id {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

        }
        .navigationTitle("BLE Thermo")
        .frame(width: 272)
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
}

struct SensorRow: View {
    let sensor: SensorReading
    var showRSSI: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(sensor.displayName)
                    .font(.headline)
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Text(String(format: "%.1f°F", sensor.tempF))
                        .foregroundStyle(.white)
                    Text("·").foregroundStyle(.white)
                    Text(String(format: "%.1f%%", sensor.humidity))
                        .foregroundStyle(.white)
                    if showRSSI {
                        Text("·").foregroundStyle(.white)
                        Text("\(sensor.rssi) dBm")
                            .foregroundStyle(.white)
                    }
                }
                .font(.subheadline)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                BatteryView(pct: sensor.battery)
                if showRSSI || sensor.lastSeen.timeIntervalSinceNow < -60 {
                    Text(sensor.lastSeen, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct DeviceRow: View {
    let device: DeviceReading
    var showRSSI: Bool
    var autoColor: Bool = false

    var body: some View {
        HStack {
            Text(device.name)
                .font(.headline)
                .foregroundStyle(.white)
            if showRSSI {
                Text("\(device.rssi) dBm")
                    .font(.caption)
                    .foregroundStyle(.white)
            }
            Spacer()
            if autoColor {
                Text("Auto")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(autoColor ? Color(red: 1.0, green: 0.85, blue: 0.4) : .white)
                .frame(width: 34)
        }
        .padding(.vertical, 4)
    }
}

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
