// Units.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

enum Units: String, CaseIterable, Identifiable {
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
}

enum Elapsed {
    /// "4:07", "1:23:45"
    static func format(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        let h = seconds / 3600, m = seconds / 60 % 60, s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
