// OdometerTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Testing
@testable import Peilung_Watch_App

struct OdometerStateTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let here = Coordinate(latitude: 29.75, longitude: -95.37)

    @Test func startStopReset() {
        var state = OdometerState()
        #expect(state.phase == .idle)
        #expect(state.elapsed(at: t0) == 0)

        state.start(at: t0, from: here)
        #expect(state.phase == .running)
        #expect(state.startCoordinate == here)
        #expect(state.elapsed(at: t0 + 90) == 90)

        state.stop(at: t0 + 600)
        #expect(state.phase == .stopped)
        #expect(state.elapsed(at: t0 + 9_999) == 600)

        state.stop(at: t0 + 900)
        #expect(state.elapsed(at: t0 + 9_999) == 600)

        state.reset()
        #expect(state == OdometerState())
    }

    @Test func startClearsThePreviousRun() {
        var state = OdometerState()
        state.start(at: t0, from: here)
        state.stop(at: t0 + 60)
        state.finalDistance = 80
        state.start(at: t0 + 120, from: nil)
        #expect(state.phase == .running)
        #expect(state.finalDistance == nil)
        #expect(state.startCoordinate == nil)
    }

    @Test func lateFixBecomesStartWithinWindow() {
        var state = OdometerState()
        state.start(at: t0, from: nil)
        state.offerStartFix(here, at: t0 + 30)
        #expect(state.startCoordinate == here)

        let elsewhere = Coordinate(latitude: 30, longitude: -95)
        state.offerStartFix(elsewhere, at: t0 + 31)
        #expect(state.startCoordinate == here)
    }

    @Test func lateFixIgnoredAfterWindow() {
        var state = OdometerState()
        state.start(at: t0, from: nil)
        state.offerStartFix(here, at: t0 + OdometerState.startFixWindow + 1)
        #expect(state.startCoordinate == nil)
    }

    @Test func historyLimit() {
        var state = OdometerState()
        state.start(at: t0, from: nil)
        #expect(!state.exceedsHistory(at: t0 + 6 * 24 * 3600))
        #expect(state.exceedsHistory(at: t0 + 8 * 24 * 3600))
    }

    @Test func persistsThroughStore() throws {
        let store = Store<OdometerState>(url: temporaryURL())
        var state = OdometerState()
        state.start(at: t0, from: here)
        state.stop(at: t0 + 600)
        state.finalDistance = 812.5
        store.save(state)
        #expect(store.load() == state)
        store.save(nil)
        #expect(store.load() == nil)
    }
}

@MainActor
final class FakePedometer: Pedometer {
    var isAvailable = true
    var isDenied = false
    var handler: (@MainActor (Result<Double, Error>) -> Void)?
    var queried: Double = 0

    func startUpdates(from start: Date, handler: @escaping @MainActor (Result<Double, Error>) -> Void) {
        self.handler = handler
    }

    func stopUpdates() {
        handler = nil
    }

    func distance(from start: Date, to end: Date) async throws -> Double {
        queried
    }
}

@MainActor
struct OdometerModelTests {
    let pedometer = FakePedometer()
    let url = temporaryURL()

    @Test func liveUpdatesThenSettlesOnStop() async {
        let model = OdometerModel(pedometer: pedometer, store: Store(url: url))
        model.watch()
        model.start(from: nil)
        pedometer.handler?(.success(120))
        #expect(model.distance == 120)

        pedometer.queried = 125
        model.stop()
        #expect(model.distance == 120)
        #expect(pedometer.handler == nil)
        await Task.yield()
        await Task.yield()
        #expect(model.distance == 125)

        let reloaded = OdometerModel(pedometer: pedometer, store: Store(url: url))
        #expect(reloaded.state.phase == .stopped)
        #expect(reloaded.distance == 125)
    }

    @Test func resetClears() {
        let model = OdometerModel(pedometer: pedometer, store: Store(url: url))
        model.watch()
        model.start(from: nil)
        pedometer.handler?(.success(50))
        model.reset()
        #expect(model.state.phase == .idle)
        #expect(model.distance == nil)
        #expect(OdometerModel(pedometer: pedometer, store: Store(url: url)).state.phase == .idle)
    }
}

@MainActor
struct MarkStoreTests {
    let url = temporaryURL()
    let here = Coordinate(latitude: 29.75, longitude: -95.37)

    @Test func namesCountPastDeletions() {
        let store = MarkStore(store: Store(url: url))
        let first = store.add(here)
        let second = store.add(here)
        #expect(first.name == "Mark 1")
        #expect(second.name == "Mark 2")
        store.delete(second.id)
        #expect(store.add(here).name == "Mark 3")
        #expect(store.marks.map(\.name) == ["Mark 3", "Mark 1"])
    }

    @Test func renameTrimsAndRejectsBlank() {
        let store = MarkStore(store: Store(url: url))
        let mark = store.add(here)
        store.rename(mark.id, to: "  Car  ")
        #expect(store.marks.first?.name == "Car")
        store.rename(mark.id, to: "   ")
        #expect(store.marks.first?.name == "Car")
    }

    @Test func persists() {
        let store = MarkStore(store: Store(url: url))
        store.add(here)
        let reloaded = MarkStore(store: Store(url: url))
        #expect(reloaded.marks == store.marks)
        #expect(reloaded.add(here).name == "Mark 2")
    }
}

func temporaryURL() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "peilung-test-\(UUID().uuidString).json")
}
