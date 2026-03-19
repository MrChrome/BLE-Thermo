import CoreBluetooth
import Foundation

struct GoveeHistoryRecord {
    let timestamp: Date
    let tempF: Double
    let humidity: Double
}

@MainActor
@Observable
class GoveeHistoryDownloader {
    var status: String = "Idle"
    var records: [GoveeHistoryRecord] = []
    var isDownloading = false
    var progress: Double = 0  // 0.0 – 1.0

    private var bleDelegate: ObjCBLEDelegate?
    private var peripheral: CBPeripheral?
    private var downloadTime: Date = Date()
    private var dataPacketCount = 0
    private var oldestMinutesBack: Int = 0   // largest minutesBack seen (first packets)
    private var newestMinutesBack: Int = 0   // smallest minutesBack seen (last packets)
    private var nextRequestMinutes: Int = 28800  // window to request on next connect
    private var resumeCount: Int = 0
    private weak var database: SensorDatabase?
    private var sensorName: String = ""

    private let totalRequestedMinutes = 28800
    private let maxResumes = 5

    func start(peripheral: CBPeripheral, bleDelegate: ObjCBLEDelegate, sensorName: String, database: SensorDatabase) {
        guard !isDownloading else { return }
        isDownloading = true
        records = []
        dataPacketCount = 0
        progress = 0
        downloadTime = Date()
        oldestMinutesBack = 0
        newestMinutesBack = 0
        nextRequestMinutes = totalRequestedMinutes
        resumeCount = 0
        status = "Connecting…"

        self.peripheral = peripheral
        self.bleDelegate = bleDelegate
        self.sensorName = sensorName
        self.database = database

        attachCallbacks(bleDelegate: bleDelegate)
        bleDelegate.beginGoveeHistory(peripheral)
    }

    func cancel() {
        bleDelegate?.endGoveeHistory()
        clearCallbacks()
        peripheral = nil
        isDownloading = false
        status = "Cancelled"
    }

    // MARK: - Internal

    private func attachCallbacks(bleDelegate: ObjCBLEDelegate) {
        bleDelegate.onGoveeReady = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.status = "Requesting history…"
                bleDelegate.sendGoveeCommand(Self.historyCommand(minutes: self.nextRequestMinutes))
            }
        }

        bleDelegate.onGoveeData = { [weak self] packet in
            guard let packet else { return }
            Task { @MainActor [weak self] in
                self?.handleDataPacket(packet)
            }
        }

        bleDelegate.onGoveeControl = { [weak self] packet in
            guard let packet else { return }
            Task { @MainActor [weak self] in
                self?.handleControlPacket(packet)
            }
        }

        bleDelegate.onGoveeDisconnect = { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleDisconnect()
            }
        }
    }

    private func handleDisconnect() {
        // If we got some records but not enough, retry up to maxResumes times.
        // The device sometimes drops mid-transfer; reconnecting usually gets more data.
        let gotData = dataPacketCount > 0
        if resumeCount < maxResumes, let peripheral, let bleDelegate {
            resumeCount += 1
            // Request from just past where we stopped, skipping 60 minutes over the trouble spot
            nextRequestMinutes = newestMinutesBack - 60
            dataPacketCount = 0
            oldestMinutesBack = 0
            newestMinutesBack = 0
            status = "Resuming (\(resumeCount)/\(maxResumes))… (\(records.count) records so far)"
            NSLog(status)
            bleDelegate.beginGoveeHistory(peripheral)
            attachCallbacks(bleDelegate: bleDelegate)
        } else {
            finish()
        }
    }

    private func finish() {
        // minutesBack values are relative to the device's internal clock, not wall time.
        // Shift all timestamps so the newest record (smallest minutesBack) aligns with downloadTime.
        if newestMinutesBack > 0 {
            let shift = TimeInterval(newestMinutesBack) * 60
            records = records.map {
                GoveeHistoryRecord(timestamp: $0.timestamp.addingTimeInterval(shift),
                                   tempF: $0.tempF, humidity: $0.humidity)
            }
        }
        records.sort { $0.timestamp < $1.timestamp }
        progress = 1.0
        status = "Done — \(records.count) records downloaded"
        database?.importHistory(name: sensorName, records: records)
        clearCallbacks()
        peripheral = nil
        isDownloading = false
    }

    // MARK: - Packet handling

    private func handleDataPacket(_ data: Data) {
        guard data.count >= 2 else { return }
        dataPacketCount += 1

        let minutesBack = Int(data[0]) << 8 | Int(data[1])

        // Track range of minutesBack values seen
        if oldestMinutesBack == 0 || minutesBack > oldestMinutesBack { oldestMinutesBack = minutesBack }
        if newestMinutesBack == 0 || minutesBack < newestMinutesBack { newestMinutesBack = minutesBack }

        // Progress: minutesBack counts down toward 0, so invert
        progress = min(1.0, max(progress, 1.0 - Double(minutesBack) / Double(oldestMinutesBack)))
        status = "Receiving… (\(records.count) records)"

        for i in 0..<6 {
            let offset = 2 + i * 3
            guard offset + 2 < data.count else { break }
            let b0 = data[offset], b1 = data[offset + 1], b2 = data[offset + 2]
            guard b0 != 0xFF else { continue }

            let raw = Int(b0) << 16 | Int(b1) << 8 | Int(b2)
            let negative = (raw & 0x800000) != 0
            let value = negative ? (raw ^ 0x800000) : raw
            let tempC = Double(value / 1000) / 10.0 * (negative ? -1 : 1)
            let humidity = Double(value % 1000) / 10.0
            let tempF = tempC * 9.0 / 5.0 + 32.0

            // Timestamp relative to downloadTime using raw device minutesBack.
            // Will be corrected in finish() once we know newestMinutesBack.
            let timestamp = downloadTime.addingTimeInterval(Double(-(minutesBack - i)) * 60)
            records.append(GoveeHistoryRecord(timestamp: timestamp, tempF: tempF, humidity: humidity))
        }
    }

    private func handleControlPacket(_ data: Data) {
        guard data.count >= 4 else { return }
        if data[0] == 0xEE && data[1] == 0x01 {
            bleDelegate?.endGoveeHistory()
            finish()
        }
    }

    private func clearCallbacks() {
        bleDelegate?.onGoveeReady = nil
        bleDelegate?.onGoveeData = nil
        bleDelegate?.onGoveeControl = nil
        bleDelegate?.onGoveeDisconnect = nil
        bleDelegate = nil
    }

    // MARK: - Command builder

    private static func historyCommand(minutes: Int) -> Data {
        let m = UInt16(min(minutes, 0xFFFF))
        var bytes: [UInt8] = [0x33, 0x01, UInt8(m >> 8), UInt8(m & 0xFF), 0x00, 0x01]
        bytes += [UInt8](repeating: 0x00, count: 13)
        let checksum = bytes.reduce(0) { $0 ^ $1 }
        bytes.append(checksum)
        return Data(bytes)
    }
}
