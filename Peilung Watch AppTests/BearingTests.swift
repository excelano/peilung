// BearingTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Testing
@testable import Peilung_Watch_App

struct NorthTests {
    @Test func magneticShowsReadingsAsTheyAre() {
        let north = North(.magnetic, declination: 2.5)
        #expect(north.magneticSuffix == "M")
        #expect(north.text(magnetic: 71.5) == "072° M")
        #expect(north.magnetic(shown: 72) == 72)
    }

    @Test func magneticNeedsNoDeclinationForCompassReadings() {
        let north = North(.magnetic, declination: nil)
        #expect(north.text(magnetic: 71.5) == "072° M")
        #expect(north.trueBearing(magnetic: 71.5) == nil)
    }

    @Test func gpsBearingsShowMagneticOnceDeclinationIsKnown() {
        #expect(North(.magnetic, declination: 2.5).text(true: 74) == "072° M")
        #expect(North(.magnetic, declination: -12).text(true: 5) == "017° M")
        #expect(North(.magnetic, declination: nil).text(true: 74) == "074° T")
    }

    @Test func trueConvertsReadingsOnceDeclinationIsKnown() {
        let north = North(.true, declination: -12)
        #expect(north.magneticSuffix == "T")
        #expect(north.text(magnetic: 7) == "355° T")
        #expect(north.magnetic(shown: 355) == 7)
        #expect(north.trueBearing(magnetic: 7) == 355)
        #expect(north.text(true: 74) == "074° T")
    }

    @Test func trueFallsBackToMagneticUntilDeclinationIsKnown() {
        let north = North(.true, declination: nil)
        #expect(north.magneticSuffix == "M")
        #expect(north.text(magnetic: 74) == "074° M")
        #expect(north.magnetic(shown: 74) == 74)
    }

    @Test func shownAndEnteredRoundTrip() {
        for reference in NorthReference.allCases {
            let north = North(reference, declination: 9.3)
            for magnetic in stride(from: 0.0, to: 360, by: 17.5) {
                #expect(abs(north.magnetic(shown: north.shown(magnetic: magnetic)) - magnetic) < 1e-9)
            }
        }
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
        let line = BearingLine(magnetic: 90, origin: origin)
        let ahead = try #require(line.offset(of: point(north: 0, east: 300), declination: 0))
        #expect(abs(ahead.along - 300) < 3)
        #expect(abs(ahead.across) < 1)

        let left = try #require(line.offset(of: point(north: 20, east: 200), declination: 0))
        #expect(abs(left.across - -20) < 1)
        #expect(abs(left.along - 200) < 3)

        let right = try #require(line.offset(of: point(north: -20, east: 200), declination: 0))
        #expect(abs(right.across - 20) < 1)
    }

    @Test func pointBehindTheOrigin() throws {
        let line = BearingLine(magnetic: 0, origin: origin)
        let behind = try #require(line.offset(of: point(north: -50, east: 0), declination: 0))
        #expect(abs(behind.along - -50) < 1)
    }

    @Test func diagonalLine() throws {
        // 10 m right of a 045° line, 100 m along it.
        let line = BearingLine(magnetic: 45, origin: origin)
        let s = sqrt(0.5)
        let offset = try #require(line.offset(of: point(north: 100 * s - 10 * s, east: 100 * s + 10 * s), declination: 0))
        #expect(abs(offset.across - 10) < 1)
        #expect(abs(offset.along - 100) < 1.5)
    }

    @Test func noOriginNoOffset() {
        #expect(BearingLine(magnetic: 90, origin: nil).offset(of: origin, declination: 0) == nil)
    }

    @Test func noDeclinationNoOffset() {
        #expect(BearingLine(magnetic: 90, origin: origin).offset(of: point(north: 0, east: 100), declination: nil) == nil)
    }

    @Test func declinationTurnsTheLineTrue() throws {
        // 080° magnetic with 10° east declination runs due east.
        let line = BearingLine(magnetic: 80, origin: origin)
        let offset = try #require(line.offset(of: point(north: 0, east: 300), declination: 10))
        #expect(abs(offset.across) < 1)
        #expect(abs(offset.along - 300) < 3)
        let uncorrected = try #require(line.offset(of: point(north: 0, east: 300), declination: 0))
        #expect(uncorrected.across > 50)
    }

    @Test func atTheOrigin() throws {
        let offset = try #require(BearingLine(magnetic: 90, origin: origin).offset(of: origin, declination: 0))
        #expect(offset.across == 0 && offset.along == 0)
    }

