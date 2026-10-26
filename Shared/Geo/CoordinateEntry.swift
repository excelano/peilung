// CoordinateEntry.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// The editable fields of a DDM coordinate, one Digital Crown target each.
/// Every field wraps within its own range without carrying into its neighbour,
/// so turning one digit never disturbs the digits already set.
struct CoordinateEntry: Equatable {
    enum Field: Int, CaseIterable {
        case latHemisphere, latDegrees, latMinutes, latHundredths, latTens, latOnes
        case lonHemisphere, lonDegrees, lonMinutes, lonHundredths, lonTens, lonOnes

        var isLatitude: Bool { rawValue < Field.lonHemisphere.rawValue }

        /// What follows the field on screen.
        var separator: String {
            switch self {
            case .latHemisphere, .lonHemisphere: " "
            case .latDegrees, .lonDegrees: "° "
            case .latMinutes, .lonMinutes: "."
            default: ""
            }
        }
    }

    var latitude: DDM
    var longitude: DDM

    init(_ coordinate: Coordinate) {
        latitude = DDM(coordinate.latitude, isLatitude: true)
        longitude = DDM(coordinate.longitude, isLatitude: false)
        Self.clamp(&latitude, to: 89)
        Self.clamp(&longitude, to: 179)
    }

    /// A pole or the antimeridian becomes the nearest value the fields can hold.
    private static func clamp(_ axis: inout DDM, to degrees: Int) {
        guard axis.degrees > degrees else { return }
        axis.degrees = degrees
        axis.minutes = 59
        axis.thousandths = 999
    }

    var coordinate: Coordinate {
        Coordinate(latitude: latitude.value, longitude: longitude.value)
    }

    /// "5.76 mi · 358° M" from where you are to the entered point; at it, no bearing.
    func offset(from here: Coordinate?, units: Units, north: North) -> String {
        guard let here else { return "No position yet" }
        let distance = here.distance(to: coordinate)
        guard distance >= 1 else { return "Where you are" }
        return units.format(meters: distance) + " · " + north.text(true: here.bearing(to: coordinate))
    }

    mutating func adjust(_ field: Field, by steps: Int) {
        if field.isLatitude {
            Self.step(&latitude, field, by: steps)
        } else {
            Self.step(&longitude, field, by: steps)
        }
    }

    /// The text of one field as shown on screen.
    func text(_ field: Field) -> String {
        let axis = field.isLatitude ? latitude : longitude
        switch field {
        case .latHemisphere, .lonHemisphere: return axis.hemisphere
        case .latDegrees, .lonDegrees: return axis.degreeText
        case .latMinutes, .lonMinutes: return String(format: "%02d", axis.minutes)
        case .latHundredths, .lonHundredths: return String(axis.thousandths / 100)
        case .latTens, .lonTens: return String(axis.thousandths / 10 % 10)
        case .latOnes, .lonOnes: return String(axis.thousandths % 10)
        }
    }

    private static func step(_ axis: inout DDM, _ field: Field, by steps: Int) {
        switch field {
        case .latHemisphere, .lonHemisphere:
            if steps % 2 != 0 { axis.isNegative.toggle() }
        case .latDegrees, .lonDegrees:
            axis.degrees = wrap(axis.degrees + steps, axis.isLatitude ? 90 : 180)
        case .latMinutes, .lonMinutes:
            axis.minutes = wrap(axis.minutes + steps, 60)
        case .latHundredths, .lonHundredths:
            axis.thousandths = replaceDigit(of: axis.thousandths, place: 100, by: steps)
        case .latTens, .lonTens:
            axis.thousandths = replaceDigit(of: axis.thousandths, place: 10, by: steps)
        case .latOnes, .lonOnes:
            axis.thousandths = replaceDigit(of: axis.thousandths, place: 1, by: steps)
        }
    }

    private static func replaceDigit(of value: Int, place: Int, by steps: Int) -> Int {
        let digit = value / place % 10
        return value + (wrap(digit + steps, 10) - digit) * place
    }

    private static func wrap(_ value: Int, _ count: Int) -> Int {
        (value % count + count) % count
    }
}
