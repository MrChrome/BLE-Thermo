import Foundation
import Network

class WebServer {
    private let database: SensorDatabase
    private var listener: NWListener?

    private var dashboardTitle: String {
        get { UserDefaults.standard.string(forKey: "dashboardTitle") ?? "BLE Thermo" }
        set { UserDefaults.standard.set(newValue, forKey: "dashboardTitle") }
    }

    private var floorplanImageURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("floorplan_image")
    }

    private var floorplanContentType: String {
        get { UserDefaults.standard.string(forKey: "floorplanContentType") ?? "image/jpeg" }
        set { UserDefaults.standard.set(newValue, forKey: "floorplanContentType") }
    }

    private var sensorPositionsJSON: String {
        get { UserDefaults.standard.string(forKey: "sensorPositions") ?? "{}" }
        set { UserDefaults.standard.set(newValue, forKey: "sensorPositions") }
    }

    init(database: SensorDatabase) {
        self.database = database
    }

    func start() {
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            listener = try NWListener(using: params, on: 80)
        } catch {
            print("[Web] Failed to create listener on port 80: \(error)")
            return
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                if let port = self.listener?.port {
                    print("[Web] Server listening on port \(port)")
                }
            case .failed(let error):
                print("[Web] Server failed: \(error)")
            default:
                break
            }
        }

        listener?.start(queue: .global(qos: .userInitiated))
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        receiveData(on: connection, accumulated: Data())
    }

    private func receiveData(on connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self] content, _, isComplete, error in
            guard let self else { connection.cancel(); return }

            var data = accumulated
            if let content { data.append(content) }

            // Find header/body boundary
            let separator = Data("\r\n\r\n".utf8)
            guard let sepRange = data.range(of: separator) else {
                if isComplete || error != nil { connection.cancel() }
                else { self.receiveData(on: connection, accumulated: data) }
                return
            }

            let headerData = data[data.startIndex..<sepRange.lowerBound]
            guard let headerStr = String(data: headerData, encoding: .utf8) else {
                connection.cancel(); return
            }

            let bodyData = Data(data[sepRange.upperBound...])
            let contentLength = self.parseContentLength(from: headerStr)

            if bodyData.count >= contentLength {
                self.handleHTTPRequest(headerStr, bodyData: Data(bodyData.prefix(contentLength)), on: connection)
            } else if isComplete || error != nil {
                connection.cancel()
            } else {
                self.receiveData(on: connection, accumulated: data)
            }
        }
    }

    private func parseContentLength(from headers: String) -> Int {
        for line in headers.components(separatedBy: "\r\n") {
            if line.lowercased().hasPrefix("content-length:") {
                let val = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
                return Int(val) ?? 0
            }
        }
        return 0
    }

    private func extractHeader(_ name: String, from headers: String) -> String? {
        for line in headers.components(separatedBy: "\r\n") {
            if line.lowercased().hasPrefix(name.lowercased() + ":") {
                return String(line.dropFirst(name.count + 1)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private func handleHTTPRequest(_ header: String, bodyData: Data, on connection: NWConnection) {
        guard let firstLine = header.split(separator: "\r\n").first else {
            connection.cancel()
            return
        }

        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { connection.cancel(); return }
        let method = String(parts[0])
        let uri = String(parts[1])

        switch method {
        case "GET":
            route(uri: uri, on: connection)
        case "POST":
            routePost(uri: uri, bodyData: bodyData, header: header, on: connection)
        case "OPTIONS":
            sendResponse(on: connection, status: "204 No Content", contentType: "text/plain", body: "")
        default:
            sendResponse(on: connection, status: "405 Method Not Allowed",
                         contentType: "text/plain", body: "Method Not Allowed")
        }
    }

    // MARK: - Routing

    private func route(uri: String, on connection: NWConnection) {
        let (path, query) = splitURI(uri)

        switch path {
        case "/", "/index.html":
            sendResponse(on: connection, status: "200 OK",
                         contentType: "text/html; charset=utf-8",
                         body: WebDashboardHTML.page)

        case "/api/title":
            let json = "{\"title\":\"\(escapeJSON(dashboardTitle))\"}"
            sendResponse(on: connection, status: "200 OK",
                         contentType: "application/json", body: json)

        case "/api/sensors":
            let names = database.allSensorNames()
            let json = "{\"sensors\":[\(names.map { "\"\(escapeJSON($0))\"" }.joined(separator: ","))]}"
            sendResponse(on: connection, status: "200 OK",
                         contentType: "application/json", body: json)

        case "/api/data":
            let range = timeRange(from: query["range"] ?? "day")
            let json: String

            if let sensorName = query["sensor"]?.removingPercentEncoding {
                let temp = database.fetch(name: sensorName, range: range, column: "temp_f")
                let hum = database.fetch(name: sensorName, range: range, column: "humidity")
                json = serializeJSON(
                    temp: [sensorName: temp],
                    humidity: [sensorName: hum]
                )
            } else {
                let temp = database.fetchAll(range: range, column: "temp_f")
                let hum = database.fetchAll(range: range, column: "humidity")
                json = serializeJSON(temp: temp, humidity: hum)
            }

            sendResponse(on: connection, status: "200 OK",
                         contentType: "application/json", body: json)

        case "/api/floorplan":
            if let imageData = try? Data(contentsOf: floorplanImageURL) {
                sendBinaryResponse(on: connection, status: "200 OK",
                                   contentType: floorplanContentType, data: imageData)
            } else {
                sendResponse(on: connection, status: "404 Not Found",
                             contentType: "text/plain", body: "No floor plan uploaded")
            }

        case "/api/floorplan/positions":
            sendResponse(on: connection, status: "200 OK",
                         contentType: "application/json", body: sensorPositionsJSON)

        default:
            sendResponse(on: connection, status: "404 Not Found",
                         contentType: "text/plain", body: "Not Found")
        }
    }

    private func routePost(uri: String, bodyData: Data, header: String, on connection: NWConnection) {
        let (path, _) = splitURI(uri)
        switch path {
        case "/api/title":
            let body = String(data: bodyData, encoding: .utf8) ?? ""
            if let titleValue = extractJSONString(key: "title", from: body), !titleValue.isEmpty {
                dashboardTitle = titleValue
                sendResponse(on: connection, status: "200 OK",
                             contentType: "application/json", body: "{\"title\":\"\(escapeJSON(titleValue))\"}")
            } else {
                sendResponse(on: connection, status: "400 Bad Request",
                             contentType: "text/plain", body: "Missing title")
            }

        case "/api/floorplan":
            let contentType = extractHeader("Content-Type", from: header) ?? "image/jpeg"
            floorplanContentType = contentType
            do {
                try bodyData.write(to: floorplanImageURL)
                sendResponse(on: connection, status: "200 OK",
                             contentType: "application/json", body: "{\"ok\":true}")
            } catch {
                sendResponse(on: connection, status: "500 Internal Server Error",
                             contentType: "text/plain", body: "Failed to save floor plan")
            }

        case "/api/floorplan/positions":
            if let str = String(data: bodyData, encoding: .utf8), !str.isEmpty {
                sensorPositionsJSON = str
                sendResponse(on: connection, status: "200 OK",
                             contentType: "application/json", body: "{\"ok\":true}")
            } else {
                sendResponse(on: connection, status: "400 Bad Request",
                             contentType: "text/plain", body: "Invalid data")
            }

        default:
            sendResponse(on: connection, status: "404 Not Found",
                         contentType: "text/plain", body: "Not Found")
        }
    }

    /// Minimal extraction of a single string value from a flat JSON object.
    private func extractJSONString(key: String, from json: String) -> String? {
        let pattern = "\"\(key)\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: json, range: NSRange(json.startIndex..., in: json)),
              let range = Range(match.range(at: 1), in: json) else { return nil }
        // Unescape basic JSON escapes
        return String(json[range])
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
            .replacingOccurrences(of: "\\/", with: "/")
    }

    // MARK: - HTTP Response

    private func sendResponse(on connection: NWConnection, status: String,
                              contentType: String, body: String) {
        let bodyData = Data(body.utf8)
        let header = """
        HTTP/1.1 \(status)\r
        Content-Type: \(contentType)\r
        Content-Length: \(bodyData.count)\r
        Access-Control-Allow-Origin: *\r
        Connection: close\r
        \r\n
        """
        var responseData = Data(header.utf8)
        responseData.append(bodyData)

        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func sendBinaryResponse(on connection: NWConnection, status: String,
                                    contentType: String, data bodyData: Data) {
        let header = "HTTP/1.1 \(status)\r\nContent-Type: \(contentType)\r\nContent-Length: \(bodyData.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
        var responseData = Data(header.utf8)
        responseData.append(bodyData)
        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - Helpers

    private func splitURI(_ uri: String) -> (path: String, query: [String: String]) {
        guard let idx = uri.firstIndex(of: "?") else { return (uri, [:]) }
        let path = String(uri[..<idx])
        let queryString = uri[uri.index(after: idx)...]
        var params: [String: String] = [:]
        for pair in queryString.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2 {
                params[String(kv[0])] = String(kv[1])
            }
        }
        return (path, params)
    }

    private func timeRange(from string: String) -> SensorDatabase.TimeRange {
        switch string.lowercased() {
        case "hour", "1h":       return .hour
        case "6h", "6hours":     return .sixHours
        case "today":            return .today
        case "yesterday":        return .yesterday
        case "day", "1d":        return .day
        case "month", "1m":      return .month
        case "year", "1y":       return .year
        default:                 return .day
        }
    }

    private func escapeJSON(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func serializeJSON(
        temp: [String: [SensorDatabase.DataPoint]],
        humidity: [String: [SensorDatabase.DataPoint]]
    ) -> String {
        func serializeSeries(_ data: [String: [SensorDatabase.DataPoint]]) -> String {
            let entries = data.map { name, points in
                let pts = points.map { p in
                    "{\"t\":\(Int(p.timestamp.timeIntervalSince1970)),\"v\":\(String(format: "%.1f", p.value))}"
                }.joined(separator: ",")
                return "\"\(escapeJSON(name))\":[\(pts)]"
            }.joined(separator: ",")
            return "{\(entries)}"
        }
        return "{\"temperature\":\(serializeSeries(temp)),\"humidity\":\(serializeSeries(humidity))}"
    }
}
