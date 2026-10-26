// Platform.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// The words and looks that differ between the watch and the iPhone.
enum Device {
    static let name = "watch"
    /// The goal's title on Navigate, which also becomes the Stop navigating button.
    static let goalTitleFont = Font.footnote

    /// Where a refused permission is turned back on: the watch app's switches live on the iPhone.
    static func allow(_ permission: String) -> String {
        "On your iPhone, allow \(permission) in Settings > Privacy."
    }
}

extension View {
    /// A page's main button. watchOS draws a full-width button already.
    func actionButton() -> some View {
        self
    }
}
