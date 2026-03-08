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

    var displayName: String { alias.isEmpty ? name : alias }
}

@Observable
class SensorStore {
    var sensors: [SensorReading] = []

    func update(uuid: UUID, name: String, alias: String, tempF: Double, humidity: Double, battery: Int, rssi: Int) {
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
                battery: battery, rssi: rssi, lastSeen: Date()
            ))
        }
        sensors.sort { $0.tempF > $1.tempF }
    }

    func rename(id: UUID, alias: String) {
        guard let idx = sensors.firstIndex(where: { $0.id == id }) else { return }
        sensors[idx].alias = alias
        DeviceAliases.save(sensors: sensors)
    }
}
