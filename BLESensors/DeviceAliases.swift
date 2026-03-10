import Foundation

private struct DeviceEntry: Codable {
    let name: String
    let alias: String?
    let homekit: Bool?
}

struct DeviceConfig {
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
                entries.map { e in (e.name, DeviceConfig(alias: e.alias ?? "", homekit: e.homekit ?? false)) },
                uniquingKeysWith: { first, _ in first }
            )
        }
        return [:]
    }

    /// Saves the current sensor list to ~/Library/Application Support/BLESensors/devices.json.
    static func save(sensors: [SensorReading]) {
        guard let url = fileURL else { return }

        let entries = sensors.map { sensor in
            DeviceEntry(name: sensor.name, alias: sensor.alias, homekit: sensor.homekit)
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
