import Foundation
import HAP

class HomeKitBridge {
    let device: Device
    private let server: Server

    var setupCode: String { device.setupCode }
    private var accessories: [UUID: (accessory: Accessory.Thermometer, humidity: Service.HumiditySensor, battery: Service.Battery)] = [:]

    init() throws {
        let storageURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!.appendingPathComponent("BLESensors/hap.json")
        try FileManager.default.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let storage = FileStorage(filename: storageURL.path)

        device = Device(
            bridgeInfo: Service.Info(name: "BLE Thermo", serialNumber: "BT-001"),
            setupCode: .random,
            storage: storage,
            accessories: []
        )

        server = try Server(device: device, listenPort: 0)
    }

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

        let tempC = (sensor.tempF - 32) * 5 / 9
        entry.accessory.temperatureSensor.currentTemperature.value = Float(tempC)
        entry.humidity.currentRelativeHumidity.value = Float(sensor.humidity)
        entry.battery.batteryLevel?.value = UInt8(min(100, max(0, sensor.battery)))
        entry.battery.statusLowBattery.value = sensor.battery < 15 ? .batteryLow : .batteryNormal
    }
}
