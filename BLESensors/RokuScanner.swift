import Foundation
import Darwin

/// Discovers Roku TVs on the local network using SSDP (Simple Service Discovery Protocol)
/// and polls their power state periodically.
class RokuScanner {
    /// Called on the main thread when a new Roku TV is found.
    var onDiscovered: ((RokuDeviceInfo) -> Void)?
    /// Called on the main thread when a known TV's power state changes.
    var onStateChanged: ((String, Bool) -> Void)?

    private var known: [String: String] = [:]    // serial -> ip
    private var discoveryTimer: Timer?
    private var pollTimer: Timer?

    func start() {
        discover()
        discoveryTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.discover()
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.pollAll()
        }
    }

    func stop() {
        discoveryTimer?.invalidate()
        pollTimer?.invalidate()
        discoveryTimer = nil
        pollTimer = nil
    }

    // MARK: - SSDP Discovery

    private func discover() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.runSSDPSearch()
        }
    }

    private func runSSDPSearch() {
        let message = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nST: roku:ecp\r\nMX: 3\r\n\r\n"

        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock != -1 else {
            print("[Roku] SSDP: failed to create socket")
            return
        }
        defer { close(sock) }

        var yes: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

        // Receive timeout of 4 seconds
        var timeout = timeval(tv_sec: 4, tv_usec: 0)
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        // Bind to any local address
        var localAddr = sockaddr_in()
        localAddr.sin_len    = UInt8(MemoryLayout<sockaddr_in>.size)
        localAddr.sin_family = sa_family_t(AF_INET)
        localAddr.sin_port   = 0
        localAddr.sin_addr   = in_addr(s_addr: INADDR_ANY)
        withUnsafePointer(to: &localAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                _ = bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        // Send to SSDP multicast address
        var destAddr = sockaddr_in()
        destAddr.sin_len    = UInt8(MemoryLayout<sockaddr_in>.size)
        destAddr.sin_family = sa_family_t(AF_INET)
        destAddr.sin_port   = CFSwapInt16HostToBig(1900)
        destAddr.sin_addr   = in_addr(s_addr: inet_addr("239.255.255.250"))

        let bytes = Array(message.utf8)
        withUnsafePointer(to: &destAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { dest in
                _ = sendto(sock, bytes, bytes.count, 0, dest, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        print("[Roku] SSDP search sent, waiting for responses...")

        // Collect responses until timeout
        var discoveredIPs: [String] = []
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = recv(sock, &buffer, buffer.count, 0)
            if n <= 0 { break }
            let response = String(bytes: Array(buffer[0..<n]), encoding: .utf8) ?? ""
            if let ip = Self.parseLocation(response) {
                discoveredIPs.append(ip)
            }
        }

        print("[Roku] SSDP found \(discoveredIPs.count) device(s)")

        Task { [weak self] in
            for ip in discoveredIPs {
                await self?.queryDevice(ip: ip)
            }
        }
    }

    // MARK: - Device Query

    private func queryDevice(ip: String) async {
        do {
            let info = try await RokuController.fetchInfo(from: ip)
            let isNew = known[info.serial] == nil
            known[info.serial] = ip
            if isNew {
                print("[Roku] Discovered: \(info.name) at \(ip) (serial: \(info.serial))")
                await MainActor.run { [weak self] in self?.onDiscovered?(info) }
            }
        } catch {
            print("[Roku] Failed to query \(ip): \(error.localizedDescription)")
        }
    }

    // MARK: - State Polling

    private func pollAll() {
        let snapshot = known
        Task { [weak self] in
            for (serial, ip) in snapshot {
                let controller = RokuController(ip: ip, serial: serial, name: "")
                let on = await controller.fetchPowerState()
                await MainActor.run { [weak self] in self?.onStateChanged?(serial, on) }
            }
        }
    }

    // MARK: - Helpers

    private static func parseLocation(_ response: String) -> String? {
        for line in response.components(separatedBy: "\r\n") {
            guard line.lowercased().hasPrefix("location:") else { continue }
            let value = line.dropFirst("location:".count).trimmingCharacters(in: .whitespaces)
            if let url = URL(string: value), let host = url.host {
                return host
            }
        }
        return nil
    }
}
