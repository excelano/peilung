// Navigator.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Observation

enum Page: String, Hashable {
    case navigate, odometer, here, marks
}

/// The page on screen and where Navigate is taking you. The app reopens on the last page.
@MainActor
@Observable
final class Navigator {
    static let pageKey = "page"
    static let goalChangedKey = "goalChanged"

    var page: Page {
        didSet { defaults.set(page.rawValue, forKey: Self.pageKey) }
    }
    private(set) var goal: Goal?
    @ObservationIgnored private(set) var goalChanged: Date?
    @ObservationIgnored var onChange: (() -> Void)?

    @ObservationIgnored private let store: Store<Goal>
    @ObservationIgnored private let defaults: UserDefaults

    init(store: Store<Goal>, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
        page = defaults.string(forKey: Self.pageKey).flatMap(Page.init) ?? .navigate
        goal = store.load()
        goalChanged = defaults.object(forKey: Self.goalChangedKey) as? Date
    }

    func navigate(to target: Target) {
        set(.point(target))
    }

    func follow(_ line: BearingLine) {
        set(.bearing(line))
    }

    func clear() {
        update(nil, changed: .now)
        onChange?()
    }

    func receive(_ goal: Goal?, changed: Date) {
        guard changed > goalChanged ?? .distantPast else { return }
        update(goal, changed: changed)
        if goal != nil { page = .navigate }
    }

    private func set(_ goal: Goal) {
        update(goal, changed: .now)
        page = .navigate
        onChange?()
    }

    private func update(_ goal: Goal?, changed: Date) {
        self.goal = goal
        goalChanged = changed
        store.save(goal)
        defaults.set(changed, forKey: Self.goalChangedKey)
    }
}
