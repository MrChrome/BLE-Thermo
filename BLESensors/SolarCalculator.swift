import Foundation

/// Computes sunrise and sunset times using the NOAA solar algorithm.
/// Hardcoded for Detroit, MI (42.33°N, 83.05°W).
enum SolarCalculator {
    private static let latitude  =  42.33
    private static let longitude = -83.05

    struct SunTimes {
        let sunrise: Date
        let sunset:  Date
    }

    static func sunTimes(for date: Date = Date()) -> SunTimes? {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let year      = calendar.component(.year, from: date)

        // Fractional year (radians)
        let daysInYear: Double = isLeapYear(year) ? 366 : 365
        let gamma = 2 * .pi / daysInYear * (Double(dayOfYear) - 1)

        // Equation of time (minutes)
        let eqTime = 229.18 * (0.000075
            + 0.001868 * cos(gamma)
            - 0.032077 * sin(gamma)
            - 0.014615 * cos(2 * gamma)
            - 0.04089  * sin(2 * gamma))

        // Solar declination (radians)
        let decl = 0.006918
            - 0.399912 * cos(gamma)
            + 0.070257 * sin(gamma)
            - 0.006758 * cos(2 * gamma)
            + 0.000907 * sin(2 * gamma)
            - 0.002697 * cos(3 * gamma)
            + 0.00148  * sin(3 * gamma)

        let latRad = latitude * .pi / 180

        // Hour angle at sunrise/sunset (radians)
        let cosHa = (cos(90.833 * .pi / 180) / (cos(latRad) * cos(decl))) - tan(latRad) * tan(decl)
        guard cosHa >= -1, cosHa <= 1 else { return nil } // polar day/night
        let ha = acos(cosHa) * 180 / .pi  // degrees

        // UTC minutes of sunrise and sunset
        let timezoneOffsetSeconds = Double(TimeZone.current.secondsFromGMT(for: date))
        let sunriseUTC = 720 - 4 * (longitude + ha) - eqTime  // minutes since midnight UTC
        let sunsetUTC  = 720 - 4 * (longitude - ha) - eqTime

        let startOfDay = calendar.startOfDay(for: date)
        let sunrise = startOfDay.addingTimeInterval(sunriseUTC * 60 + timezoneOffsetSeconds)
        let sunset  = startOfDay.addingTimeInterval(sunsetUTC  * 60 + timezoneOffsetSeconds)

        return SunTimes(sunrise: sunrise, sunset: sunset)
    }

    /// Returns the current lighting phase and a 0–1 progress value within that phase.
    enum Phase {
        case day        // light blue
        case goldenHour // blue → gold transition (90 min before sunset)
        case night      // cream
    }

    static func currentPhase(now: Date = Date()) -> (phase: Phase, progress: Double) {
        guard let times = sunTimes(for: now) else { return (.day, 0) }

        let goldenStart  = times.sunset.addingTimeInterval(-180 * 60)
        let goldenPeak   = times.sunset.addingTimeInterval(-90 * 60)

        if now < times.sunrise || now >= times.sunset {
            return (.night, 0)
        } else if now < goldenStart {
            return (.day, 0)
        } else if now < goldenPeak {
            // Transition from blue → gold over 90 minutes
            let progress = now.timeIntervalSince(goldenStart) / (90 * 60)
            return (.goldenHour, min(1, max(0, progress)))
        } else {
            // Hold at full gold until sunset
            return (.goldenHour, 1.0)
        }
    }

    /// Interpolated RGB for the current time of day.
    static func currentColor(now: Date = Date()) -> (r: UInt8, g: UInt8, b: UInt8) {
        let (phase, progress) = currentPhase(now: now)
        switch phase {
        case .day:
            // Light blue: #ADD8E6
            return (0xAD, 0xD8, 0xE6)
        case .goldenHour:
            // Lerp from light blue → deep orange: #FF6000
            return lerp(from: (0xAD, 0xD8, 0xE6), to: (0xFF, 0x60, 0x00), t: progress)
        case .night:
            // Warm orange-cream: #FF7820
            return (0xFF, 0x78, 0x20)
        }
    }

    // MARK: - Helpers

    private static func lerp(
        from a: (UInt8, UInt8, UInt8),
        to b: (UInt8, UInt8, UInt8),
        t: Double
    ) -> (UInt8, UInt8, UInt8) {
        func mix(_ x: UInt8, _ y: UInt8) -> UInt8 {
            UInt8(Double(x) + (Double(y) - Double(x)) * t)
        }
        return (mix(a.0, b.0), mix(a.1, b.1), mix(a.2, b.2))
    }

    private static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }
}
