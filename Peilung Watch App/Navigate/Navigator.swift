// Navigator.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Observation

enum Page: Hashable {
    case odometer, here, navigate, marks
}

/// The page on screen and where Navigate is taking you.
@MainActor
@Observable
final class Navigator {
    var page = Page.odometer
    private(set) var goal: Goal?

    @ObservationIgnored private let store: Store<Goal>

    init(store: Store<Goal>) {
        self.store = store
        goal = store.load()
    }

    func navigate(to target: Target) {
        set(.point(target))
    }

    func follow(_ line: BearingLine) {
        set(.bearing(line))
    }

    private func set(_ goal: Goal) {
        self.goal = goal
        store.save(goal)
        page = .navigate
    }
}
