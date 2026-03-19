import SwiftUI
import Charts
import Combine

struct GraphWindow: View {
    let sensorName: String
    let database: SensorDatabase
    @State private var range: SensorDatabase.TimeRange = .day
    @State private var tempPoints:     [SensorDatabase.DataPoint] = []
    @State private var humidityPoints: [SensorDatabase.DataPoint] = []

    var body: some View {
        VStack(spacing: 0) {
            // Range picker
            Picker("Range", selection: $range) {
                ForEach(SensorDatabase.TimeRange.allCases, id: \.self) { r in
                    Text(r.rawValue).tag(r)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            if tempPoints.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.line.downtrend.xyaxis",
                    description: Text("No readings recorded for this time range yet.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        GraphCard(title: "Temperature (°F)", points: tempPoints, color: .blue, range: range)
                        GraphCard(title: "Humidity (%)", points: humidityPoints, color: .green, range: range)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(sensorName)
        .frame(minWidth: 480, minHeight: 500)
        .task(id: range) { reload() }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            reload()
        }
    }

    private func reload() {
        tempPoints     = database.fetch(name: sensorName, range: range, column: "temp_f")
        humidityPoints = database.fetch(name: sensorName, range: range, column: "humidity")
    }
}

struct AllSensorsGraphWindow: View {
    let database: SensorDatabase
    @State private var range: SensorDatabase.TimeRange = .day
    @State private var tempData:     [String: [SensorDatabase.DataPoint]] = [:]
    @State private var humidityData: [String: [SensorDatabase.DataPoint]] = [:]
    @State private var hiddenSensors: Set<String> = []

    /// All known sensor names across both datasets, sorted.
    private var allSensorNames: [String] {
        let names = Set(tempData.keys).union(humidityData.keys)
        return names.sorted()
    }

    private var visibleTemp:     [String: [SensorDatabase.DataPoint]] {
        tempData.filter     { !hiddenSensors.contains($0.key) }
    }
    private var visibleHumidity: [String: [SensorDatabase.DataPoint]] {
        humidityData.filter { !hiddenSensors.contains($0.key) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Range", selection: $range) {
                ForEach(SensorDatabase.TimeRange.allCases, id: \.self) { r in
                    Text(r.rawValue).tag(r)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])

            // Sensor toggle chips
            if !allSensorNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(allSensorNames, id: \.self) { name in
                            let hidden = hiddenSensors.contains(name)
                            Button {
                                if hidden {
                                    hiddenSensors.remove(name)
                                } else {
                                    hiddenSensors.insert(name)
                                }
                            } label: {
                                Text(name)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(hidden ? Color.secondary.opacity(0.15) : Color.accentColor.opacity(0.2))
                                    .foregroundStyle(hidden ? .secondary : .primary)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().strokeBorder(hidden ? Color.secondary.opacity(0.3) : Color.accentColor.opacity(0.5), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }

            if tempData.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.line.downtrend.xyaxis",
                    description: Text("No readings recorded for this time range yet.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        MultiSensorGraphCard(title: "Temperature (°F)", seriesData: visibleTemp, range: range)
                        MultiSensorGraphCard(title: "Humidity (%)", seriesData: visibleHumidity, range: range)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("All Sensors")
        .frame(minWidth: 480, minHeight: 500)
        .task(id: range) { reload() }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in reload() }
    }

    private func reload() {
        tempData     = database.fetchAll(range: range, column: "temp_f")
        humidityData = database.fetchAll(range: range, column: "humidity")
    }
}

private struct MultiSensorGraphCard: View {
    let title: String
    let seriesData: [String: [SensorDatabase.DataPoint]]
    let range: SensorDatabase.TimeRange

    struct NamedPoint: Identifiable {
        let id = UUID()
        let name: String
        let timestamp: Date
        let value: Double
    }

    private var allPoints: [NamedPoint] {
        seriesData.flatMap { name, points in
            points.map { NamedPoint(name: name, timestamp: $0.timestamp, value: $0.value) }
        }
    }
    private var minVal: Double { (allPoints.map(\.value).min() ?? 0) - 20 }
    private var maxVal: Double { (allPoints.map(\.value).max() ?? 100) + 1 }
    private var xDomain: ClosedRange<Date> {
        if let bounds = range.calendarBounds { return bounds.start...bounds.end }
        let end = Date()
        return end.addingTimeInterval(Double(-(range.rollingSeconds ?? 86_400)))...end
    }
    private var xFormat: Date.FormatStyle {
        switch range {
        case .hour, .sixHours:    return .dateTime.hour().minute()
        case .today, .yesterday:  return .dateTime.hour()
        case .day:                return .dateTime.hour()
        case .month:              return .dateTime.month().day()
        case .year:               return .dateTime.month()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)

            Chart(allPoints) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(by: .value("Sensor", point.name))
                .interpolationMethod(.catmullRom)
            }
            .chartXScale(domain: xDomain)
            .chartYScale(domain: minVal...maxVal)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: xFormat)
                }
            }
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 220)
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct GraphCard: View {
    let title: String
    let points: [SensorDatabase.DataPoint]
    let color: Color
    let range: SensorDatabase.TimeRange

    private var minVal: Double { (points.map(\.value).min() ?? 0) - 20 }
    private var maxVal: Double { (points.map(\.value).max() ?? 100) + 1 }
    private var xDomain: ClosedRange<Date> {
        if let bounds = range.calendarBounds {
            return bounds.start...bounds.end
        }
        let end = Date()
        let start = end.addingTimeInterval(Double(-(range.rollingSeconds ?? 86_400)))
        return start...end
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Chart(points, id: \.timestamp) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(color)
                .interpolationMethod(.catmullRom)
            }
            .chartXScale(domain: xDomain)
            .chartYScale(domain: minVal...maxVal)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: xFormat)
                }
            }
            .frame(height: 180)
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var xFormat: Date.FormatStyle {
        switch range {
        case .hour, .sixHours:    return .dateTime.hour().minute()
        case .today, .yesterday:  return .dateTime.hour()
        case .day:                return .dateTime.hour()
        case .month:              return .dateTime.month().day()
        case .year:               return .dateTime.month()
        }
    }
}
