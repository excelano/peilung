// BearingEntryView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// Takes a bearing two ways: sight it by pointing the top of the iPhone at a landmark
/// and locking the live compass reading, or dial it by dragging the number or with the
/// minus and plus buttons. Dialing also adjusts a locked reading.
struct BearingEntryView: View {
    @Environment(LocationModel.self) private var location
    @AppStorage(NorthReference.storageKey) private var reference = NorthReference.magnetic

    let onFollow: (BearingLine) -> Void

    /// The magnetic bearing once locked or dialed; nil while following the compass.
    @State private var fixed: Double?

    private var north: North { North(reference, declination: location.declination) }

    private var magnetic: Double? { fixed ?? location.magneticHeading }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(magnetic.map { North.degrees(north.shown(magnetic: $0)) } ?? "---°")
                    .font(.system(size: 72, weight: .semibold, design: .rounded).monospacedDigit())
                Text(north.magneticSuffix)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(fixed == nil ? Color.accentColor : .primary)
            .dragInput { dial(by: $0) }
            if fixed == nil, let warning = CompassWarning.text(location.headingAccuracy) {
                Text(warning)
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            } else {
                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 12) {
                Button("Minus one degree", systemImage: "minus") {
                    dial(by: -1)
                    Haptics.play(.click)
                }
                Button("Plus one degree", systemImage: "plus") {
                    dial(by: 1)
                    Haptics.play(.click)
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .controlSize(.large)
            Spacer(minLength: 0)
            if fixed == nil && location.magneticHeading != nil {
                Button("Lock") {
                    fixed = location.magneticHeading
                    Haptics.play(.click)
                }
                .tint(.accentColor)
                .actionButton()
            } else {
                Button("Follow") { follow() }
                    .tint(.green)
                    .actionButton()
                    .disabled(magnetic == nil)
            }
        }
        .padding()
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var hint: String {
        if fixed != nil { return "Drag the number to adjust." }
        if location.magneticHeading != nil { return "Point the top of the iPhone at the landmark, or drag the number." }
        return "Drag the number to set a bearing."
    }

    private func dial(by steps: Int) {
        let shown = magnetic.map { north.shown(magnetic: $0) } ?? 0
        fixed = north.magnetic(shown: shown.rounded() + Double(steps))
    }

    private func follow() {
        guard let magnetic else { return }
        let origin = location.freshLocation().map { Coordinate($0.coordinate) }
        onFollow(BearingLine(magnetic: magnetic, origin: origin))
        Haptics.play(.start)
    }
}
