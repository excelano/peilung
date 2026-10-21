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

    /// One past the highest default name still in the list, so numbering carries on
    /// while numbered marks remain and starts again at 1 once none do.
    private var nextNumber: Int {
        let numbers = contents.marks.compactMap { mark -> Int? in
            guard mark.name.hasPrefix("Mark ") else { return nil }
            return Int(mark.name.dropFirst("Mark ".count))
        }
        return (numbers.max() ?? 0) + 1
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
