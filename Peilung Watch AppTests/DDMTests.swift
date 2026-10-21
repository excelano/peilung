// DDMTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Testing
@testable import Peilung_Watch_App

struct DDMTests {
    @Test func formatsNorthAndWest() {
        #expect(Geocache.format(29.75205, isLatitude: true) == "N 29° 45.123")
        #expect(Geocache.format(-95.3742667, isLatitude: false) == "W 095° 22.456")
    }

    @Test func formatsSouthAndEast() {
        #expect(Geocache.format(-33.8568, isLatitude: true) == "S 33° 51.408")
        #expect(Geocache.format(151.2153, isLatitude: false) == "E 151° 12.918")
    }

    @Test func roundingCarriesIntoDegreesNotSixtyMinutes() {
        #expect(Geocache.format(29.9999999, isLatitude: true) == "N 30° 00.000")
        #expect(Geocache.format(-95.999999, isLatitude: false) == "W 096° 00.000")
        // Minutes rounding up to 60.000 carry into the degrees.
        #expect(Geocache.format(10 + 59.9996 / 60, isLatitude: true) == "N 11° 00.000")
        #expect(Geocache.format(10 + 59.9994 / 60, isLatitude: true) == "N 10° 59.999")
    }

    @Test func zeroIsNorthAndEast() {
        #expect(Geocache.format(0, isLatitude: true) == "N 00° 00.000")
        #expect(Geocache.format(0, isLatitude: false) == "E 000° 00.000")
        #expect(Geocache.format(-0.0000001, isLatitude: true) == "N 00° 00.000")
        #expect(Geocache.format(-0.0000001, isLatitude: false) == "E 000° 00.000")
    }

    @Test func formatsAntimeridian() {
        #expect(Geocache.format(180, isLatitude: false) == "E 180° 00.000")
        #expect(Geocache.format(-180, isLatitude: false) == "W 180° 00.000")
        #expect(Geocache.format(-90, isLatitude: true) == "S 90° 00.000")
    }

    @Test func valueIsExactFromFields() {
        let ddm = DDM(isLatitude: true, isNegative: true, degrees: 29, minutes: 45, thousandths: 123)
        #expect(abs(ddm.value - -(29 + 45.123 / 60)) < 1e-12)
    }

    @Test(arguments: [
        (29.75205, -95.3742667), (-33.8568, 151.2153), (0.0005, -0.0005),
        (51.477928, -0.001545), (64.1466, -21.9426), (-54.8019, -68.303),
    ])
    func decimalToDDMAndBackRoundTrips(latitude: Double, longitude: Double) {
        let first = DDM(latitude, isLatitude: true)
        let back = DDM(first.value, isLatitude: true)
        #expect(back == first)
        #expect(abs(first.value - latitude) <= 0.0005 / 60 + 1e-12)
        let lon = DDM(longitude, isLatitude: false)
        #expect(DDM(lon.value, isLatitude: false) == lon)
    }
}
