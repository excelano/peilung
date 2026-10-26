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

    var page: Page {
        didSet { defaults.set(page.rawValue, forKey: Self.pageKey) }
    }
    private(set) var goal: Goal?

    @ObservationIgnored private let store: Store<Goal>
    @ObservationIgnored private let defaults: UserDefaults

    init(store: Store<Goal>, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
        page = defaults.string(forKey: Self.pageKey).flatMap(Page.init) ?? .navigate
        goal = store.load()
    }

    func navigate(to target: Target) {
        set(.point(target))
    }

    func follow(_ line: BearingLine) {
        set(.bearing(line))
    }

    func clear() {
        goal = nil
        store.save(nil)
    }

    private func set(_ goal: Goal) {
        self.goal = goal
        store.save(goal)
        page = .navigate
    }
}
