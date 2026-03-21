import Foundation
import Network

class WebServer {
    private let database: SensorDatabase
    private var listener: NWListener?

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
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self else { connection.cancel(); return }

            var data = accumulated
            if let content { data.append(content) }

            // Check if we have a complete HTTP request (headers end with \r\n\r\n)
            if let str = String(data: data, encoding: .utf8), str.contains("\r\n\r\n") {
                self.handleHTTPRequest(str, on: connection)
            } else if isComplete || error != nil {
                connection.cancel()
            } else {
                self.receiveData(on: connection, accumulated: data)
            }
        }
    }

    private func handleHTTPRequest(_ raw: String, on connection: NWConnection) {
        guard let firstLine = raw.split(separator: "\r\n").first else {
            connection.cancel()
            return
        }

        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" else {
            sendResponse(on: connection, status: "405 Method Not Allowed",
                         contentType: "text/plain", body: "Method Not Allowed")
            return
        }

        let uri = String(parts[1])
        route(uri: uri, on: connection)
    }

    // MARK: - Routing

    private func route(uri: String, on connection: NWConnection) {
        let (path, query) = splitURI(uri)

        switch path {
        case "/", "/index.html":
            sendResponse(on: connection, status: "200 OK",
                         contentType: "text/html; charset=utf-8",
                         body: WebDashboardHTML.page)

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

        default:
            sendResponse(on: connection, status: "404 Not Found",
                         contentType: "text/plain", body: "Not Found")
        }
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
