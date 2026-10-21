// CoordinateEntryTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Testing
@testable import Peilung_Watch_App

struct CoordinateEntryTests {
    let houston = Coordinate(latitude: 29.75205, longitude: -95.3742667)

    @Test func startsFromCoordinateAndReturnsItsDDM() {
        let entry = CoordinateEntry(houston)
        #expect(entry.coordinate.latitudeText == "N 29° 45.123")
        #expect(entry.coordinate.longitudeText == "W 095° 22.456")
    }

    @Test func enteredFieldsParseToDecimal() {
        var entry = CoordinateEntry(houston)
        entry.adjust(.latOnes, by: 4)        // 45.127
        entry.adjust(.latHundredths, by: -1) // 45.027
        entry.adjust(.lonMinutes, by: 3)     // 25.456
        #expect(entry.coordinate.latitudeText == "N 29° 45.027")
        #expect(entry.coordinate.longitudeText == "W 095° 25.456")
        #expect(abs(entry.coordinate.latitude - (29 + 45.027 / 60)) < 1e-12)
        #expect(abs(entry.coordinate.longitude - -(95 + 25.456 / 60)) < 1e-12)
    }

    @Test func digitsWrapWithoutCarrying() {
        var entry = CoordinateEntry(houston)
        entry.adjust(.latOnes, by: 7)        // 3 + 7 = 10 → 0
        #expect(entry.text(.latOnes) == "0")
        #expect(entry.text(.latTens) == "2")
        entry.adjust(.latHundredths, by: -2) // 1 - 2 → 9
        #expect(entry.coordinate.latitudeText == "N 29° 45.920")
        entry.adjust(.latMinutes, by: 15)    // 45 + 15 → 0
        #expect(entry.text(.latMinutes) == "00")
        #expect(entry.text(.latDegrees) == "29")
    }

    @Test func degreesStayInRange() {
        var entry = CoordinateEntry(houston)
        entry.adjust(.latDegrees, by: 61)    // 29 + 61 = 90 → 0
        #expect(entry.text(.latDegrees) == "00")
        entry.adjust(.lonDegrees, by: 85)    // 95 + 85 = 180 → 0
        #expect(entry.text(.lonDegrees) == "000")
        entry.adjust(.lonDegrees, by: -1)
        #expect(entry.text(.lonDegrees) == "179")
    }

    @Test func hemisphereTogglesOnOddSteps() {
        var entry = CoordinateEntry(houston)
        entry.adjust(.latHemisphere, by: 1)
        #expect(entry.coordinate.latitude < 0)
        entry.adjust(.latHemisphere, by: 2)
        #expect(entry.coordinate.latitude < 0)
        entry.adjust(.lonHemisphere, by: -1)
        #expect(entry.coordinate.longitudeText == "E 095° 22.456")
    }

    @Test func polesAndAntimeridianClampIntoEditableRange() {
        let entry = CoordinateEntry(Coordinate(latitude: 90, longitude: -180))
        #expect(entry.text(.latDegrees) == "89")
        #expect(entry.text(.lonDegrees) == "179")
    }
}
