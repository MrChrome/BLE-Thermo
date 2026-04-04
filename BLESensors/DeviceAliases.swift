import Foundation

private struct DeviceEntry: Codable {
    let uuid: String?
    let name: String
    let alias: String?
    let homekit: Bool?
}

struct DeviceConfig {
    var uuid: UUID
    var alias: String
    var homekit: Bool
}

enum DeviceAliases {
    /// Returns a [deviceName: DeviceConfig] dictionary.
    /// Looks in ~/Library/Application Support/BLESensors/devices.json first, then the app bundle.
    static func load() -> [String: DeviceConfig] {
        let candidates: [URL?] = [
            fileURL,
            Bundle.main.url(forResource: "devices", withExtension: "json"),
        ]

        for url in candidates.compactMap({ $0 }) {
            guard let data = try? Data(contentsOf: url),
                  let entries = try? JSONDecoder().decode([DeviceEntry].self, from: data)
            else { continue }

            return Dictionary(
                entries.compactMap { e in
                    let uuid = e.uuid.flatMap { UUID(uuidString: $0) } ?? UUID()
                    return (e.name, DeviceConfig(uuid: uuid, alias: e.alias ?? "", homekit: e.homekit ?? false))
                },
                uniquingKeysWith: { first, _ in first }
            )
        }
        return [:]
    }

    /// Saves the current sensor list to ~/Library/Application Support/BLESensors/devices.json.
    static func save(sensors: [SensorReading]) {
        guard let url = fileURL else { return }

        // Only persist BLE (Govee) sensors — cloud sensors like Mysa re-fetch on launch
        let entries = sensors.filter { $0.source == .govee }.map { sensor in
            DeviceEntry(uuid: sensor.id.uuidString, name: sensor.name, alias: sensor.alias, homekit: sensor.homekit)
        }

        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: url, options: [.atomic])
    }

    private static var fileURL: URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("BLESensors/devices.json")
    }
}
