// GeoTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Testing
@testable import Peilung_Watch_App

struct BearingTests {
    let origin = Coordinate(latitude: 0, longitude: 0)

    @Test func cardinalBearings() {
        #expect(abs(origin.bearing(to: Coordinate(latitude: 1, longitude: 0)) - 0) < 1e-9)
        #expect(abs(origin.bearing(to: Coordinate(latitude: 0, longitude: 1)) - 90) < 1e-9)
        #expect(abs(origin.bearing(to: Coordinate(latitude: -1, longitude: 0)) - 180) < 1e-9)
        #expect(abs(origin.bearing(to: Coordinate(latitude: 0, longitude: -1)) - 270) < 1e-9)
    }

    /// LAX to JFK, from Ed Williams' Aviation Formulary: initial course 066° (65.9°).
    @Test func laxToJFK() {
        let lax = Coordinate(latitude: 33 + 57.0 / 60, longitude: -(118 + 24.0 / 60))
        let jfk = Coordinate(latitude: 40 + 38.0 / 60, longitude: -(73 + 47.0 / 60))
        #expect(abs(lax.bearing(to: jfk) - 65.89) < 0.05)
    }

    @Test func greatCircleBearingDiffersFromRhumbLine() {
        // Due east along 60°N starts out north of east on a great circle.
        let bearing = Coordinate(latitude: 60, longitude: 0).bearing(to: Coordinate(latitude: 60, longitude: 10))
        #expect(bearing > 80 && bearing < 90)
    }
}

struct DistanceTests {
    /// LAX to JFK: 2144 nm (3970 km) on the sphere, about 3983 km on the WGS84 ellipsoid.
    @Test func laxToJFK() {
        let lax = Coordinate(latitude: 33 + 57.0 / 60, longitude: -(118 + 24.0 / 60))
        let jfk = Coordinate(latitude: 40 + 38.0 / 60, longitude: -(73 + 47.0 / 60))
        let km = lax.distance(to: jfk) / 1000
        #expect(km > 3960 && km < 3995)
    }

    @Test func oneThousandthOfAMinuteOfLatitude() {
        // 0.001' of latitude is about 1.85 m: the resolution of a DDM coordinate.
        let a = Coordinate(latitude: 29.75, longitude: -95.37)
        let b = Coordinate(latitude: 29.75 + 0.001 / 60, longitude: -95.37)
        #expect(abs(a.distance(to: b) - 1.85) < 0.02)
    }
}

struct CompassTests {
    @Test func unwrappedTakesTheShortWayRound() {
        #expect(Compass.unwrapped(10, from: 350) == 370)
        #expect(Compass.unwrapped(350, from: 10) == -10)
        #expect(Compass.unwrapped(90, from: 720) == 810)
        #expect(Compass.unwrapped(-90, from: 0) == -90)
    }

    @Test func compassPoints() {
        #expect(Compass.point(0) == "N")
        #expect(Compass.point(22.4) == "N")
        #expect(Compass.point(22.5) == "NE")
        #expect(Compass.point(180) == "S")
        #expect(Compass.point(337.6) == "N")
        #expect(Compass.point(-45) == "NW")
    }
}

struct UnitsTests {
    @Test func metric() {
        #expect(Units.metric.format(meters: 0) == "0 m")
        #expect(Units.metric.format(meters: 999.4) == "999 m")
        #expect(Units.metric.format(meters: 999.6) == "1.00 km")
        #expect(Units.metric.format(meters: 2_346) == "2.35 km")
        #expect(Units.metric.format(meters: 12_345) == "12.3 km")
        #expect(Units.metric.format(meters: 123_456) == "123 km")
    }

    @Test func imperial() {
        #expect(Units.imperial.format(meters: 100) == "328 ft")
        #expect(Units.imperial.format(meters: 160) == "525 ft")
        #expect(Units.imperial.format(meters: 1609.344) == "1.00 mi")
        #expect(Units.imperial.format(meters: 20_000) == "12.4 mi")
    }

    @Test func elapsed() {
        #expect(Elapsed.format(0) == "0:00")
        #expect(Elapsed.format(247) == "4:07")
        #expect(Elapsed.format(5025) == "1:23:45")
        #expect(Elapsed.format(-3) == "0:00")
    }
}

struct FreshnessTests {
    @MainActor @Test func fixIsStaleAfterFiveSeconds() {
        let now = Date.now
        #expect(LocationModel.isFresh(now.addingTimeInterval(-5), at: now))
        #expect(!LocationModel.isFresh(now.addingTimeInterval(-5.1), at: now))
    }
}
