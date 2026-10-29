// LocationTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import CoreLocation
import Foundation
import Testing
@testable import Peilung_Watch_App

@MainActor
struct LocationModelTests {
    let defaults = UserDefaults(suiteName: "LocationModelTests-\(UUID().uuidString)")!

    @Test func headingIsMagneticWithOrWithoutAFix() {
        let model = LocationModel(defaults: defaults)
        model.receiveHeading(magnetic: 69, true: -1, accuracy: 8)
        #expect(model.magneticHeading == 69)
        #expect(model.headingAccuracy == 8)
        #expect(model.declination == nil)
        model.receiveHeading(magnetic: 70, true: 72.5, accuracy: 8)
        #expect(model.magneticHeading == 70)
        #expect(model.declination == 2.5)
    }

    @Test func declinationWrapsAcrossNorth() {
        let model = LocationModel(defaults: defaults)
        model.receiveHeading(magnetic: 3, true: 351, accuracy: 5)
        #expect(model.declination == -12)
    }

    @Test func invalidReadingIsIgnored() {
        let model = LocationModel(defaults: defaults)
        model.receiveHeading(magnetic: 40, true: 42, accuracy: -1)
        #expect(model.magneticHeading == nil)
        #expect(model.declination == nil)
    }

    @Test func declinationIsRemembered() {
        LocationModel(defaults: defaults).receiveHeading(magnetic: 70, true: 72.5, accuracy: 8)
        let reopened = LocationModel(defaults: defaults)
        #expect(reopened.declination == 2.5)
        #expect(reopened.magneticHeading == nil)
    }

    @Test func learningADeclinationIsTimedAndAnnounced() {
        let model = LocationModel(defaults: defaults)
        var announced = 0
        model.onLearn = { announced += 1 }
        model.receiveHeading(magnetic: 70, true: 72.5, accuracy: 8)
        model.receiveHeading(magnetic: 71, true: 73.55, accuracy: 8)
        #expect(announced == 1)
        #expect(model.savedDeclination?.degrees == 2.5)
    }

    @Test func aDeclinationSavedWithoutADateIsSavedAgainWithOne() {
        defaults.set(2.5, forKey: LocationModel.declinationKey)
        let model = LocationModel(defaults: defaults)
        #expect(model.savedDeclination == nil)
        model.receiveHeading(magnetic: 70, true: 72.5, accuracy: 8)
        #expect(model.savedDeclination?.degrees == 2.5)
    }

    @Test func aNewerReceivedDeclinationWinsAndAnOlderOneIsIgnored() {
        let model = LocationModel(defaults: defaults)
        model.receive(LearnedDeclination(degrees: 2.5, date: .now - 60, origin: houston))
        #expect(model.declination == 2.5)
        model.receive(LearnedDeclination(degrees: 3, date: .now - 120, origin: nil))
        #expect(model.declination == 2.5)
        model.receive(LearnedDeclination(degrees: 3, date: .now, origin: nil))
        #expect(LocationModel(defaults: defaults).declination == 3)
    }

    @Test func aDeclinationLearnedFarAwayIsNotTrusted() {
        let model = LocationModel(defaults: defaults)
        fix(model, at: houston)
        model.receiveHeading(magnetic: 70, true: 72.5, accuracy: 8)
        fix(model, at: munich)
        #expect(model.declination == nil)
        model.receiveHeading(magnetic: 70, true: 74, accuracy: 8)
        #expect(model.declination == 4)
        #expect(model.savedDeclination?.origin == munich)
    }

    @Test func aRememberedDeclinationIsCheckedAgainstTheNextFix() {
        let model = LocationModel(defaults: defaults)
        fix(model, at: houston)
        model.receiveHeading(magnetic: 70, true: 72.5, accuracy: 8)
        let reopened = LocationModel(defaults: defaults)
        #expect(reopened.declination == 2.5)
        fix(reopened, at: Coordinate(latitude: 30.27, longitude: -97.74))
        #expect(reopened.declination == nil)
    }

    @Test func movingWithTheSameDeclinationRecordsWhereOnlyOnceFarEnough() {
        let model = LocationModel(defaults: defaults)
        var announced = 0
        model.onLearn = { announced += 1 }
        fix(model, at: houston)
        model.receiveHeading(magnetic: 70, true: 72.5, accuracy: 8)
        fix(model, at: Coordinate(latitude: 29.80, longitude: -95.37))
        model.receiveHeading(magnetic: 70, true: 72.5, accuracy: 8)
        #expect(announced == 1)
        let farther = Coordinate(latitude: 29.95, longitude: -95.37)
        fix(model, at: farther)
        model.receiveHeading(magnetic: 70, true: 72.5, accuracy: 8)
        #expect(announced == 2)
        #expect(model.savedDeclination?.origin == farther)
    }

    @Test func withoutAFixTheDeclinationIsSavedOnce() {
        let model = LocationModel(defaults: defaults)
        var announced = 0
        model.onLearn = { announced += 1 }
        for _ in 0..<5 { model.receiveHeading(magnetic: 70, true: 72.5, accuracy: 8) }
        #expect(announced == 1)
        #expect(model.declination == 2.5)
    }

    private let houston = Coordinate(latitude: 29.76, longitude: -95.37)
    private let munich = Coordinate(latitude: 48.14, longitude: 11.58)

    private func fix(_ model: LocationModel, at coordinate: Coordinate) {
        let location = CLLocation(coordinate: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude),
                                  altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5, timestamp: .now)
        model.locationManager(CLLocationManager(), didUpdateLocations: [location])
    }

    @Test func stoppingTheCompassKeepsTheDeclination() {
        let model = LocationModel(defaults: defaults)
        model.receiveHeading(magnetic: 70, true: 72.5, accuracy: 8)
        model.stopHeading()
        #expect(model.magneticHeading == nil)
        #expect(model.headingAccuracy == nil)
        #expect(model.declination == 2.5)
    }

    @Test func passingErrorsAreNotShown() {
        let model = LocationModel(defaults: defaults)
        model.receiveError(CLError(.locationUnknown))
        model.receiveError(CLError(.headingFailure))
        model.receiveError(CLError(.denied))
        #expect(model.errorText == nil)
        model.receiveError(CLError(.network))
        #expect(model.errorText == "Location is unavailable right now.")
    }

    @Test func freshLocationHonoursAge() {
        let model = LocationModel(defaults: defaults)
        #expect(model.freshLocation() == nil)
        #expect(model.coordinate == nil)
    }
}
