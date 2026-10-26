// Haptics.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import UIKit

@MainActor
enum Haptics {
    /// Turns play three impacts growing for right and fading for left, after the
    /// watch's rising and falling direction taps.
    static func play(_ haptic: Haptic) {
        switch haptic {
        case .click: UISelectionFeedbackGenerator().selectionChanged()
        case .start: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .stop, .arrived: UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .success, .onBearing: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .turnLeft: pulse([1, 0.6, 0.3])
        case .turnRight: pulse([0.3, 0.6, 1])
        }
    }

    private static func pulse(_ intensities: [Double]) {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        Task {
            for intensity in intensities {
                generator.impactOccurred(intensity: intensity)
                try? await Task.sleep(for: .milliseconds(120))
            }
        }
    }
}
