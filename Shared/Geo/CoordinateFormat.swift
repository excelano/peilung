// CoordinateFormat.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// How coordinates are written, both on screen and in entry.
enum CoordinateFormat: String, CaseIterable, Identifiable {
    /// N 29° 45.123
    case degreesMinutes
    /// N 29° 45′ 07.4″
    case degreesMinutesSeconds
    /// N 29.75205°
    case decimalDegrees

    var id: Self { self }

    static let storageKey = "coordinates"

    var label: String {
        switch self {
        case .degreesMinutes: "Degrees, minutes"
        case .degreesMinutesSeconds: "Degrees, min, sec"
        case .decimalDegrees: "Decimal degrees"
        }
    }

    /// One field of an axis below the degrees, each holding `count` steps of `size`
    /// in the format's smallest unit.
    struct Place {
        let size: Int
        let count: Int
        let width: Int
        let separator: String
    }

    /// The smallest unit, per degree: a thousandth of a minute (about 1.9 m), a tenth
    /// of a second (about 3.1 m) or a hundred-thousandth of a degree (about 1.1 m).
    var perDegree: Int {
        switch self {
        case .degreesMinutes: 60_000
        case .degreesMinutesSeconds: 36_000
        case .decimalDegrees: 100_000
        }
    }

    var degreeSeparator: String { self == .decimalDegrees ? "." : "° " }

    var places: [Place] {
        switch self {
        case .degreesMinutes:
            [Place(size: 1000, count: 60, width: 2, separator: "."), digit(100), digit(10), digit(1)]
        case .degreesMinutesSeconds:
            [Place(size: 600, count: 60, width: 2, separator: "′ "),
             Place(size: 10, count: 60, width: 2, separator: "."),
             digit(1, separator: "″")]
        case .decimalDegrees:
            [digit(10_000), digit(1000), digit(100), digit(10), digit(1, separator: "°")]
        }
    }

    private func digit(_ size: Int, separator: String = "") -> Place {
        Place(size: size, count: 10, width: 1, separator: separator)
    }
}

/// One axis of a coordinate held in integer steps of its format's smallest unit, so
/// formatting never produces "60.000".
struct CoordinateAxis: Equatable {
    let format: CoordinateFormat
    let isLatitude: Bool
    var isNegative: Bool
    var steps: Int

    init(_ value: Double, isLatitude: Bool, format: CoordinateFormat) {
        let steps = Int((abs(value) * Double(format.perDegree)).rounded())
        self.format = format
        self.isLatitude = isLatitude
        self.isNegative = value < 0 && steps > 0
        self.steps = steps
    }

    var value: Double {
        let magnitude = Double(steps) / Double(format.perDegree)
        return isNegative ? -magnitude : magnitude
    }

    var hemisphere: String {
        isLatitude ? (isNegative ? "S" : "N") : (isNegative ? "W" : "E")
    }

    var degrees: Int { steps / format.perDegree }

    var degreeText: String {
        String(format: isLatitude ? "%02d" : "%03d", degrees)
    }

    func text(_ place: CoordinateFormat.Place) -> String {
        String(format: "%0\(place.width)d", steps / place.size % place.count)
    }

    var text: String {
        hemisphere + " " + degreeText + format.degreeSeparator
            + format.places.map { text($0) + $0.separator }.joined()
    }
}

extension Coordinate {
    func latitudeText(_ format: CoordinateFormat) -> String {
        CoordinateAxis(latitude, isLatitude: true, format: format).text
    }

    func longitudeText(_ format: CoordinateFormat) -> String {
        CoordinateAxis(longitude, isLatitude: false, format: format).text
    }
}
