// TargetEntryView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// Coordinate entry, field by field as on the watch: tap or step to a field, then
/// drag the digits or use the up and down buttons to change it. Starts from the
/// current position, since usually only the trailing digits differ, and shows how
/// far and which way the entered point is as it changes.
struct TargetEntryView: View {
    typealias Field = CoordinateEntry.Field

    @Environment(LocationModel.self) private var location
    @AppStorage(Units.storageKey) private var units = Units.localeDefault
    @AppStorage(NorthReference.storageKey) private var reference = NorthReference.magnetic

    let onSet: (Coordinate) -> Void

    @State private var entry: CoordinateEntry
    @State private var field = CoordinateEntry.firstField

    init(start: Coordinate, format: CoordinateFormat, onSet: @escaping (Coordinate) -> Void) {
        self.onSet = onSet
        _entry = State(initialValue: CoordinateEntry(start, format: format))
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                row(entry.row(isLatitude: true))
                row(entry.row(isLatitude: false))
            }
            .dragInput { entry.adjust(field, by: $0) }
            Text(entry.offset(from: location.coordinate, units: units, north: North(reference, declination: location.declination)))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(spacing: 12) {
                Button("Previous field", systemImage: "chevron.left") { move(by: -1) }
                Button("Down", systemImage: "chevron.down") { step(by: -1) }
                Button("Up", systemImage: "chevron.up") { step(by: 1) }
                Button("Next field", systemImage: "chevron.right") { move(by: 1) }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .controlSize(.large)
            Button("Go") { onSet(entry.coordinate) }
                .tint(.green)
                .actionButton()
        }
        .padding()
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func row(_ fields: [Field]) -> some View {
        HStack(spacing: 0) {
            ForEach(fields, id: \.self) { item in
                segment(item)
                Text(entry.separator(item))
            }
        }
        .font(.system(size: 30, weight: .semibold, design: .monospaced))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    private func segment(_ item: Field) -> some View {
        Text(entry.text(item))
            .padding(.vertical, 2)
            .background(item == field ? Color.accentColor.opacity(0.45) : .clear, in: .rect(cornerRadius: 4))
            .onTapGesture { field = item }
    }

    private func move(by offset: Int) {
        let all = entry.fields
        field = all[((all.firstIndex(of: field) ?? 0) + offset + all.count) % all.count]
        Haptics.play(.click)
    }

    private func step(by steps: Int) {
        entry.adjust(field, by: steps)
        Haptics.play(.click)
    }
}
