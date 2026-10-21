// Navigator.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Observation

enum Page: Hashable {
    case odometer, here, navigate, marks
}

/// The page on screen and the target being navigated to.
@MainActor
@Observable
final class Navigator {
    var page = Page.odometer
    private(set) var target: Target?

    @ObservationIgnored private let store: Store<Target>

    init(store: Store<Target>) {
        self.store = store
        target = store.load()
    }

    func navigate(to target: Target) {
        self.target = target
        store.save(target)
        page = .navigate
    }

    func clearTarget() {
        target = nil
        store.save(nil)
    }
}
