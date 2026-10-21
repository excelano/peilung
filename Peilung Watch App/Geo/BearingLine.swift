// BearingLine.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// A bearing to follow, and where it was taken when a fix was available.
struct BearingLine: Codable, Equatable, Sendable {
    /// Degrees clockwise from true north.
    var bearing: Double
    var origin: Coordinate?

    /// Meters to the right of the line (negative: left) and along it from the origin
    /// (negative: behind it). Flat-earth geometry, which is exact enough over the few
    /// kilometers a bearing is walked.
    func offset(of point: Coordinate) -> (across: Double, along: Double)? {
        guard let origin else { return nil }
        let distance = origin.distance(to: point)
        guard distance > 0 else { return (0, 0) }
        let angle = (origin.bearing(to: point) - bearing) * .pi / 180
        return (distance * sin(angle), distance * cos(angle))
    }
}

/// Where Navigate is taking you: a point, or along a bearing.
enum Goal: Codable, Equatable, Sendable {
    case point(Target)
    case bearing(BearingLine)
}

/// Whether the watch is pointing along the bearing, with hysteresis so a reading
/// hovering at the edge does not buzz on and off.
struct BearingHold: Equatable {
    static let onWithin = 5.0
    static let offBeyond = 10.0

    enum Cue: Equatable { case onBearing, turnLeft, turnRight }

    private(set) var isOn = false

    /// `deviation` is bearing minus heading: positive means the bearing is to the right.
    /// Returns a cue when the state changes.
    mutating func update(deviation: Double) -> Cue? {
        let degrees = Compass.signed(deviation)
        if isOn, abs(degrees) > Self.offBeyond {
            isOn = false
            return degrees > 0 ? .turnRight : .turnLeft
        }
        if !isOn, abs(degrees) <= Self.onWithin {
            isOn = true
            return .onBearing
        }
        return nil
    }
}
