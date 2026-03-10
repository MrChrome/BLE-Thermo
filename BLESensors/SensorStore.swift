import Foundation
import Observation

struct SensorReading: Identifiable {
    let id: UUID
    var name: String
    var alias: String
    var tempF: Double
    var humidity: Double
    var battery: Int
    var rssi: Int
    var lastSeen: Date
    var homekit: Bool

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

@Observable
class SensorStore {
    var sensors: [SensorReading] = []
    var devices: [DeviceReading] = []
    var homekitSetupCode: String? = nil
    var bridge: HomeKitBridge? = nil
    private var reachabilityTimer: Timer?

    init() {
        // Every 60 seconds, mark sensors not seen in 5 minutes as unreachable in HomeKit
        reachabilityTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            let cutoff = Date().addingTimeInterval(-5 * 60)
            for sensor in self.sensors where sensor.homekit {
                if sensor.lastSeen < cutoff {
                    self.bridge?.markUnreachable(id: sensor.id)
                }
            }
        }
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
        sensors[idx].alias = alias
        DeviceAliases.save(sensors: sensors)
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
}
