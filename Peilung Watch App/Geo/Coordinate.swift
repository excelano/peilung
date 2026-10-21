// Coordinate.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import CoreLocation

struct Coordinate: Codable, Equatable, Sendable {
    var latitude: Double
    var longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    var latitudeText: String { Geocache.format(latitude, isLatitude: true) }
    var longitudeText: String { Geocache.format(longitude, isLatitude: false) }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    /// Meters, from Core Location's ellipsoidal distance.
    func distance(to other: Coordinate) -> Double {
        location.distance(from: other.location)
    }

    /// Initial great-circle bearing in degrees, 0 ..< 360, clockwise from true north.
    func bearing(to other: Coordinate) -> Double {
        let φ1 = latitude * .pi / 180
        let φ2 = other.latitude * .pi / 180
        let Δλ = (other.longitude - longitude) * .pi / 180
        let y = sin(Δλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
        let degrees = atan2(y, x) * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }
}

/// A named point to navigate to.
struct Target: Codable, Equatable, Sendable {
    var name: String
    var coordinate: Coordinate
}
