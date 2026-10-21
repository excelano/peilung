// MarkStore.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Observation

struct Mark: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var coordinate: Coordinate
    var date: Date

    var target: Target { Target(name: name, coordinate: coordinate) }
}

@MainActor
@Observable
final class MarkStore {
    struct Contents: Codable {
        var marks: [Mark] = []
        /// Numbers default names, and keeps counting past deleted marks so a name is never reused.
        var nextNumber = 1
    }

    private(set) var contents: Contents

    @ObservationIgnored private let store: Store<Contents>

    init(store: Store<Contents>) {
        self.store = store
        contents = store.load() ?? Contents()
    }

    /// Newest first.
    var marks: [Mark] { contents.marks }

    @discardableResult
    func add(_ coordinate: Coordinate, at date: Date = .now) -> Mark {
        let mark = Mark(name: "Mark \(contents.nextNumber)", coordinate: coordinate, date: date)
        contents.marks.insert(mark, at: 0)
        contents.nextNumber += 1
        save()
        return mark
    }

    func rename(_ id: Mark.ID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = contents.marks.firstIndex(where: { $0.id == id }) else { return }
        contents.marks[index].name = trimmed
        save()
    }

    func delete(_ id: Mark.ID) {
        contents.marks.removeAll { $0.id == id }
        save()
    }

    private func save() {
        store.save(contents)
    }
}
