// Haptics.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import WatchKit

enum Haptics {
    static func play(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
}
