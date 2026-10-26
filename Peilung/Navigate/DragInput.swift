// DragInput.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

extension View {
    /// The iPhone's Digital Crown: dragging up or down calls `onStep` with the steps
    /// passed, up counting up, with a click for each.
    func dragInput(onStep: @escaping (Int) -> Void) -> some View {
        modifier(DragInput(onStep: onStep))
    }
}

private struct DragInput: ViewModifier {
    /// Points of travel per step.
    private static let stepHeight = 14.0

    let onStep: (Int) -> Void
    /// Steps already passed in the current drag.
    @State private var passed = 0

    func body(content: Content) -> some View {
        content
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { drag in
                        let steps = Int(-drag.translation.height / Self.stepHeight)
                        guard steps != passed else { return }
                        onStep(steps - passed)
                        passed = steps
                        Haptics.play(.click)
                    }
                    .onEnded { _ in passed = 0 }
            )
    }
}
