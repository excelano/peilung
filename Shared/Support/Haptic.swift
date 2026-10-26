// Haptic.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

/// The taps the app plays. Each platform's `Haptics` turns them into its own feedback.
enum Haptic {
    case click, start, stop, success
    /// The navigation cues.
    case turnLeft, turnRight, onBearing, arrived
}
