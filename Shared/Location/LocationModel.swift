// LocationModel.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import CoreLocation
import Observation

/// Position and heading from Core Location. GPS runs only while the screen is up;
/// the heading runs only while the Navigate page is showing.
@MainActor
@Observable
final class LocationModel: NSObject, CLLocationManagerDelegate {
    /// A fix older than this is shown as stale.
    static let freshness: TimeInterval = 5
    static let declinationKey = "declination"
    static let declinationLearnedKey = "declinationLearned"
    static let declinationOriginKey = "declinationOrigin"

    private(set) var location: CLLocation?
    /// Degrees clockwise from magnetic north, which the compass reads with or without a fix.
    private(set) var magneticHeading: Double?
    /// True minus magnetic north, learned once the compass has a fix and remembered,
    /// since it changes little over hundreds of kilometers.
    var declination: Double? {
        guard let learnedDeclination else { return nil }
        if let origin = declinationOrigin, let here = coordinate,
           here.distance(to: origin) > LearnedDeclination.range { return nil }
        return learnedDeclination
    }
    private var learnedDeclination: Double?
    private var declinationOrigin: Coordinate?
    /// The compass's own error estimate, in degrees.
    private(set) var headingAccuracy: Double?
    private(set) var status: CLAuthorizationStatus = .notDetermined
    private(set) var errorText: String?

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isSimulated = false
    @ObservationIgnored var onLearn: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        learnedDeclination = defaults.object(forKey: Self.declinationKey) as? Double
        declinationOrigin = Self.declinationOrigin(in: defaults)
        super.init()
        status = manager.authorizationStatus
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
    }

    var isDenied: Bool { status == .denied || status == .restricted }

    var headingAvailable: Bool { CLLocationManager.headingAvailable() }

    /// The current fix when it is fresh enough to act on.
    func freshLocation(at now: Date = .now) -> CLLocation? {
        guard let location, Self.isFresh(location.timestamp, at: now) else { return nil }
        return location
    }

    var coordinate: Coordinate? { location.map { Coordinate($0.coordinate) } }

    static func isFresh(_ timestamp: Date, at now: Date) -> Bool {
        now.timeIntervalSince(timestamp) <= freshness
    }

    /// How far apart two fixes must be to mean anything. The reported accuracy is a
    /// best guess that fixes often wander past, indoors most of all.
    static func margin(accuracy: Double) -> Double {
        max(2 * accuracy, 10)
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
        let learned = LearnedDeclination(degrees: Compass.signed(trueHeading - magnetic), date: .now, origin: coordinate)
        learnedDeclination = learned.degrees
        declinationOrigin = learned.origin
        if savedDeclination.map({ $0.isSuperseded(by: learned) }) ?? true {
            save(learned)
            onLearn?()
        }
    }

    var savedDeclination: LearnedDeclination? {
        guard let degrees = defaults.object(forKey: Self.declinationKey) as? Double,
              let date = defaults.object(forKey: Self.declinationLearnedKey) as? Date else { return nil }
        return LearnedDeclination(degrees: degrees, date: date, origin: Self.declinationOrigin(in: defaults))
    }

    func receive(_ received: LearnedDeclination) {
        guard received.date > savedDeclination?.date ?? .distantPast else { return }
        learnedDeclination = received.degrees
        declinationOrigin = received.origin
        save(received)
    }

    private func save(_ learned: LearnedDeclination) {
        defaults.set(learned.degrees, forKey: Self.declinationKey)
        defaults.set(learned.date, forKey: Self.declinationLearnedKey)
        defaults.set(learned.origin.flatMap { try? JSONEncoder().encode($0) }, forKey: Self.declinationOriginKey)
    }

    private static func declinationOrigin(in defaults: UserDefaults) -> Coordinate? {
        defaults.data(forKey: Self.declinationOriginKey).flatMap { try? JSONDecoder().decode(Coordinate.self, from: $0) }
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
        learnedDeclination = declination
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

struct LearnedDeclination: Codable, Equatable, Sendable {
    static let range = 100_000.0

    var degrees: Double
    var date: Date
    var origin: Coordinate?

    func isSuperseded(by learned: LearnedDeclination) -> Bool {
        guard abs(degrees - learned.degrees) < 0.1 else { return true }
        guard let learnedOrigin = learned.origin else { return false }
        guard let origin else { return true }
        return learnedOrigin.distance(to: origin) > Self.range / 10
    }
}
