import Foundation
import HAP

class HomeKitBridge: AccessoryDelegate {
    let device: Device
    private let server: Server

    var setupCode: String { device.setupCode }
    private var accessories: [UUID: (accessory: Accessory.Thermometer, humidity: Service.HumiditySensor, battery: Service.Battery)] = [:]

    // LED strip
    private var lightbulb: Accessory.Lightbulb?
    var ledController: LEDStripController?

    init(knownSensors: [DeviceConfig] = []) throws {
        let storageURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!.appendingPathComponent("BLESensors/hap.json")
        try FileManager.default.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        print("[HomeKit] Storage path: \(storageURL.path)")
        print("[HomeKit] Storage exists: \(FileManager.default.fileExists(atPath: storageURL.path))")
        let storage = FileStorage(filename: storageURL.path)

        // Add the LED strip as a permanent accessory
        let bulb = Accessory.Lightbulb(
            info: Service.Info(name: "LED Strip", serialNumber: "LED-001"),
            type: .color,
            isDimmable: true
        )
        lightbulb = bulb

        // Pre-create accessories for known HomeKit sensors so they are
        // passed into Device init and not re-added dynamically on each run.
        var initialAccessories: [Accessory] = [bulb]
        for config in knownSensors where config.homekit {
            let humidity = Service.HumiditySensor()
            let battery = Service.Battery()
            let accessory = Accessory.Thermometer(
                info: Service.Info(
                    name: config.alias.isEmpty ? "Sensor" : config.alias,
                    serialNumber: config.uuid.uuidString.prefix(8).description
                ),
                additionalServices: [humidity, battery]
            )
            accessory.reachable = false
            accessories[config.uuid] = (accessory, humidity, battery)
            initialAccessories.append(accessory)
        }

        device = Device(
            bridgeInfo: Service.Info(name: "BLE Thermo", serialNumber: "BT-001"),
            setupCode: .random,
            storage: storage,
            accessories: initialAccessories
        )

        server = try Server(device: device, listenPort: 0)
        print("[HomeKit] Server started")
        print("[HomeKit] Setup code: \(device.setupCode)")
        print("[HomeKit] Accessories: \(initialAccessories.count)")

        bulb.delegate = self
    }

    // MARK: - AccessoryDelegate

    func characteristic<T>(_ characteristic: GenericCharacteristic<T>,
                            ofService service: Service,
                            ofAccessory accessory: Accessory,
                            didChangeValue newValue: T?) {
        guard accessory === lightbulb, let led = ledController else { return }

        switch characteristic.type {
        case .powerState:
            if let on = newValue as? Bool { led.setPower(on) }
        case .brightness:
            if let pct = newValue as? Int { led.setBrightness(pct) }
        case .hue:
            let h = (newValue as? Float) ?? lightbulb?.lightbulb.hue?.value ?? 0
            let s = lightbulb?.lightbulb.saturation?.value ?? 0
            led.setColor(hue: h, saturation: s)
        case .saturation:
            let h = lightbulb?.lightbulb.hue?.value ?? 0
            let s = (newValue as? Float) ?? lightbulb?.lightbulb.saturation?.value ?? 0
            led.setColor(hue: h, saturation: s)
        default:
            break
        }
    }

    // MARK: - Temperature sensors

    func addSensor(_ sensor: SensorReading) {
        guard accessories[sensor.id] == nil else { return }

        let humidity = Service.HumiditySensor()
        let battery = Service.Battery()

        let accessory = Accessory.Thermometer(
            info: Service.Info(
                name: sensor.displayName,
                serialNumber: sensor.id.uuidString.prefix(8).description
            ),
            additionalServices: [humidity, battery]
        )

        let tempC = (sensor.tempF - 32) * 5 / 9
        accessory.temperatureSensor.currentTemperature.value = Float(tempC)
        humidity.currentRelativeHumidity.value = Float(sensor.humidity)
        battery.batteryLevel?.value = UInt8(min(100, max(0, sensor.battery)))
        battery.statusLowBattery.value = sensor.battery < 15 ? .batteryLow : .batteryNormal

        accessories[sensor.id] = (accessory, humidity, battery)
        device.addAccessories([accessory])
    }

    func removeSensor(id: UUID) {
        guard let entry = accessories.removeValue(forKey: id) else { return }
        device.removeAccessories([entry.accessory])
    }

    func updateSensor(_ sensor: SensorReading) {
        guard let entry = accessories[sensor.id] else { return }

        entry.accessory.reachable = true
        let tempC = (sensor.tempF - 32) * 5 / 9
        entry.accessory.temperatureSensor.currentTemperature.value = Float(tempC)
        entry.humidity.currentRelativeHumidity.value = Float(sensor.humidity)
        entry.battery.batteryLevel?.value = UInt8(min(100, max(0, sensor.battery)))
        entry.battery.statusLowBattery.value = sensor.battery < 15 ? .batteryLow : .batteryNormal
    }

    func markUnreachable(id: UUID) {
        accessories[id]?.accessory.reachable = false
    }
}
