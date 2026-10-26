// Platform.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// The words and looks that differ between the watch and the iPhone.
enum Device {
    static let name = "iPhone"

    /// Where a refused permission is turned back on.
    static func allow(_ permission: String) -> String {
        "Allow \(permission) for Peilung in Settings > Privacy & Security."
    }
}

extension View {
    /// A page's main button.
    func actionButton() -> some View {
        buttonStyle(.borderedProminent).controlSize(.large)
    }
}
