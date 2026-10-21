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
