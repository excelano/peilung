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

    /// The magnetic bearing once locked or dialed; nil while following the compass.
    @State private var fixed: Double?
    @State private var crown = 0.0
    @FocusState private var isFocused: Bool

    private var north: North { North(reference, declination: location.declination) }

    private var magnetic: Double? { fixed ?? location.magneticHeading }

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(magnetic.map { North.degrees(north.shown(magnetic: $0)) } ?? "---°")
                    .font(.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit())
                Text(north.magneticSuffix)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(fixed == nil ? Color.accentColor : .primary)
            .crownInput($crown, focus: $isFocused)
            if fixed == nil, let warning = CompassWarning.text(location.headingAccuracy) {
                Text(warning)
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if fixed == nil && location.magneticHeading != nil {
                Button("Lock") {
                    fixed = location.magneticHeading
                    Haptics.play(.click)
                }
                .tint(.accentColor)
            } else {
                Button("Follow") { follow() }
                    .tint(.green)
                    .disabled(magnetic == nil)
            }
        }
        .onChange(of: crown) { old, new in
            let steps = Int(new.rounded()) - Int(old.rounded())
            guard steps != 0 else { return }
            let shown = magnetic.map { north.shown(magnetic: $0) } ?? 0
            fixed = north.magnetic(shown: shown.rounded() + Double(steps))
        }
    }

    private var hint: String {
        if fixed != nil { return "Turn the crown to adjust." }
        if location.magneticHeading != nil { return "Point 12 o'clock at the landmark, or turn the crown." }
        return "Turn the crown to set a bearing."
    }

    private func follow() {
        guard let magnetic else { return }
        let origin = location.freshLocation().map { Coordinate($0.coordinate) }
        onFollow(BearingLine(magnetic: magnetic, origin: origin))
        Haptics.play(.start)
    }
}
