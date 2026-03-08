import CoreBluetooth
import Foundation

class BluetoothScanner {
    private let store: SensorStore
    private let aliases: [String: String]
    private let delegate: ObjCBLEDelegate

    init(store: SensorStore) {
        self.store   = store
        self.aliases = DeviceAliases.load()
        self.delegate = ObjCBLEDelegate()

        delegate.onDiscover = { [weak self] peripheral, mfrData, rssi in
            guard let self,
                  let peripheral,
                  let mfrData,
                  let rssi,
                  let reading = Self.decodeGovee(Data(mfrData)) else { return }

            let name  = peripheral.name ?? peripheral.identifier.uuidString.prefix(8).description
            let alias = self.aliases[name] ?? ""

            self.store.update(
                uuid:     peripheral.identifier,
                name:     name,
                alias:    alias,
                tempF:    reading.tempF,
                humidity: reading.humidity,
                battery:  reading.battery,
                rssi:     rssi.intValue as Int
            )
        }

        delegate.start(with: nil)
    }

    // MARK: - Govee advertisement decoder

    private static func decodeGovee(_ data: Data) -> (tempF: Double, humidity: Double, battery: Int)? {
        guard data.count >= 7 else { return nil }
        let companyID = UInt16(data[0]) | (UInt16(data[1]) << 8)
        guard companyID == 0xEC88 else { return nil }

        var packed = Int32((UInt32(data[3]) << 16) | (UInt32(data[4]) << 8) | UInt32(data[5]))
        if packed & 0x800000 != 0 {
            packed = -(packed & 0x7FFFFF)
        }

        let tempC    = Double(packed / 1000) / 10.0
        let humidity = Double(abs(packed) % 1000) / 10.0
        let battery  = Int(data[6])
        return (tempC * 9 / 5 + 32, humidity, battery)
    }
}
