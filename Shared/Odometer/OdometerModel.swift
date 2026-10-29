// OdometerModel.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Observation

@MainActor
@Observable
final class OdometerModel {
    static let changedKey = "odometerChanged"

    private(set) var state: OdometerState
    /// Meters walked since Start, while running; nil until the pedometer first answers.
    private(set) var liveDistance: Double?
    private(set) var errorText: String?

    @ObservationIgnored private let pedometer: Pedometer
    @ObservationIgnored private let store: Store<OdometerState>
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isWatching = false
    @ObservationIgnored private(set) var changed: Date?
    @ObservationIgnored var onChange: (() -> Void)?

    init(pedometer: Pedometer, store: Store<OdometerState>, defaults: UserDefaults = .standard) {
        self.pedometer = pedometer
        self.store = store
        self.defaults = defaults
        state = store.load() ?? OdometerState()
        changed = defaults.object(forKey: Self.changedKey) as? Date
    }

    var run: OdometerState {
        var run = state
        run.finalDistance = nil
        return run
    }

    var isAvailable: Bool { pedometer.isAvailable }
    var isDenied: Bool { pedometer.isDenied }

    /// Why the reading can't be trusted or taken, if it can't.
    func message(at now: Date) -> String? {
        if !isAvailable { return "This \(Device.name) can't track distance." }
        if isDenied { return Device.allow("Motion & Fitness") }
        if state.phase == .running && state.exceedsHistory(at: now) {
            return "Started over 7 days ago; the \(Device.name) keeps only 7 days of steps."
        }
        return errorText
    }

    var distance: Double? {
        Pedometers.shown(state.phase == .stopped ? state.finalDistance : liveDistance)
    }

    func start(from coordinate: Coordinate?) {
        state.start(at: .now, from: coordinate)
        liveDistance = 0
        errorText = nil
        save()
        announce()
        if isWatching { beginUpdates() }
    }

    func stop() {
        guard state.phase == .running, let startDate = state.startDate else { return }
        let end = Date.now
        state.stop(at: end)
        state.finalDistance = liveDistance
        save()
        announce()
        pedometer.stopUpdates()
        Task { await settle(from: startDate, to: end) }
    }

    func reset() {
        pedometer.stopUpdates()
        state.reset()
        liveDistance = nil
        errorText = nil
        save()
        announce()
    }

    func offerStartFix(_ coordinate: Coordinate) {
        let before = state
        state.offerStartFix(coordinate, at: .now)
        if state != before {
            save()
            announce()
        }
    }

    func receive(_ run: OdometerState, changed: Date) {
        guard changed > self.changed ?? .distantPast else { return }
        let before = state
        state.adopt(run)
        record(changed)
        save()
        guard state.startDate != before.startDate || state.endDate != before.endDate else { return }
        errorText = nil
        pedometer.stopUpdates()
        switch state.phase {
        case .running:
            if state.startDate != before.startDate { liveDistance = 0 }
            if isWatching { beginUpdates() }
        case .stopped:
            if let start = state.startDate, let end = state.endDate {
                Task { await settle(from: start, to: end) }
            }
        case .idle:
            liveDistance = nil
        }
    }

    /// The Odometer page is showing: follow the pedometer live, or retry a stopped
    /// reading whose final query failed.
    func watch() {
        isWatching = true
        switch state.phase {
        case .running:
            beginUpdates()
        case .stopped:
            if state.finalDistance == nil, let start = state.startDate, let end = state.endDate {
                Task { await settle(from: start, to: end) }
            }
        case .idle:
            break
        }
    }

    func unwatch() {
        isWatching = false
        pedometer.stopUpdates()
    }

    private func beginUpdates() {
        guard let startDate = state.startDate else { return }
        pedometer.startUpdates(from: startDate) { [weak self] result in
            guard let self, self.state.phase == .running, self.state.startDate == startDate else { return }
            switch result {
            case .success(let meters):
                self.liveDistance = meters
                self.errorText = nil
            case .failure(let error):
                self.errorText = error.localizedDescription
            }
        }
    }

    /// Replaces the live figure at Stop with the pedometer's own count for the run.
    private func settle(from start: Date, to end: Date) async {
        do {
            let meters = try await pedometer.distance(from: start, to: end)
            guard state.startDate == start else { return }
            state.finalDistance = meters
            errorText = nil
            save()
        } catch {
            guard state.startDate == start else { return }
            errorText = error.localizedDescription
        }
    }

    private func save() {
        store.save(state)
    }

    private func announce() {
        record(.now)
        onChange?()
    }

    private func record(_ changed: Date) {
        self.changed = changed
        defaults.set(changed, forKey: Self.changedKey)
    }
}
