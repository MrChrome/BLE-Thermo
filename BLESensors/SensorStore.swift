import Foundation
import Observation
import CoreBluetooth

enum SensorSource {
    case govee, mysa, homepod
}

struct SensorReading: Identifiable {
    let id: UUID
    var name: String
    var alias: String
    var tempF: Double
    var humidity: Double
    var battery: Int      // -1 for sensors without a battery (e.g. Mysa)
    var rssi: Int
    var lastSeen: Date
    var homekit: Bool
    var source: SensorSource = .govee

    var displayName: String { alias.isEmpty ? name : alias }
}

struct DeviceReading: Identifiable {
    let id: UUID
    var name: String
    var rssi: Int
    var lastSeen: Date
}

// Maps BLE device names to display names shown in the UI
let trackedDeviceNames: [String: String] = [
    "ELK-BLEDOM": "LED Strips"
]

struct RokuTV: Identifiable {
    let id: String      // serial number
    let name: String
    let ip: String
    var powerOn: Bool
    let controller: RokuController
}

@Observable
class SensorStore {
    var sensors: [SensorReading] = []
    var devices: [DeviceReading] = []
    var peripherals: [UUID: CBPeripheral] = [:]
    var bleDelegate: ObjCBLEDelegate?
    var homekitSetupCode: String? = nil
    let mysaClient = MysaClient()
    private var mysaPollingTask: Task<Void, Never>?

    var rokuTVs: [RokuTV] = []
    var rokuScanner: RokuScanner?

    let homepodReader = HomePodReader()

    var homepodEnabled: Bool = UserDefaults.standard.bool(forKey: "homepodEnabled") {
        didSet {
            UserDefaults.standard.set(homepodEnabled, forKey: "homepodEnabled")
            if !homepodEnabled { removeHomepodSensors() }
            // HomePodReader starts automatically once HomeKit authorises;
            // disabling just hides the sensors and suppresses the callback.
        }
    }

    var mysaEnabled: Bool = UserDefaults.standard.bool(forKey: "mysaEnabled") {
        didSet {
            UserDefaults.standard.set(mysaEnabled, forKey: "mysaEnabled")
            if mysaEnabled { startMysaPolling() } else { stopMysaPolling() }
        }
    }

    var bridge: HomeKitBridge? = nil {
        didSet {
            // When the bridge becomes available, restore auto-color if it was previously enabled
            if bridge != nil && ledAutoColor {
                let color = SolarCalculator.currentColor()
                bridge?.ledController?.setPower(true)
                bridge?.ledController?.setColorRGB(r: color.r, g: color.g, b: color.b)
                bridge?.notifyLEDPowerOn()
            }
        }
    }
    private var reachabilityTimer: Timer?
    private var ledColorTimer: Timer?
    private var loggingTimer: Timer?
    let database = SensorDatabase()
    enum LEDState { case off, on, auto }

    var ledAutoColor: Bool {
        get { ledState == .auto }
        set { ledState = newValue ? .auto : .off }
    }

    var ledState: LEDState = UserDefaults.standard.bool(forKey: "ledAutoColor") ? .auto : .off {
        didSet { UserDefaults.standard.set(ledAutoColor, forKey: "ledAutoColor") }
    }

    init() {
        // Every 5 minutes, update LED strip color based on time of day
        ledColorTimer = Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { [weak self] _ in
            guard let self, self.ledAutoColor else { return }
            let color = SolarCalculator.currentColor()
            self.bridge?.ledController?.setColorRGB(r: color.r, g: color.g, b: color.b)
            self.bridge?.notifyLEDPowerOn()
        }

        // Every 60 seconds, log sensor readings to the database
        loggingTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self, !self.sensors.isEmpty else { return }
            self.database.log(sensors: self.sensors)
        }

        // Every 60 seconds, check sensor timeouts
        reachabilityTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            let unreachableCutoff = Date().addingTimeInterval(-5 * 60)
            let removeCutoff = Date().addingTimeInterval(-15 * 60)

            // Remove sensors and devices not seen in 15 minutes
            self.sensors.removeAll { sensor in
                guard sensor.lastSeen < removeCutoff else { return false }
                if sensor.homekit { self.bridge?.markUnreachable(id: sensor.id) }
                return true
            }
            self.devices.removeAll { $0.lastSeen < removeCutoff }

