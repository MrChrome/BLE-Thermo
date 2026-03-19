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

    /// Replaces all stored data for `name` with the provided history records.
    /// Runs inside a single transaction for performance.
    func importHistory(name: String, records: [GoveeHistoryRecord]) {
        execute("BEGIN TRANSACTION;")
        execute("DELETE FROM readings WHERE name = '\(name.replacingOccurrences(of: "'", with: "''"))';")

        let sql = "INSERT INTO readings (timestamp, name, temp_f, humidity) VALUES (?, ?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            execute("ROLLBACK;")
            return
        }
        defer { sqlite3_finalize(stmt) }

        for record in records {
            sqlite3_bind_int64(stmt, 1, Int64(record.timestamp.timeIntervalSince1970))
            sqlite3_bind_text(stmt, 2, (name as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 3, record.tempF)
            sqlite3_bind_double(stmt, 4, record.humidity)
            sqlite3_step(stmt)
            sqlite3_reset(stmt)
        }

        execute("COMMIT;")
    }

    // MARK: - Read

    struct DataPoint {
        let timestamp: Date
        let value: Double
    }

    enum TimeRange: String, CaseIterable {
        case hour      = "1 Hour"
        case today     = "Today"
        case yesterday = "Yesterday"
        case day       = "1 Day"
        case month     = "1 Month"
        case year      = "1 Year"

        /// For rolling ranges, returns seconds to look back. Nil for calendar-day ranges.
        var rollingSeconds: Int? {
            switch self {
            case .hour:      return 3_600
            case .day:       return 86_400
            case .month:     return 86_400 * 30
            case .year:      return 86_400 * 365
            case .today, .yesterday: return nil
            }
        }

        /// Returns the start and end of the calendar day for fixed ranges.
        var calendarBounds: (start: Date, end: Date)? {
            let calendar = Calendar.current
            switch self {
            case .today:
                let start = calendar.startOfDay(for: Date())
                return (start, Date())
            case .yesterday:
                let todayStart = calendar.startOfDay(for: Date())
                let start = calendar.date(byAdding: .day, value: -1, to: todayStart)!
                return (start, todayStart)
            default:
                return nil
            }
        }
    }

    func fetch(name: String, range: TimeRange, column: String) -> [DataPoint] {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        if let bounds = range.calendarBounds {
            let sql = "SELECT timestamp, \(column) FROM readings WHERE name = ? AND timestamp >= ? AND timestamp < ? ORDER BY timestamp ASC;"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            sqlite3_bind_text(stmt, 1, (name as NSString).utf8String, -1, nil)
            sqlite3_bind_int64(stmt, 2, Int64(bounds.start.timeIntervalSince1970))
            sqlite3_bind_int64(stmt, 3, Int64(bounds.end.timeIntervalSince1970))
        } else {
            let since = Int64(Date().timeIntervalSince1970) - Int64(range.rollingSeconds ?? 86_400)
            let sql = "SELECT timestamp, \(column) FROM readings WHERE name = ? AND timestamp >= ? ORDER BY timestamp ASC;"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            sqlite3_bind_text(stmt, 1, (name as NSString).utf8String, -1, nil)
            sqlite3_bind_int64(stmt, 2, since)
        }

        var points: [DataPoint] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let ts  = sqlite3_column_int64(stmt, 0)
            let val = sqlite3_column_double(stmt, 1)
            points.append(DataPoint(timestamp: Date(timeIntervalSince1970: Double(ts)), value: val))
        }
        return points
    }

    /// Returns data for all sensors, keyed by sensor name.
    func fetchAll(range: TimeRange, column: String) -> [String: [DataPoint]] {
        // First get all distinct names in the time window
        var nameStmt: OpaquePointer?
        defer { sqlite3_finalize(nameStmt) }

        let nameSql: String
        if let bounds = range.calendarBounds {
            nameSql = "SELECT DISTINCT name FROM readings WHERE timestamp >= ? AND timestamp < ?;"
            guard sqlite3_prepare_v2(db, nameSql, -1, &nameStmt, nil) == SQLITE_OK else { return [:] }
            sqlite3_bind_int64(nameStmt, 1, Int64(bounds.start.timeIntervalSince1970))
            sqlite3_bind_int64(nameStmt, 2, Int64(bounds.end.timeIntervalSince1970))
        } else {
            let since = Int64(Date().timeIntervalSince1970) - Int64(range.rollingSeconds ?? 86_400)
            nameSql = "SELECT DISTINCT name FROM readings WHERE timestamp >= ?;"
            guard sqlite3_prepare_v2(db, nameSql, -1, &nameStmt, nil) == SQLITE_OK else { return [:] }
            sqlite3_bind_int64(nameStmt, 1, since)
        }

        var names: [String] = []
        while sqlite3_step(nameStmt) == SQLITE_ROW {
            if let cStr = sqlite3_column_text(nameStmt, 0) {
                names.append(String(cString: cStr))
            }
        }

        var result: [String: [DataPoint]] = [:]
        for name in names {
            result[name] = fetch(name: name, range: range, column: column)
        }
        return result
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
