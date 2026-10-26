// Haptics.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import WatchKit

enum Haptics {
    /// watchOS's own navigation turn haptics play nothing for this app on a Series 9,
    /// so turns use the direction pair: up for right, down for left.
    static func play(_ haptic: Haptic) {
        let type: WKHapticType = switch haptic {
        case .click: .click
        case .start: .start
        case .stop, .arrived: .stop
        case .success, .onBearing: .success
        case .turnLeft: .directionDown
        case .turnRight: .directionUp
        }
        WKInterfaceDevice.current().play(type)
    }
}
