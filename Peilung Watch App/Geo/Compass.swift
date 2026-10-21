// Compass.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

enum Compass {
    /// Below this distance GPS noise outweighs the arrow.
    static let nearTargetMeters = 10.0

    /// Returns the angle equivalent to `target` (mod 360) that lies closest to `current`,
    /// so a rotation animation crossing north turns the short way instead of spinning round.
    static func unwrapped(_ target: Double, from current: Double) -> Double {
        var delta = (target - current).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return current + delta
    }

    /// The same angle in -180 ... 180, negative meaning anticlockwise.
    static func signed(_ degrees: Double) -> Double {
        unwrapped(degrees, from: 0)
    }

    /// "40° left" when a target lies well off the way the watch points, nil when it is
    /// roughly ahead. `deviation` is bearing minus heading.
    static func turn(_ deviation: Double) -> String? {
        let degrees = signed(deviation)
        guard abs(degrees) > BearingHold.offBeyond else { return nil }
        return "\(Int(abs(degrees).rounded()))° " + (degrees > 0 ? "right" : "left")
    }

    /// The same angle in 0 ..< 360.
    static func normalized(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }
}

enum CompassWarning {
    /// Above this the compass is too rough to follow a bearing by.
    static let accuracyLimit = 20.0

    static func text(_ accuracy: Double?) -> String? {
        guard let accuracy, accuracy > accuracyLimit else { return nil }
        return "Compass ±\(Int(accuracy.rounded()))°. Move the watch in a figure 8 to calibrate."
    }
}

/// Whether you have reached a point, with hysteresis so GPS noise at the target
/// does not announce the arrival over and over.
struct Arrival: Equatable {
    /// Leaving again takes twice the arrival distance.
    static let leaveMeters = Compass.nearTargetMeters * 2

    private(set) var isNear = false

    /// Returns true once, on arriving.
    mutating func update(distance: Double) -> Bool {
        if isNear {
            if distance > Self.leaveMeters { isNear = false }
            return false
        }
        isNear = distance < Compass.nearTargetMeters
        return isNear
    }
}
