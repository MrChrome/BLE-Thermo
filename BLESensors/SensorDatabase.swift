import Foundation
import SQLite3

/// Persistent SQLite store for sensor readings, intended for graphing historical data.
class SensorDatabase {
    private var db: OpaquePointer?

    init() {
        guard let url = Self.databaseURL else {
            print("[DB] Could not resolve database path")
            return
        }

        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            print("[DB] Failed to open database: \(String(cString: sqlite3_errmsg(db)))")
            return
        }

        execute("""
            CREATE TABLE IF NOT EXISTS readings (
                timestamp INTEGER NOT NULL,
                name      TEXT NOT NULL,
                temp_f    REAL NOT NULL,
                humidity  REAL NOT NULL
            );
        """)

        execute("""
            CREATE INDEX IF NOT EXISTS idx_readings_name_time
            ON readings (name, timestamp);
        """)

        print("[DB] Opened at \(url.path)")
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Write

    func log(sensors: [SensorReading]) {
        let timestamp = Int(Date().timeIntervalSince1970)
        let sql = "INSERT INTO readings (timestamp, name, temp_f, humidity) VALUES (?, ?, ?, ?);"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        for sensor in sensors {
            let name = sensor.displayName
            sqlite3_bind_int64(stmt, 1, Int64(timestamp))
            sqlite3_bind_text(stmt, 2, (name as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 3, sensor.tempF)
            sqlite3_bind_double(stmt, 4, sensor.humidity)
            sqlite3_step(stmt)
            sqlite3_reset(stmt)
        }
    }

    // MARK: - Read

    struct DataPoint {
        let timestamp: Date
        let value: Double
    }

    enum TimeRange: String, CaseIterable {
        case hour  = "1 Hour"
        case day   = "1 Day"
        case month = "1 Month"
        case year  = "1 Year"

        var seconds: Int {
            switch self {
            case .hour:  return 3_600
            case .day:   return 86_400
            case .month: return 86_400 * 30
            case .year:  return 86_400 * 365
            }
        }
    }

    func fetch(name: String, range: TimeRange, column: String) -> [DataPoint] {
        let since = Int(Date().timeIntervalSince1970) - range.seconds
        let sql = "SELECT timestamp, \(column) FROM readings WHERE name = ? AND timestamp >= ? ORDER BY timestamp ASC;"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (name as NSString).utf8String, -1, nil)
        sqlite3_bind_int64(stmt, 2, Int64(since))

        var points: [DataPoint] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let ts   = sqlite3_column_int64(stmt, 0)
            let val  = sqlite3_column_double(stmt, 1)
            points.append(DataPoint(timestamp: Date(timeIntervalSince1970: Double(ts)), value: val))
        }
        return points
    }

    // MARK: - Private

    private func execute(_ sql: String) {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK,
           let err {
            print("[DB] Error: \(String(cString: err))")
            sqlite3_free(err)
        }
    }

    private static var databaseURL: URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("BLESensors/sensor_history.sqlite")
    }
}
