// TargetEntryView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// Coordinate entry for gloves and one hand: the arrows pick a field, the Digital Crown
/// changes it. Starts from the current position, since usually only the trailing
/// digits differ.
struct TargetEntryView: View {
    typealias Field = CoordinateEntry.Field

    let onSet: (Coordinate) -> Void

    @State private var entry: CoordinateEntry
    @State private var field = Field.latMinutes
    @State private var crown = 0.0
    @FocusState private var isFocused: Bool

    init(start: Coordinate, onSet: @escaping (Coordinate) -> Void) {
        self.onSet = onSet
        _entry = State(initialValue: CoordinateEntry(start))
    }

    var body: some View {
        VStack(spacing: 6) {
            row([.latHemisphere, .latDegrees, .latMinutes, .latHundredths, .latTens, .latOnes])
            row([.lonHemisphere, .lonDegrees, .lonMinutes, .lonHundredths, .lonTens, .lonOnes])
            HStack {
                Button("Previous field", systemImage: "chevron.left") { move(by: -1) }
                Button("Next field", systemImage: "chevron.right") { move(by: 1) }
            }
            .labelStyle(.iconOnly)
            Button("Go") { onSet(entry.coordinate) }
                .tint(.green)
        }
        .focusable()
        .focused($isFocused)
        .digitalCrownRotation($crown, from: -1_000_000, through: 1_000_000, by: 1,
                              sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
        .onChange(of: crown) { old, new in
            let steps = Int(new.rounded()) - Int(old.rounded())
            if steps != 0 { entry.adjust(field, by: steps) }
        }
        .onAppear { isFocused = true }
    }

    private func row(_ fields: [Field]) -> some View {
        HStack(spacing: 0) {
            ForEach(fields, id: \.self) { item in
                segment(item)
                switch item {
                case .latHemisphere, .lonHemisphere: Text(" ")
                case .latDegrees, .lonDegrees: Text("° ")
                case .latMinutes, .lonMinutes: Text(".")
                default: EmptyView()
                }
            }
        }
        .font(.system(size: 22, weight: .semibold, design: .monospaced))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    private func segment(_ item: Field) -> some View {
        Text(entry.text(item))
            .padding(.vertical, 2)
            .background(item == field ? Color.accentColor.opacity(0.45) : .clear, in: .rect(cornerRadius: 3))
            .onTapGesture { field = item }
    }

    private func move(by offset: Int) {
        let all = Field.allCases
        field = all[(field.rawValue + offset + all.count) % all.count]
        Haptics.play(.click)
    }
}
