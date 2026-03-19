import CoreBluetooth
import Foundation

class BluetoothScanner {
    private let store: SensorStore
    private let configs: [String: DeviceConfig]
    private let delegate: ObjCBLEDelegate
    private var ledPeripheral: CBPeripheral?

    init(store: SensorStore) {
        self.store    = store
        self.configs  = DeviceAliases.load()
        self.delegate = ObjCBLEDelegate()
        store.bleDelegate = delegate

        delegate.onDiscover = { [weak self] peripheral, mfrData, rssi, localName in
            guard let self, let peripheral, let rssi else { return }

            let uuid = peripheral.identifier
            let name = (peripheral.name ?? localName ?? uuid.uuidString.prefix(8).description).trimmingCharacters(in: .whitespaces)

            // Handle explicitly tracked non-sensor devices
            if let displayName = trackedDeviceNames[name] {
                DispatchQueue.main.async {
                    self.store.updateDevice(uuid: uuid, name: displayName, rssi: rssi.intValue)
                }
                // Connect if we don't have a controller yet and aren't already connecting
                if self.ledPeripheral == nil {
                    self.ledPeripheral = peripheral
                    self.delegate.beginConnection(peripheral)
                }
                return
            }

            // Handle Govee temperature sensors
            guard let mfrData, let reading = Self.decodeGovee(Data(mfrData)) else { return }

            let config = self.configs[name]
            DispatchQueue.main.async {
                self.store.peripherals[uuid] = peripheral
                self.store.update(
                    uuid:     uuid,
                    name:     name,
                    alias:    config?.alias ?? "",
                    homekit:  config?.homekit ?? false,
                    tempF:    reading.tempF,
                    humidity: reading.humidity,
                    battery:  reading.battery,
                    rssi:     rssi.intValue as Int
                )
            }
        }

        delegate.onConnect = { [weak self] peripheral, writeChar in
            guard let self, let peripheral, let writeChar else { return }
            let controller = LEDStripController(
                peripheral: peripheral,
                writeChar: writeChar,
                delegate: self.delegate
            )
            self.store.bridge?.ledController = controller
            print("[LED] Connected and ready")
        }

        delegate.onDisconnect = { [weak self] _ in
            self?.store.bridge?.ledController = nil
            self?.ledPeripheral = nil
            print("[LED] Disconnected")
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
