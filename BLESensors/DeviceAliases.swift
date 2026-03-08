import Foundation

private struct DeviceEntry: Codable {
    let uuid: String
    let name: String?
    let alias: String?
}

enum DeviceAliases {
    /// Returns a [deviceName: alias] dictionary.
    /// Looks in ~/Library/Application Support/BLESensors/devices.json first, then the app bundle.
    static func load() -> [String: String] {
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
                    guard let name = e.name, let alias = e.alias, !alias.isEmpty else { return nil }
                    return (name, alias)
                },
                uniquingKeysWith: { first, _ in first }
            )
        }
        return [:]
    }

    /// Saves the current sensor list to ~/Library/Application Support/BLESensors/devices.json.
    static func save(sensors: [SensorReading]) {
        guard let url = fileURL else { return }

        let entries = sensors.map { sensor in
            DeviceEntry(uuid: sensor.id.uuidString, name: sensor.name, alias: sensor.alias)
        }

        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static var fileURL: URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("BLESensors/devices.json")
    }
}
