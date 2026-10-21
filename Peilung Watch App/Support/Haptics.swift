// Haptics.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import WatchKit

enum Haptics {
    /// The navigation cues. watchOS's own navigation turn haptics play nothing for this
    /// app on a Series 9, so turns use the direction pair: up for right, down for left.
    static let turnLeft = WKHapticType.directionDown
    static let turnRight = WKHapticType.directionUp
    static let onBearing = WKHapticType.success
    static let arrived = WKHapticType.stop

    static func play(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
}
