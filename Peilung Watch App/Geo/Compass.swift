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

    /// "N", "NE", … for a bearing in degrees.
    static func point(_ degrees: Double) -> String {
        let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int(((degrees + 22.5) / 45).rounded(.down))
        return points[(index % 8 + 8) % 8]
    }
}