    @Test func goalPersists() {
        let store = Store<Goal>(url: temporaryURL())
        let goal = Goal.bearing(BearingLine(magnetic: 123.4, origin: origin))
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

@MainActor
struct NavigatorTests {
    let defaults = UserDefaults(suiteName: "NavigatorTests-\(UUID().uuidString)")!

    @Test func opensOnNavigateFirstTime() {
        #expect(Navigator(store: Store(url: temporaryURL()), defaults: defaults).page == .navigate)
    }

    @Test func reopensOnTheLastPage() {
        let navigator = Navigator(store: Store(url: temporaryURL()), defaults: defaults)
        navigator.page = .odometer
        #expect(Navigator(store: Store(url: temporaryURL()), defaults: defaults).page == .odometer)
    }

    @Test func clearForgetsTheGoal() {
        let url = temporaryURL()
        let navigator = Navigator(store: Store(url: url), defaults: defaults)
        navigator.follow(BearingLine(magnetic: 90, origin: nil))
        #expect(navigator.page == .navigate)
        navigator.clear()
        #expect(navigator.goal == nil)
        #expect(Navigator(store: Store(url: url), defaults: defaults).goal == nil)
    }

    @Test func localChangesAreTimedAndAnnounced() {
        let url = temporaryURL()
        let navigator = Navigator(store: Store(url: url), defaults: defaults)
        var announced = 0
        navigator.onChange = { announced += 1 }
        navigator.follow(BearingLine(magnetic: 90, origin: nil))
        let followed = navigator.goalChanged
        navigator.clear()
        #expect(announced == 2)
        #expect(followed != nil)
        #expect(navigator.goalChanged ?? .distantPast >= followed ?? .distantFuture)
        #expect(Navigator(store: Store(url: url), defaults: defaults).goalChanged == navigator.goalChanged)
    }

    @Test func aNewerReceivedGoalWinsAndOpensNavigate() {
        let url = temporaryURL()
        let navigator = Navigator(store: Store(url: url), defaults: defaults)
        navigator.follow(BearingLine(magnetic: 90, origin: nil))
        navigator.page = .marks
        var announced = false
        navigator.onChange = { announced = true }
        let car = Goal.point(Target(name: "Car", coordinate: Coordinate(latitude: 29.75, longitude: -95.37)))
        navigator.receive(car, changed: .now + 1)
        #expect(navigator.goal == car)
        #expect(navigator.page == .navigate)
        #expect(!announced)
        #expect(Navigator(store: Store(url: url), defaults: defaults).goal == car)
    }

    @Test func anOlderReceivedGoalIsIgnored() {
        let navigator = Navigator(store: Store(url: temporaryURL()), defaults: defaults)
        let line = Goal.bearing(BearingLine(magnetic: 90, origin: nil))
        navigator.follow(BearingLine(magnetic: 90, origin: nil))
        navigator.receive(nil, changed: .now - 60)
        #expect(navigator.goal == line)
    }

    @Test func aReceivedStopKeepsThePage() {
        let navigator = Navigator(store: Store(url: temporaryURL()), defaults: defaults)
        navigator.follow(BearingLine(magnetic: 90, origin: nil))
        navigator.page = .odometer
        navigator.receive(nil, changed: .now + 1)
        #expect(navigator.goal == nil)
        #expect(navigator.page == .odometer)
    }
}

struct ArrivalTests {
    @Test func announcesOnceOnArriving() {
        var arrival = Arrival()
        #expect(arrival.update(distance: 150) == false)
        #expect(arrival.update(distance: 10) == false)
        #expect(arrival.update(distance: 9.9) == true)
        #expect(arrival.isNear)
        #expect(arrival.update(distance: 4) == false)
        #expect(arrival.update(distance: 9) == false)
    }

    @Test func gpsWobbleAtTheTargetStaysQuiet() {
        var arrival = Arrival()
        _ = arrival.update(distance: 5)
        for distance in [12.0, 8, 18, 6, 20] {
            #expect(arrival.update(distance: distance) == false)
        }
        #expect(arrival.isNear)
    }

    @Test func leavingRearmsIt() {
        var arrival = Arrival()
        _ = arrival.update(distance: 5)
        #expect(arrival.update(distance: 20.1) == false)
        #expect(!arrival.isNear)
        #expect(arrival.update(distance: 7) == true)
    }
}
