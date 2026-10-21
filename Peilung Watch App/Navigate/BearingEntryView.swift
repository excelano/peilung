// BearingEntryView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// Takes a bearing two ways: sight it by pointing 12 o'clock at a landmark and
/// locking the live compass reading, or dial it with the Digital Crown. Turning the
/// crown also adjusts a locked reading.
struct BearingEntryView: View {
    @Environment(LocationModel.self) private var location
    @AppStorage(NorthReference.storageKey) private var reference = NorthReference.magnetic

    let onFollow: (BearingLine) -> Void

    /// The bearing as shown, once locked or dialed; nil while following the compass.
    @State private var fixed: Double?
    @State private var crown = 0.0
    @FocusState private var isFocused: Bool

    private var north: North { North(reference, declination: location.declination) }

    private var shown: Double? {
        fixed ?? location.heading.map(north.shown)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(shown.map(North.degrees) ?? "---°")
                    .font(.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit())
                Text(north.suffix)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(fixed == nil ? Color.accentColor : .primary)
            .crownInput($crown, focus: $isFocused)
            Text(hint)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if fixed == nil, let warning = CompassWarning.text(location.headingAccuracy) {
                Text(warning).font(.footnote).foregroundStyle(.orange).multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
            if fixed == nil && location.heading != nil {
                Button("Lock") {
                    fixed = shown
                    Haptics.play(.click)
                }
                .tint(.accentColor)
            } else {
                Button("Follow") { follow() }
                    .tint(.green)
                    .disabled(shown == nil)
            }
        }
        .onChange(of: crown) { old, new in
            let steps = Int(new.rounded()) - Int(old.rounded())
            if steps != 0 { fixed = Compass.normalized((shown ?? 0).rounded() + Double(steps)) }
        }
    }

    private var hint: String {
        if fixed != nil { return "Turn the crown to adjust." }
        if location.heading != nil { return "Point 12 o'clock at the landmark, or turn the crown." }
        return "Turn the crown to set a bearing."
    }

    private func follow() {
        guard let shown else { return }
        let origin = location.freshLocation().map { Coordinate($0.coordinate) }
        onFollow(BearingLine(bearing: north.trueBearing(shown), origin: origin))
        Haptics.play(.start)
    }
}

enum CompassWarning {
    /// Above this the compass is too rough to follow a bearing by.
    static let accuracyLimit = 20.0

    static func text(_ accuracy: Double?) -> String? {
        guard let accuracy, accuracy > accuracyLimit else { return nil }
        return "Compass ±\(Int(accuracy.rounded()))°. Move the watch in a figure 8 to calibrate."
    }
}
