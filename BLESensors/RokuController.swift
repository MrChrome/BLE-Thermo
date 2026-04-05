import Foundation
import HAP

struct RokuDeviceInfo {
    let name: String
    let serial: String
    let ip: String
    var powerOn: Bool
}

/// Controls a single Roku TV via the External Control Protocol (ECP) REST API.
class RokuController {
    let ip: String
    let serial: String
    let name: String

    private var baseURLString: String { "http://\(ip):8060" }

    init(ip: String, serial: String, name: String) {
        self.ip = ip
        self.serial = serial
        self.name = name
    }

    // MARK: - Discovery

    static func fetchInfo(from ip: String) async throws -> RokuDeviceInfo {
        let url = URL(string: "http://\(ip):8060/query/device-info")!
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = "GET"
        let (data, _) = try await URLSession.shared.data(for: request)
        let xml = String(data: data, encoding: .utf8) ?? ""

        let name = parseXMLField(xml, tag: "friendly-device-name") ?? "Roku TV"
        let serial = parseXMLField(xml, tag: "serial-number") ?? ip
        let powerMode = parseXMLField(xml, tag: "power-mode") ?? "PowerOff"
        let powerOn = powerMode == "PowerOn" || powerMode == "DisplayOn"

        return RokuDeviceInfo(name: name, serial: serial, ip: ip, powerOn: powerOn)
    }

    // MARK: - State Polling

    func fetchPowerState() async -> Bool {
        guard let url = URL(string: "\(baseURLString)/query/device-info") else { return false }
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = "GET"
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let xml = String(data: data, encoding: .utf8) ?? ""
            let powerMode = Self.parseXMLField(xml, tag: "power-mode") ?? "PowerOff"
            return powerMode == "PowerOn" || powerMode == "DisplayOn"
        } catch {
            print("[Roku] Poll failed for \(name): \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Control

    func setPower(_ on: Bool) async {
        await sendKey(on ? "PowerOn" : "PowerOff")
    }

    func volumeUp() async { await sendKey("VolumeUp") }
    func volumeDown() async { await sendKey("VolumeDown") }
    func mute() async { await sendKey("VolumeMute") }

    func sendRemoteKey(_ key: RokuRemoteKey) async {
        await sendKey(key.ecpName)
    }

    func sendKey(_ key: String) async {
        guard let url = URL(string: "\(baseURLString)/keypress/\(key)") else { return }
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = "POST"
        do {
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("[Roku] Keypress \(key) failed for \(name): \(error.localizedDescription)")
        }
    }

    // MARK: - XML Helpers

    static func parseXMLField(_ xml: String, tag: String) -> String? {
        let open = "<\(tag)>"
        let close = "</\(tag)>"
        guard let startRange = xml.range(of: open),
              let endRange = xml.range(of: close, range: startRange.upperBound..<xml.endIndex)
        else { return nil }
        return String(xml[startRange.upperBound..<endRange.lowerBound])
    }
}

// MARK: - Remote key mapping

enum RokuRemoteKey {
    case rewind, fastForward, nextTrack, previousTrack
    case arrowUp, arrowDown, arrowLeft, arrowRight
    case select, back, exit, playPause, info

    var ecpName: String {
        switch self {
        case .rewind:        return "Rev"
        case .fastForward:   return "Fwd"
        case .nextTrack:     return "Right"
        case .previousTrack: return "Left"
        case .arrowUp:       return "Up"
        case .arrowDown:     return "Down"
        case .arrowLeft:     return "Left"
        case .arrowRight:    return "Right"
        case .select:        return "Select"
        case .back:          return "Back"
        case .exit:          return "Home"
        case .playPause:     return "Play"
        case .info:          return "Info"
        }
    }

    init(hapKey: Enums.RemoteKey) {
        switch hapKey {
        case .rewind:        self = .rewind
        case .fastforward:   self = .fastForward
        case .nexttrack:     self = .nextTrack
        case .previoustrack: self = .previousTrack
        case .arrowup:       self = .arrowUp
        case .arrowdown:     self = .arrowDown
        case .arrowleft:     self = .arrowLeft
        case .arrowright:    self = .arrowRight
        case .select:        self = .select
        case .back:          self = .back
        case .exit:          self = .exit
        case .playpause:     self = .playPause
        case .information:   self = .info
        }
    }
}
