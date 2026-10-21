// MarksView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct MarksView: View {
    @Environment(MarkStore.self) private var marks
    @Environment(LocationModel.self) private var location
    @Environment(Navigator.self) private var navigator
    @AppStorage(Units.storageKey) private var units = Units.localeDefault
    @State private var renaming: Mark?

    var body: some View {
        List {
            if marks.marks.isEmpty {
                Text("No marks yet. Save one from the Here page.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(marks.marks) { mark in
                Button { navigator.navigate(to: mark.target) } label: { row(mark) }
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) { marks.delete(mark.id) }
                        Button("Rename", systemImage: "pencil") { renaming = mark }
                            .tint(.blue)
                    }
            }
            Section {
                Picker("Units", selection: $units) {
                    ForEach(Units.allCases) { Text($0.label).tag($0) }
                }
            }
        }
        .navigationTitle("Marks")
        .sheet(item: $renaming) { mark in
            RenameView(name: mark.name) { marks.rename(mark.id, to: $0) }
        }
    }

    private func row(_ mark: Mark) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(mark.name).font(.headline).lineLimit(1)
            Group {
                Text(mark.coordinate.latitudeText)
                Text(mark.coordinate.longitudeText)
            }
            .font(.system(.footnote, design: .monospaced))
            HStack {
                Text(mark.date, format: .relative(presentation: .named))
                Spacer()
                if let here = location.coordinate {
                    Text(units.format(meters: here.distance(to: mark.coordinate)))
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }
}

private struct RenameView: View {
    @State var name: String
    let onDone: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            TextField("Name", text: $name)
            Button("Save") {
                onDone(name)
                dismiss()
            }
        }
    }
}
