// CrownInput.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

extension View {
    /// Makes this view take the Digital Crown as whole detents counted into `value`.
    /// Focus is claimed once the sheet has finished presenting, and again on a tap.
    func crownInput(_ value: Binding<Double>, focus: FocusState<Bool>.Binding) -> some View {
        contentShape(.rect)
            .focusable()
            .focused(focus)
            .digitalCrownRotation(value, from: -1_000_000, through: 1_000_000, by: 1,
                                  sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
            .onTapGesture { focus.wrappedValue = true }
            .task {
                try? await Task.sleep(for: .milliseconds(300))
                focus.wrappedValue = true
            }
    }
}
