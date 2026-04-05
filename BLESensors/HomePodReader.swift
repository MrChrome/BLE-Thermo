import Foundation
import Observation

// Reads temperature and humidity from HomeKit accessories (e.g. HomePods).
// Reports via the onUpdate callback, then polls on a timer.

@Observable
class HomePodReader: NSObject, HMHomeManagerDelegate {
    private let manager = HMHomeManager()
    private var refreshTimer: Timer?
    private(set) var isAuthorized = false

    // Called on the main thread whenever a reading is available.
    // Parameters: (stableID, displayName, tempF, humidity)
    var onUpdate: ((UUID, String, Double, Double) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        print("[HomePod] HMHomeManager initialized, delegate set")
    }

    // MARK: - HMHomeManagerDelegate

    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        print("[HomePod] homeManagerDidUpdateHomes fired, homes: \(manager.homes.count)")
        // authorizationStatus is unavailable on macOS; treat the delegate firing as authorized.
        // If access was denied, manager.homes will simply be empty.
        isAuthorized = true
        fetchAll()
        scheduleTimer()
    }

    // MARK: - Polling

    private func scheduleTimer() {
        refreshTimer?.invalidate()
        // Re-read every 3 minutes; HomePod sensors update infrequently
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3 * 60, repeats: true) { [weak self] _ in
            self?.fetchAll()
        }
    }

    func fetchAll() {
        for home in manager.homes {
            for accessory in home.accessories {
                fetchAccessory(accessory, home: home)
            }
        }
    }

    private func fetchAccessory(_ accessory: HMAccessory, home: HMHome) {
        var tempChar: HMCharacteristic?
        var humChar:  HMCharacteristic?

        for service in accessory.services {
            for char in service.characteristics {
                switch char.characteristicType {
                case HMCharacteristicTypeCurrentTemperature:
                    tempChar = char
                case HMCharacteristicTypeCurrentRelativeHumidity:
                    humChar = char
                default:
                    break
                }
            }
        }

        guard let tempChar else { return }  // not a temperature-reporting accessory

        tempChar.readValue { [weak self, weak accessory, weak humChar] error in
            guard error == nil, let self, let accessory else { return }
            let tempC = (tempChar.value as? Double)
                     ?? (tempChar.value as? NSNumber).map { Double(truncating: $0) }
                     ?? 0.0

            if let humChar {
                humChar.readValue { [weak self, weak accessory] _ in
                    guard let self, let accessory else { return }
                    let hum = (humChar.value as? Double)
                            ?? (humChar.value as? NSNumber).map { Double(truncating: $0) }
                            ?? 0.0
                    DispatchQueue.main.async {
                        self.report(accessory: accessory, home: home, tempC: tempC, humidity: hum)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.report(accessory: accessory, home: home, tempC: tempC, humidity: 0.0)
                }
            }
        }
    }

    private func report(accessory: HMAccessory, home: HMHome, tempC: Double, humidity: Double) {
        let id = accessory.uniqueIdentifier
        let roomName = accessory.room?.name
        let name: String
        if let room = roomName, room != "Default Room", room != home.name {
            name = "\(room) — \(accessory.name)"
        } else {
            name = accessory.name
        }
        let tempF = tempC * 9.0 / 5.0 + 32.0
        onUpdate?(id, name, tempF, humidity)
    }
}
