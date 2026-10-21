// BearingTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Testing
@testable import Peilung_Watch_App

struct NorthTests {
    @Test func magneticSubtractsEastDeclination() {
        let north = North(.magnetic, declination: 2.5)
        #expect(north.isMagnetic)
        #expect(north.shown(74) == 71.5)
        #expect(north.text(74) == "072° M")
        #expect(north.trueBearing(71.5) == 74)
    }

    @Test func westDeclinationWrapsPastNorth() {
        let north = North(.magnetic, declination: -12)
        #expect(north.text(355) == "007° M")
        #expect(north.trueBearing(5) == 353)
    }

    @Test func trueIgnoresDeclination() {
        let north = North(.true, declination: 9)
        #expect(!north.isMagnetic)
        #expect(north.text(74) == "074° T")
    }

    @Test func magneticFallsBackToTrueUntilDeclinationIsKnown() {
        let north = North(.magnetic, declination: nil)
        #expect(!north.isMagnetic)
        #expect(north.text(74) == "074° T")
    }

    @Test func degreesRoundToThreeDigits() {
        #expect(North.degrees(0) == "000°")
        #expect(North.degrees(7.4) == "007°")
        #expect(North.degrees(359.6) == "000°")
    }
}

struct AngleTests {
    @Test func signed() {
        #expect(Compass.signed(190) == -170)
        #expect(Compass.signed(-190) == 170)
        #expect(Compass.signed(45) == 45)
        #expect(Compass.signed(720 + 30) == 30)
    }

    @Test func normalized() {
        #expect(Compass.normalized(-10) == 350)
        #expect(Compass.normalized(370) == 10)
        #expect(Compass.normalized(360) == 0)
    }
}

struct BearingLineTests {
    let origin = Coordinate(latitude: 29.75, longitude: -95.37)

    /// A point `north` and `east` meters from the origin.
    func point(north: Double, east: Double) -> Coordinate {
        Coordinate(
            latitude: origin.latitude + north / 110_850,
            longitude: origin.longitude + east / (111_320 * cos(origin.latitude * .pi / 180))
        )
    }

    @Test func eastwardLine() throws {
        let line = BearingLine(bearing: 90, origin: origin)
        let ahead = try #require(line.offset(of: point(north: 0, east: 300)))
        #expect(abs(ahead.along - 300) < 3)
        #expect(abs(ahead.across) < 1)

        let left = try #require(line.offset(of: point(north: 20, east: 200)))
        #expect(abs(left.across - -20) < 1)
        #expect(abs(left.along - 200) < 3)

        let right = try #require(line.offset(of: point(north: -20, east: 200)))
        #expect(abs(right.across - 20) < 1)
    }

    @Test func pointBehindTheOrigin() throws {
        let line = BearingLine(bearing: 0, origin: origin)
        let behind = try #require(line.offset(of: point(north: -50, east: 0)))
        #expect(abs(behind.along - -50) < 1)
    }

    @Test func diagonalLine() throws {
        // 10 m right of a 045° line, 100 m along it.
        let line = BearingLine(bearing: 45, origin: origin)
        let s = sqrt(0.5)
        let offset = try #require(line.offset(of: point(north: 100 * s - 10 * s, east: 100 * s + 10 * s)))
        #expect(abs(offset.across - 10) < 1)
        #expect(abs(offset.along - 100) < 1.5)
    }

    @Test func noOriginNoOffset() {
        #expect(BearingLine(bearing: 90, origin: nil).offset(of: origin) == nil)
    }

    @Test func atTheOrigin() throws {
        let offset = try #require(BearingLine(bearing: 90, origin: origin).offset(of: origin))
        #expect(offset.across == 0 && offset.along == 0)
    }

    @Test func goalPersists() {
        let store = Store<Goal>(url: temporaryURL())
        let goal = Goal.bearing(BearingLine(bearing: 123.4, origin: origin))
        store.save(goal)
        #expect(store.load() == goal)
        let point = Goal.point(Target(name: "Car", coordinate: origin))
        store.save(point)
        #expect(store.load() == point)
    }
}

struct BearingHoldTests {
    @Test func comesOnWithinFiveDegrees() {
        var hold = BearingHold()
        #expect(hold.update(deviation: 30) == nil)
        #expect(hold.update(deviation: 6) == nil)
        #expect(hold.update(deviation: 5) == .onBearing)
        #expect(hold.isOn)
    }

    @Test func staysOnUntilBeyondTenDegrees() {
        var hold = BearingHold()
        _ = hold.update(deviation: 0)
        #expect(hold.update(deviation: 9) == nil)
        #expect(hold.update(deviation: -10) == nil)
        #expect(hold.isOn)
        #expect(hold.update(deviation: 11) == .turnRight)
        #expect(!hold.isOn)
    }

    @Test func cuesTheTurnBackToTheBearing() {
        var hold = BearingHold()
        _ = hold.update(deviation: 0)
        // The bearing now lies 15° anticlockwise of where the watch points.
        #expect(hold.update(deviation: -15) == .turnLeft)
    }

    @Test func wrapsAcrossNorth() {
        var hold = BearingHold()
        #expect(hold.update(deviation: 358) == .onBearing)
        #expect(hold.update(deviation: 345) == .turnLeft)
    }
}
