// LocationModel.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import CoreLocation
import Observation

/// Position and heading from Core Location. GPS runs only while the app is on screen;
/// the heading runs only while the Navigate page is showing.
@MainActor
@Observable
final class LocationModel: NSObject, CLLocationManagerDelegate {
    /// A fix older than this is shown as stale.
    static let freshness: TimeInterval = 5

    private(set) var location: CLLocation?
    /// Degrees clockwise from true north, or from magnetic north when the true heading is unknown.
    private(set) var heading: Double?
    /// True minus magnetic north, known once the compass and a fix agree.
    private(set) var declination: Double?
    /// The compass's own error estimate, in degrees.
    private(set) var headingAccuracy: Double?
    private(set) var status: CLAuthorizationStatus = .notDetermined
    private(set) var errorText: String?

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var isSimulated = false

    override init() {
        super.init()
        status = manager.authorizationStatus
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
    }

    var isDenied: Bool { status == .denied || status == .restricted }

    var headingAvailable: Bool { CLLocationManager.headingAvailable() }

    /// The current fix when it is no older than `freshness`.
    func freshLocation(at now: Date = .now) -> CLLocation? {
        guard let location, Self.isFresh(location.timestamp, at: now) else { return nil }
        return location
    }

    var coordinate: Coordinate? { location.map { Coordinate($0.coordinate) } }

    static func isFresh(_ timestamp: Date, at now: Date) -> Bool {
        now.timeIntervalSince(timestamp) <= freshness
    }

    func start() {
        guard !isSimulated else { return }
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
    }

    func stop() {
        guard !isSimulated else { return }
        manager.stopUpdatingLocation()
        stopHeading()
    }

    func startHeading() {
        guard !isSimulated, headingAvailable else { return }
        manager.startUpdatingHeading()
    }

    func stopHeading() {
        guard !isSimulated else { return }
        manager.stopUpdatingHeading()
        heading = nil
        headingAccuracy = nil
    }

    #if DEBUG
    /// Replaces Core Location with a fixed fix and compass, for screenshots.
    func simulate(_ location: CLLocation, heading: Double, declination: Double, accuracy: Double) {
        isSimulated = true
        status = .authorizedWhenInUse
        self.location = location
        self.heading = heading
        self.declination = declination
        headingAccuracy = accuracy
    }
    #endif

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            self.status = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last, latest.horizontalAccuracy >= 0 else { return }
        MainActor.assumeIsolated {
            location = latest
            errorText = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let accuracy = newHeading.headingAccuracy
        guard accuracy >= 0 else { return }
        let hasTrue = newHeading.trueHeading >= 0
        let degrees = hasTrue ? newHeading.trueHeading : newHeading.magneticHeading
        let offset = Compass.signed(newHeading.trueHeading - newHeading.magneticHeading)
        MainActor.assumeIsolated {
            heading = degrees
            headingAccuracy = accuracy
            if hasTrue { declination = offset }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let text = error.localizedDescription
        MainActor.assumeIsolated {
            errorText = text
        }
    }
}
