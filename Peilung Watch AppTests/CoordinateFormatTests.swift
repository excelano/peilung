// CoordinateFormatTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Testing
@testable import Peilung_Watch_App

struct CoordinateFormatTests {
    private func text(_ value: Double, isLatitude: Bool, _ format: CoordinateFormat = .degreesMinutes) -> String {
        CoordinateAxis(value, isLatitude: isLatitude, format: format).text
    }

    @Test func formatsNorthAndWest() {
        #expect(text(29.75205, isLatitude: true) == "N 29° 45.123")
        #expect(text(-95.3742667, isLatitude: false) == "W 095° 22.456")
    }

    @Test func formatsSouthAndEast() {
        #expect(text(-33.8568, isLatitude: true) == "S 33° 51.408")
        #expect(text(151.2153, isLatitude: false) == "E 151° 12.918")
    }

    @Test func roundingCarriesIntoDegreesNotSixtyMinutes() {
        #expect(text(29.9999999, isLatitude: true) == "N 30° 00.000")
        #expect(text(-95.999999, isLatitude: false) == "W 096° 00.000")
        // Minutes rounding up to 60.000 carry into the degrees.
        #expect(text(10 + 59.9996 / 60, isLatitude: true) == "N 11° 00.000")
        #expect(text(10 + 59.9994 / 60, isLatitude: true) == "N 10° 59.999")
    }

    @Test func zeroIsNorthAndEast() {
        #expect(text(0, isLatitude: true) == "N 00° 00.000")
        #expect(text(0, isLatitude: false) == "E 000° 00.000")
        #expect(text(-0.0000001, isLatitude: true) == "N 00° 00.000")
        #expect(text(-0.0000001, isLatitude: false) == "E 000° 00.000")
    }

    @Test func formatsAntimeridian() {
        #expect(text(180, isLatitude: false) == "E 180° 00.000")
        #expect(text(-180, isLatitude: false) == "W 180° 00.000")
        #expect(text(-90, isLatitude: true) == "S 90° 00.000")
    }

    @Test func formatsSeconds() {
        #expect(text(29.75205, isLatitude: true, .degreesMinutesSeconds) == "N 29° 45′ 07.4″")
        #expect(text(-95.3742667, isLatitude: false, .degreesMinutesSeconds) == "W 095° 22′ 27.4″")
        #expect(text(29.9999999, isLatitude: true, .degreesMinutesSeconds) == "N 30° 00′ 00.0″")
    }

    @Test func formatsDecimalDegrees() {
        #expect(text(29.75205, isLatitude: true, .decimalDegrees) == "N 29.75205°")
        #expect(text(-95.3742667, isLatitude: false, .decimalDegrees) == "W 095.37427°")
        #expect(text(-0.000001, isLatitude: true, .decimalDegrees) == "N 00.00000°")
    }

    @Test func valueIsExactFromSteps() {
        var axis = CoordinateAxis(0, isLatitude: true, format: .degreesMinutes)
        axis.isNegative = true
        axis.steps = 29 * 60_000 + 45_123
        #expect(abs(axis.value - -(29 + 45.123 / 60)) < 1e-12)
    }

    @Test(arguments: [
        (29.75205, -95.3742667), (-33.8568, 151.2153), (0.0005, -0.0005),
        (51.477928, -0.001545), (64.1466, -21.9426), (-54.8019, -68.303),
    ])
    func decimalToFormatAndBackRoundTrips(latitude: Double, longitude: Double) {
        for format in CoordinateFormat.allCases {
            let first = CoordinateAxis(latitude, isLatitude: true, format: format)
            #expect(CoordinateAxis(first.value, isLatitude: true, format: format) == first)
            #expect(abs(first.value - latitude) <= 0.5 / Double(format.perDegree) + 1e-12)
            let lon = CoordinateAxis(longitude, isLatitude: false, format: format)
            #expect(CoordinateAxis(lon.value, isLatitude: false, format: format) == lon)
        }
    }
}
