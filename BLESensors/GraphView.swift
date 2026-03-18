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

private struct GraphCard: View {
    let title: String
    let points: [SensorDatabase.DataPoint]
    let color: Color
    let range: SensorDatabase.TimeRange

    private var minVal: Double { (points.map(\.value).min() ?? 0) - 1 }
    private var maxVal: Double { (points.map(\.value).max() ?? 100) + 1 }
    private var xDomain: ClosedRange<Date> {
        let end = Date()
        let start = end.addingTimeInterval(Double(-range.seconds))
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
        case .hour:  return .dateTime.hour().minute()
        case .day:   return .dateTime.hour()
        case .month: return .dateTime.month().day()
        case .year:  return .dateTime.month()
        }
    }
}
