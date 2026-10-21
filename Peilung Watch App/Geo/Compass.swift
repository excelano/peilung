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
