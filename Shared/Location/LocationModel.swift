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
    /// The same for the dimmed always-on display, which redraws about once a minute.
    static let dimmedFreshness: TimeInterval = 90
    static let declinationKey = "declination"

    private(set) var location: CLLocation?
    /// Degrees clockwise from magnetic north, which the compass reads with or without a fix.
    private(set) var magneticHeading: Double?
    /// True minus magnetic north, learned once the compass has a fix and remembered,
    /// since it changes little over hundreds of kilometers.
    private(set) var declination: Double?
    /// The compass's own error estimate, in degrees.
    private(set) var headingAccuracy: Double?
    private(set) var status: CLAuthorizationStatus = .notDetermined
    private(set) var errorText: String?

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isSimulated = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        declination = defaults.object(forKey: Self.declinationKey) as? Double
        super.init()
        status = manager.authorizationStatus
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
    }

    var isDenied: Bool { status == .denied || status == .restricted }

    var headingAvailable: Bool { CLLocationManager.headingAvailable() }

    /// The current fix when it is fresh enough to act on.
    func freshLocation(at now: Date = .now, dimmed: Bool = false) -> CLLocation? {
        guard let location, Self.isFresh(location.timestamp, at: now, dimmed: dimmed) else { return nil }
        return location
    }

    var coordinate: Coordinate? { location.map { Coordinate($0.coordinate) } }

    static func isFresh(_ timestamp: Date, at now: Date, dimmed: Bool = false) -> Bool {
        now.timeIntervalSince(timestamp) <= (dimmed ? dimmedFreshness : freshness)
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
        magneticHeading = nil
        headingAccuracy = nil
    }

    /// A compass reading. A true heading below zero means the compass has no fix yet.
    func receiveHeading(magnetic: Double, true trueHeading: Double, accuracy: Double) {
        guard accuracy >= 0 else { return }
        magneticHeading = magnetic
        headingAccuracy = accuracy
        guard trueHeading >= 0 else { return }
        let learned = Compass.signed(trueHeading - magnetic)
        declination = learned
        let saved = defaults.object(forKey: Self.declinationKey) as? Double
        if saved.map({ abs($0 - learned) >= 0.1 }) ?? true {
            defaults.set(learned, forKey: Self.declinationKey)
        }
    }

    /// Core Location keeps trying after a passing failure, and a refusal shows through
    /// `status`, so only lasting failures are shown.
    func receiveError(_ error: Error) {
        switch (error as? CLError)?.code {
        case .locationUnknown, .headingFailure, .denied:
            return
        default:
            errorText = "Location is unavailable right now."
        }
    }

    #if DEBUG
    /// Replaces Core Location with a fixed fix and compass, for screenshots.
    func simulate(_ location: CLLocation, magneticHeading: Double, declination: Double, accuracy: Double) {
        isSimulated = true
        status = .authorizedWhenInUse
        self.location = location
        self.magneticHeading = magneticHeading
        self.declination = declination
        headingAccuracy = accuracy
    }
    #endif

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            guard !isSimulated else { return }
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
        let magnetic = newHeading.magneticHeading
        let trueHeading = newHeading.trueHeading
        let accuracy = newHeading.headingAccuracy
        MainActor.assumeIsolated {
            receiveHeading(magnetic: magnetic, true: trueHeading, accuracy: accuracy)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            receiveError(error)
        }
    }
}
