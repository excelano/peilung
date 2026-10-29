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
    var changed: Date?

    var target: Target { Target(name: name, coordinate: coordinate) }
    var lastChanged: Date { changed ?? date }
}

@MainActor
@Observable
final class MarkStore {
    struct Contents: Codable, Equatable {
        static let deletionMemory: TimeInterval = 90 * 24 * 3600

        var marks: [Mark] = []
        var deleted: [Mark.ID: Date] = [:]

        init() {}

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            marks = try container.decode([Mark].self, forKey: .marks)
            deleted = try container.decodeIfPresent([Mark.ID: Date].self, forKey: .deleted) ?? [:]
        }

        func merged(with other: Contents, at now: Date = .now) -> Contents {
            var result = Contents()
            result.deleted = deleted.merging(other.deleted, uniquingKeysWith: max)
                .filter { now.timeIntervalSince($0.value) < Self.deletionMemory }
            var byID = Dictionary(marks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            for mark in other.marks where byID[mark.id].map({ mark.lastChanged > $0.lastChanged }) ?? true {
                byID[mark.id] = mark
            }
            result.marks = byID.values
                .filter { mark in result.deleted[mark.id].map { mark.lastChanged > $0 } ?? true }
                .sorted { ($0.date, $0.id.uuidString) > ($1.date, $1.id.uuidString) }
            return result
        }
    }

    private(set) var contents: Contents

    @ObservationIgnored private let store: Store<Contents>
    @ObservationIgnored var onChange: (() -> Void)?

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

    /// The mark already at `coordinate`, or a new one there.
    func mark(at coordinate: Coordinate, date: Date = .now) -> Mark {
        marks.first { $0.coordinate == coordinate } ?? add(coordinate, at: date)
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
        contents.marks[index].changed = .now
        save()
    }

    func delete(_ id: Mark.ID) {
        contents.marks.removeAll { $0.id == id }
        contents.deleted[id] = .now
        save()
    }

    func receive(_ other: Contents) -> Bool {
        let merged = contents.merged(with: other)
        if merged != contents {
            contents = merged
            store.save(contents)
        }
        return merged != other.merged(with: Contents())
    }

    private func save() {
        store.save(contents)
        onChange?()
    }
}
