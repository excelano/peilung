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
        let mark = Mark(name: "Mark \(nextNumber)", coordinate: coordinate, date: date)
        contents.marks.insert(mark, at: 0)
        save()
        return mark
    }

    /// The lowest number no current mark is named after, so an emptied list starts again at 1.
    private var nextNumber: Int {
        let taken = Set(contents.marks.map(\.name))
        return (1...).first { !taken.contains("Mark \($0)") }!
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
