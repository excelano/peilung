// CoordinateEntryTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Testing
@testable import Peilung_Watch_App

struct CoordinateEntryTests {
    let houston = Coordinate(latitude: 29.75205, longitude: -95.3742667)

    private func lat(_ index: Int) -> CoordinateEntry.Field { .init(isLatitude: true, index: index) }
    private func lon(_ index: Int) -> CoordinateEntry.Field { .init(isLatitude: false, index: index) }

    @Test func startsFromCoordinateAndReturnsItsDDM() {
        let entry = CoordinateEntry(houston, format: .degreesMinutes)
        #expect(entry.coordinate.latitudeText(.degreesMinutes) == "N 29° 45.123")
        #expect(entry.coordinate.longitudeText(.degreesMinutes) == "W 095° 22.456")
    }

    @Test func enteredFieldsParseToDecimal() {
        var entry = CoordinateEntry(houston, format: .degreesMinutes)
        entry.adjust(lat(5), by: 4)  // 45.127
        entry.adjust(lat(3), by: -1) // 45.027
        entry.adjust(lon(2), by: 3)  // 25.456
        #expect(entry.coordinate.latitudeText(.degreesMinutes) == "N 29° 45.027")
        #expect(entry.coordinate.longitudeText(.degreesMinutes) == "W 095° 25.456")
        #expect(abs(entry.coordinate.latitude - (29 + 45.027 / 60)) < 1e-12)
        #expect(abs(entry.coordinate.longitude - -(95 + 25.456 / 60)) < 1e-12)
    }

    @Test func digitsWrapWithoutCarrying() {
        var entry = CoordinateEntry(houston, format: .degreesMinutes)
        entry.adjust(lat(5), by: 7)  // 3 + 7 = 10 → 0
        #expect(entry.text(lat(5)) == "0")
        #expect(entry.text(lat(4)) == "2")
        entry.adjust(lat(3), by: -2) // 1 - 2 → 9
        #expect(entry.coordinate.latitudeText(.degreesMinutes) == "N 29° 45.920")
        entry.adjust(lat(2), by: 15) // 45 + 15 → 0
        #expect(entry.text(lat(2)) == "00")
        #expect(entry.text(lat(1)) == "29")
    }

    @Test func degreesStayInRange() {
        var entry = CoordinateEntry(houston, format: .degreesMinutes)
        entry.adjust(lat(1), by: 61) // 29 + 61 = 90 → 0
        #expect(entry.text(lat(1)) == "00")
        entry.adjust(lon(1), by: 85) // 95 + 85 = 180 → 0
        #expect(entry.text(lon(1)) == "000")
        entry.adjust(lon(1), by: -1)
        #expect(entry.text(lon(1)) == "179")
    }

    @Test func hemisphereTogglesOnOddSteps() {
        var entry = CoordinateEntry(houston, format: .degreesMinutes)
        entry.adjust(lat(0), by: 1)
        #expect(entry.coordinate.latitude < 0)
        entry.adjust(lat(0), by: 2)
        #expect(entry.coordinate.latitude < 0)
        entry.adjust(lon(0), by: -1)
        #expect(entry.coordinate.longitudeText(.degreesMinutes) == "E 095° 22.456")
    }

    @Test func secondsFieldsWrapWithinTheirRange() {
        var entry = CoordinateEntry(houston, format: .degreesMinutesSeconds)
        #expect(entry.row(isLatitude: true).map(entry.text) == ["N", "29", "45", "07", "4"])
        #expect(entry.row(isLatitude: true).map(entry.separator) == [" ", "° ", "′ ", ".", "″"])
        entry.adjust(lat(3), by: 55) // 7 + 55 = 62 → 2
        entry.adjust(lat(4), by: -5) // 4 - 5 → 9
        #expect(entry.coordinate.latitudeText(.degreesMinutesSeconds) == "N 29° 45′ 02.9″")
        #expect(abs(entry.coordinate.latitude - (29 + 45.0 / 60 + 2.9 / 3600)) < 1e-12)
    }

    @Test func decimalDigitsWrapWithoutCarrying() {
        var entry = CoordinateEntry(houston, format: .decimalDegrees)
        #expect(entry.row(isLatitude: false).map(entry.text) == ["W", "095", "3", "7", "4", "2", "7"])
        entry.adjust(lon(2), by: 7)  // 3 + 7 → 0
        entry.adjust(lon(1), by: 86) // 95 + 86 = 181 → 1
        #expect(entry.coordinate.longitudeText(.decimalDegrees) == "W 001.07427°")
        #expect(entry.fields.count == 14)
    }

    @Test func polesAndAntimeridianClampIntoEditableRange() {
        let entry = CoordinateEntry(Coordinate(latitude: 90, longitude: -180), format: .degreesMinutes)
        #expect(entry.coordinate.latitudeText(.degreesMinutes) == "N 89° 59.999")
        #expect(entry.coordinate.longitudeText(.degreesMinutes) == "W 179° 59.999")
        let near = CoordinateEntry(Coordinate(latitude: -89.9999999, longitude: 179.99999999), format: .degreesMinutes)
        #expect(near.coordinate.latitudeText(.degreesMinutes) == "S 89° 59.999")
        #expect(near.coordinate.longitudeText(.degreesMinutes) == "E 179° 59.999")
        let decimal = CoordinateEntry(Coordinate(latitude: 90, longitude: -180), format: .decimalDegrees)
        #expect(decimal.coordinate.latitudeText(.decimalDegrees) == "N 89.99999°")
    }
}

struct CrownTests {
    @Test func countsDetentsTurned() {
        #expect(Crown.steps(from: 10, to: 13) == 3)
        #expect(Crown.steps(from: 13, to: 10) == -3)
        #expect(Crown.steps(from: 10.4, to: 10.6) == 1)
        #expect(Crown.steps(from: 10, to: 10.3) == 0)
    }

    @Test func wrapsTheShortWayRound() {
        #expect(Crown.steps(from: 99, to: 0) == 1)
        #expect(Crown.steps(from: 0, to: 99) == -1)
        #expect(Crown.steps(from: 97, to: 2) == 5)
        #expect(Crown.steps(from: 98.6, to: 0.2) == 1)
    }
}
