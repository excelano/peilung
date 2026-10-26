// CoordinateEntry.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// The editable fields of a coordinate in the chosen format, one Digital Crown target
/// each. Every field wraps within its own range without carrying into its neighbour,
/// so turning one digit never disturbs the digits already set.
struct CoordinateEntry: Equatable {
    /// The hemisphere is field 0, the degrees field 1, then the format's places.
    struct Field: Hashable {
        let isLatitude: Bool
        let index: Int
    }

    var latitude: CoordinateAxis
    var longitude: CoordinateAxis

    init(_ coordinate: Coordinate, format: CoordinateFormat) {
        latitude = CoordinateAxis(coordinate.latitude, isLatitude: true, format: format)
        longitude = CoordinateAxis(coordinate.longitude, isLatitude: false, format: format)
        Self.clamp(&latitude, below: 90)
        Self.clamp(&longitude, below: 180)
    }

    /// A pole or the antimeridian becomes the nearest value the fields can hold.
    private static func clamp(_ axis: inout CoordinateAxis, below degrees: Int) {
        axis.steps = min(axis.steps, degrees * axis.format.perDegree - 1)
    }

    var format: CoordinateFormat { latitude.format }

    var coordinate: Coordinate {
        Coordinate(latitude: latitude.value, longitude: longitude.value)
    }

    func row(isLatitude: Bool) -> [Field] {
        (0...format.places.count + 1).map { Field(isLatitude: isLatitude, index: $0) }
    }

    var fields: [Field] { row(isLatitude: true) + row(isLatitude: false) }

    /// The first field after the degrees, where entry starts.
    static let firstField = Field(isLatitude: true, index: 2)

    /// "5.76 mi · 358° M" from where you are to the entered point; at it, no bearing.
    func offset(from here: Coordinate?, units: Units, north: North) -> String {
        guard let here else { return "No position yet" }
        let distance = here.distance(to: coordinate)
        guard distance >= 1 else { return "Where you are" }
        return units.format(meters: distance) + " · " + north.text(true: here.bearing(to: coordinate))
    }

    /// The text of one field as shown on screen.
    func text(_ field: Field) -> String {
        let axis = field.isLatitude ? latitude : longitude
        switch field.index {
        case 0: return axis.hemisphere
        case 1: return axis.degreeText
        default: return axis.text(format.places[field.index - 2])
        }
    }

    /// What follows the field on screen.
    func separator(_ field: Field) -> String {
        switch field.index {
        case 0: " "
        case 1: format.degreeSeparator
        default: format.places[field.index - 2].separator
        }
    }

    mutating func adjust(_ field: Field, by steps: Int) {
        if field.isLatitude {
            Self.step(&latitude, field.index, by: steps)
        } else {
            Self.step(&longitude, field.index, by: steps)
        }
    }

    private static func step(_ axis: inout CoordinateAxis, _ index: Int, by steps: Int) {
        switch index {
        case 0:
            if steps % 2 != 0 { axis.isNegative.toggle() }
        case 1:
            let perDegree = axis.format.perDegree
            let degrees = axis.steps / perDegree
            axis.steps += (wrap(degrees + steps, axis.isLatitude ? 90 : 180) - degrees) * perDegree
        default:
            let place = axis.format.places[index - 2]
            let current = axis.steps / place.size % place.count
            axis.steps += (wrap(current + steps, place.count) - current) * place.size
        }
    }

    private static func wrap(_ value: Int, _ count: Int) -> Int {
        (value % count + count) % count
    }
}