            // Mark sensors not seen in 5 minutes as unreachable in HomeKit
            for sensor in self.sensors where sensor.homekit {
                if sensor.lastSeen < unreachableCutoff {
                    self.bridge?.markUnreachable(id: sensor.id)
                }
            }
        }

        // Start Mysa polling if previously enabled and authenticated
        if mysaEnabled && mysaClient.isAuthenticated {
            startMysaPolling()
        }

        // HomePod reader: deliver readings whenever HomeKit reports them
        homepodReader.onUpdate = { [weak self] id, name, tempF, humidity in
            guard let self, self.homepodEnabled else { return }
            self.applyHomepodReading(id: id, name: name, tempF: tempF, humidity: humidity)
        }
    }

    // MARK: - Mysa Polling

    func startMysaPolling() {
        mysaPollingTask?.cancel()
        mysaPollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    let devices = try await self.mysaClient.fetchDevices()
                    await MainActor.run { self.applyMysaDevices(devices) }
                } catch {
                    print("[Mysa] Poll error: \(error.localizedDescription)")
                }
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    func stopMysaPolling() {
        mysaPollingTask?.cancel()
        mysaPollingTask = nil
        removeMysaSensors()
    }

    func removeMysaSensors() {
        sensors.removeAll { $0.source == .mysa }
    }

    func removeHomepodSensors() {
        sensors.removeAll { $0.source == .homepod }
    }

    private func applyHomepodReading(id: UUID, name: String, tempF: Double, humidity: Double) {
        if let idx = sensors.firstIndex(where: { $0.id == id }) {
            sensors[idx].name     = name
            sensors[idx].tempF    = tempF
            sensors[idx].humidity = humidity
            sensors[idx].lastSeen = Date()
        } else {
            sensors.append(SensorReading(
                id: id, name: name, alias: "",
                tempF: tempF, humidity: humidity,
                battery: -1, rssi: 0,
                lastSeen: Date(), homekit: false,
                source: .homepod
            ))
        }
        sensors.sort { $0.tempF > $1.tempF }
    }

    /// Trigger an immediate Mysa poll (e.g. right after sign-in).
    func pollMysaNow() async {
        guard mysaClient.isAuthenticated else { return }
        do {
            let devices = try await mysaClient.fetchDevices()
            applyMysaDevices(devices)
        } catch {
            print("[Mysa] Immediate poll error: \(error.localizedDescription)")
        }
    }

    private func applyMysaDevices(_ devices: [MysaDeviceState]) {
        for device in devices {
            if let idx = sensors.firstIndex(where: { $0.id == device.id }) {
                sensors[idx].name     = device.name
                sensors[idx].tempF    = device.tempF
                sensors[idx].humidity = device.humidity
                sensors[idx].lastSeen = Date()
            } else {
                sensors.append(SensorReading(
                    id: device.id,
                    name: device.name,
                    alias: "",
                    tempF: device.tempF,
                    humidity: device.humidity,
                    battery: -1,
                    rssi: 0,
                    lastSeen: Date(),
                    homekit: false,
                    source: .mysa
                ))
            }
        }
        sensors.sort { $0.tempF > $1.tempF }
    }

    func update(uuid: UUID, name: String, alias: String, homekit: Bool = false, tempF: Double, humidity: Double, battery: Int, rssi: Int) {
        let isNew = !sensors.contains(where: { $0.id == uuid })

        if let idx = sensors.firstIndex(where: { $0.id == uuid }) {
            sensors[idx].name     = name
            sensors[idx].alias    = alias.isEmpty ? sensors[idx].alias : alias
            sensors[idx].tempF    = tempF
            sensors[idx].humidity = humidity
            sensors[idx].battery  = battery
            sensors[idx].rssi     = rssi
            sensors[idx].lastSeen = Date()
        } else {
            sensors.append(SensorReading(
                id: uuid, name: name, alias: alias,
                tempF: tempF, humidity: humidity,
                battery: battery, rssi: rssi, lastSeen: Date(),
                homekit: homekit
            ))
        }

        // If this is a new sensor with homekit enabled, register it with the bridge
        if isNew && homekit {
            if let sensor = sensors.first(where: { $0.id == uuid }) {
                bridge?.addSensor(sensor)
            }
        }
        sensors.sort { $0.tempF > $1.tempF }

        // Update HomeKit for this sensor
        if let sensor = sensors.first(where: { $0.id == uuid }), sensor.homekit {
            bridge?.updateSensor(sensor)
        }
    }

    func updateDevice(uuid: UUID, name: String, rssi: Int) {
        if let idx = devices.firstIndex(where: { $0.id == uuid }) {
            devices[idx].name = name
            devices[idx].rssi = rssi
            devices[idx].lastSeen = Date()
        } else {
            devices.append(DeviceReading(id: uuid, name: name, rssi: rssi, lastSeen: Date()))
        }
    }

    func rename(id: UUID, alias: String) {
        guard let idx = sensors.firstIndex(where: { $0.id == id }) else { return }
        let oldName = sensors[idx].displayName
        sensors[idx].alias = alias
        let newName = sensors[idx].displayName
        DeviceAliases.save(sensors: sensors)
        database.rename(from: oldName, to: newName)
    }

    func setHomeKit(id: UUID, enabled: Bool) {
        guard let idx = sensors.firstIndex(where: { $0.id == id }) else { return }
        sensors[idx].homekit = enabled
        DeviceAliases.save(sensors: sensors)
        if enabled {
            bridge?.addSensor(sensors[idx])
        } else {
            bridge?.removeSensor(id: id)
        }
    }

    // MARK: - Roku TVs

    func startRokuScanner() {
        let scanner = RokuScanner()

        scanner.onDiscovered = { [weak self] info in
            guard let self else { return }
            guard self.rokuTVs.first(where: { $0.id == info.serial }) == nil else { return }
            let controller = RokuController(ip: info.ip, serial: info.serial, name: info.name)
            let tv = RokuTV(id: info.serial, name: info.name, ip: info.ip, powerOn: info.powerOn, controller: controller)
            self.rokuTVs.append(tv)
            self.bridge?.addTV(info: info, controller: controller)
        }

        scanner.onStateChanged = { [weak self] serial, powerOn in
            guard let self else { return }
            if let idx = self.rokuTVs.firstIndex(where: { $0.id == serial }) {
                self.rokuTVs[idx].powerOn = powerOn
                self.bridge?.updateTV(serial: serial, powerOn: powerOn)
            }
        }

        scanner.start()
        rokuScanner = scanner
    }
}
