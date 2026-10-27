// Units.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

enum Units: String, CaseIterable, Identifiable, Codable {
    case metric, imperial

    var id: Self { self }

    static let storageKey = "units"

    static var localeDefault: Units {
        Locale.current.measurementSystem == .us ? .imperial : .metric
    }

    var label: String {
        switch self {
        case .metric: "Metric"
        case .imperial: "Imperial"
        }
    }

    /// Meters below 1 km, then km; feet below 0.1 mi, then miles.
    func format(meters: Double) -> String {
        switch self {
        case .metric:
            if meters < 999.5 { return "\(Int(meters.rounded())) m" }
            return Self.decimal(meters / 1000) + " km"
        case .imperial:
            let miles = meters / 1609.344
            if miles < 0.1 { return "\(Int((meters / 0.3048).rounded())) ft" }
            return Self.decimal(miles) + " mi"
        }
    }

    /// Two decimals below 10, one below 100, none above.
    private static func decimal(_ value: Double) -> String {
        let digits = value < 9.995 ? 2 : value < 99.95 ? 1 : 0
        return String(format: "%.\(digits)f", value)
    }

    /// A position against a bearing line, "15 m left · 220 m along ±10 m", or nil while
    /// still within the GPS margin of the line's start, where GPS cannot place you on it.
    /// Drift within the margin reads as on the line.
    func offset(_ offset: (across: Double, along: Double), margin: Double) -> String? {
        guard hypot(offset.across, offset.along) > margin else { return nil }
        return side(abs(offset.across) <= margin ? 0 : offset.across) + " · " + progress(offset.along) + " ±" + rough(margin)
    }

    func side(_ across: Double) -> String {
        across == 0 ? "on line" : rough(abs(across)) + (across > 0 ? " right" : " left")
    }

    func progress(_ along: Double) -> String {
        along < 0 ? rough(-along) + " behind" : rough(along) + " along"
    }

    /// A distance between two GPS fixes, "40 ft", or nil while it is within the GPS margin.
    func gpsDistance(_ meters: Double, margin: Double) -> String? {
        meters > margin ? rough(meters) : nil
    }

    /// To the nearest 5 m or 10 ft, finer than GPS can tell.
    func rough(_ meters: Double) -> String {
        let step = self == .metric ? 5 : 3.048
        return format(meters: max(step, (meters / step).rounded() * step))
    }
}

enum Elapsed {
    /// "4:07", "1:23:45"
    static func format(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        let h = seconds / 3600, m = seconds / 60 % 60, s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    /// "8 s old", "3 min old", "2 h old"
    static func age(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        if seconds < 60 { return "\(seconds) s old" }
        if seconds < 3600 { return "\(seconds / 60) min old" }
        return "\(seconds / 3600) h old"
    }
}
