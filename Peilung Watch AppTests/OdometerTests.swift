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
    var queryError: Error?
    /// When set, queries wait until the test resumes `pending`.
    var holdsQueries = false
    var pending: CheckedContinuation<Double, Error>?
    private(set) var queries = 0

    func startUpdates(from start: Date, handler: @escaping @MainActor (Result<Double, Error>) -> Void) {
        self.handler = handler
    }

    func stopUpdates() {
        handler = nil
    }

    func distance(from start: Date, to end: Date) async throws -> Double {
        queries += 1
        if let queryError { throw queryError }
        guard holdsQueries else { return queried }
        return try await withCheckedThrowingContinuation { pending = $0 }
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

    @Test func updatesFollowThePage() {
        let model = OdometerModel(pedometer: pedometer, store: Store(url: url))
        model.start(from: nil)
        #expect(pedometer.handler == nil)
        model.watch()
        #expect(pedometer.handler != nil)
        model.unwatch()
        #expect(pedometer.handler == nil)
    }

    @Test func liveErrorShowsAndClears() {
        let model = OdometerModel(pedometer: pedometer, store: Store(url: url))
        model.watch()
        model.start(from: nil)
        pedometer.handler?(.failure(CocoaError(.featureUnsupported)))
        #expect(model.errorText != nil)
        pedometer.handler?(.success(20))
        #expect(model.errorText == nil)
        #expect(model.distance == 20)
    }

    @Test func distanceBelowTheMinimumIsHidden() {
        let model = OdometerModel(pedometer: pedometer, store: Store(url: url))
        model.watch()
        model.start(from: nil)
        pedometer.handler?(.success(Pedometers.minimumDistance - 1))
        #expect(model.distance == nil)
        pedometer.handler?(.success(Pedometers.minimumDistance))
        #expect(model.distance == Pedometers.minimumDistance)
    }

    @Test func lateResultAfterResetIsDropped() async {
        let model = OdometerModel(pedometer: pedometer, store: Store(url: url))
        pedometer.holdsQueries = true
        model.watch()
        model.start(from: nil)
        pedometer.handler?(.success(40))
        model.stop()
        await waitUntil { pedometer.pending != nil }
        model.reset()
        pedometer.pending?.resume(returning: 999)
        await Task.yield()
        await Task.yield()
        #expect(model.state.phase == .idle)
        #expect(model.distance == nil)
    }

    @Test func failedFinalQueryKeepsLiveFigureAndRetriesOnWatch() async {
        let model = OdometerModel(pedometer: pedometer, store: Store(url: url))
        model.watch()
        model.start(from: nil)
        pedometer.handler?(.success(40))
        pedometer.queryError = CocoaError(.featureUnsupported)
        model.stop()
        await waitUntil { model.errorText != nil }
        #expect(model.distance == 40)

        // The live figure was saved, so a reopened model has a reading and needs no retry.
        pedometer.queryError = nil
        pedometer.queried = 42
        let reopened = OdometerModel(pedometer: pedometer, store: Store(url: url))
        let before = pedometer.queries
        reopened.watch()
        #expect(reopened.distance == 40)
        #expect(pedometer.queries == before)
    }

    @Test func stoppedReadingWithoutDistanceIsQueriedOnWatch() async {
        var state = OdometerState()
        let start = Date.now.addingTimeInterval(-600)
        state.start(at: start, from: nil)
        state.stop(at: start.addingTimeInterval(300))
        Store<OdometerState>(url: url).save(state)
        pedometer.queried = 380
        let model = OdometerModel(pedometer: pedometer, store: Store(url: url))
        #expect(model.distance == nil)
        model.watch()
        await waitUntil { model.distance != nil }
        #expect(model.distance == 380)
    }

    @Test func messagesInOrderOfImportance() {
        let model = OdometerModel(pedometer: pedometer, store: Store(url: url))
        #expect(model.message(at: .now) == nil)
        model.watch()
        model.start(from: nil)
        pedometer.handler?(.failure(CocoaError(.featureUnsupported)))
        #expect(model.message(at: .now) == model.errorText)
        #expect(model.message(at: .now.addingTimeInterval(8 * 86_400))?.hasPrefix("Started over 7 days ago") == true)
        pedometer.isDenied = true
        #expect(model.message(at: .now) == "On your iPhone, allow Motion & Fitness in Settings > Privacy.")
        pedometer.isAvailable = false
        #expect(model.message(at: .now) == "This watch can't track distance.")
    }

    @Test func stopWhenIdleDoesNothing() {
        let model = OdometerModel(pedometer: pedometer, store: Store(url: url))
        model.stop()
        #expect(model.state.phase == .idle)
        #expect(pedometer.queries == 0)
    }

    @Test func startFixIsSavedOnlyWhenTaken() {
        let model = OdometerModel(pedometer: pedometer, store: Store(url: url))
        model.start(from: nil)
        let fix = Coordinate(latitude: 29.75, longitude: -95.37)
        model.offerStartFix(fix)
        #expect(model.state.startCoordinate == fix)
        #expect(OdometerModel(pedometer: pedometer, store: Store(url: url)).state.startCoordinate == fix)
    }
}

/// Yields until `condition` holds, for work a model starts in its own task.
@MainActor
func waitUntil(_ condition: () -> Bool) async {
    for _ in 0..<1000 where !condition() {
        await Task.yield()
    }
}

@MainActor
struct OdometerSyncTests {
    let pedometer = FakePedometer()
    let url = temporaryURL()
    let defaults = UserDefaults(suiteName: "OdometerSyncTests-\(UUID().uuidString)")!

    private func model() -> OdometerModel {
        OdometerModel(pedometer: pedometer, store: Store(url: url), defaults: defaults)
    }

    @Test func localChangesAreTimedAndAnnouncedWithoutTheDistance() {
        let model = model()
        var announced = 0
        model.onChange = { announced += 1 }
        model.start(from: nil)
        pedometer.handler?(.success(120))
        model.stop()
        #expect(announced == 2)
        #expect(model.changed != nil)
        #expect(model.run.finalDistance == nil)
        #expect(model.run.endDate == model.state.endDate)
    }

    @Test func aRunStoppedElsewhereSettlesThisDevicesOwnSteps() async {
        let model = model()
        model.start(from: nil)
        var run = model.run
        run.stop(at: .now)
        pedometer.queried = 300
        model.receive(run, changed: .now + 1)
        #expect(model.state.phase == .stopped)
        await Task.yield()
        await Task.yield()
        #expect(model.distance == 300)
    }

    @Test func aRunStartedElsewhereFollowsLive() {
        let model = model()
        model.watch()
        var run = OdometerState()
        run.start(at: .now - 60, from: nil)
        model.receive(run, changed: .now)
        #expect(model.state.phase == .running)
        pedometer.handler?(.success(50))
        #expect(model.distance == 50)
    }

    @Test func anOlderRunIsIgnored() {
        let model = model()
        model.start(from: nil)
        model.receive(OdometerState(), changed: .now - 60)
        #expect(model.state.phase == .running)
    }

    @Test func theChangeTimePersists() {
        let model = model()
        model.start(from: nil)
        #expect(self.model().changed == model.changed)
    }
}

@MainActor
struct MarkSyncTests {
    let here = Coordinate(latitude: 29.75, longitude: -95.37)
    let t0 = Date.now - 3600

    private func contents(_ marks: [Mark], deleted: [Mark.ID: Date] = [:]) -> MarkStore.Contents {
        var contents = MarkStore.Contents()
        contents.marks = marks
        contents.deleted = deleted
        return contents
    }

    @Test func marksFromBothDevicesSurviveNewestFirst() {
        let older = Mark(name: "Car", coordinate: here, date: t0)
        let newer = Mark(name: "Bench", coordinate: here, date: t0 + 60)
        let merged = contents([older]).merged(with: contents([newer]))
        #expect(merged.marks == [newer, older])
    }

    @Test func theLaterRenameWins() {
        let mark = Mark(name: "Mark 1", coordinate: here, date: t0)
        var renamed = mark
        renamed.name = "Car"
        renamed.changed = t0 + 60
        #expect(contents([mark]).merged(with: contents([renamed])).marks == [renamed])
        #expect(contents([renamed]).merged(with: contents([mark])).marks == [renamed])
    }

    @Test func aDeletionCarriesOverUnlessTheMarkChangedSince() {
        let mark = Mark(name: "Car", coordinate: here, date: t0)
        let deletion = contents([], deleted: [mark.id: t0 + 60])
        #expect(contents([mark]).merged(with: deletion).marks.isEmpty)
        var renamedLater = mark
        renamedLater.changed = t0 + 120
        #expect(contents([renamedLater]).merged(with: deletion).marks == [renamedLater])
    }

    @Test func oldDeletionsAreForgotten() {
        let id = UUID()
        let deletion = contents([], deleted: [id: t0])
        let later = t0 + MarkStore.Contents.deletionMemory + 1
        #expect(deletion.merged(with: MarkStore.Contents(), at: later).deleted.isEmpty)
    }

    @Test func receiveSaysWhetherTheOtherDeviceIsMissingSomething() {
        let store = MarkStore(store: Store(url: temporaryURL()))
        let mine = store.add(here)
        let theirs = Mark(name: "Car", coordinate: here, date: t0)
        #expect(store.receive(contents([theirs])))
        #expect(store.marks.map(\.id) == [mine.id, theirs.id])
        #expect(!store.receive(store.contents))
    }

    @Test func localChangesAreAnnounced() {
        let store = MarkStore(store: Store(url: temporaryURL()))
        var announced = 0
        store.onChange = { announced += 1 }
        let mark = store.add(here)
        store.rename(mark.id, to: "Car")
        store.delete(mark.id)
        #expect(announced == 3)
        #expect(store.contents.deleted[mark.id] != nil)
    }

    @Test func aFileWithoutDeletionsStillLoads() throws {
        let url = temporaryURL()
        let mark = Mark(name: "Car", coordinate: here, date: t0)
        let json = try JSONEncoder().encode(["marks": [mark]])
        try json.write(to: url)
        #expect(MarkStore(store: Store(url: url)).marks == [mark])
    }
}

@MainActor
struct MarkStoreTests {
    let url = temporaryURL()
    let here = Coordinate(latitude: 29.75, longitude: -95.37)

    @Test func numberingCarriesOnPastTheHighest() {
        let store = MarkStore(store: Store(url: url))
        let first = store.add(here)
        let second = store.add(here)
        let third = store.add(here)
        #expect([first.name, second.name, third.name] == ["Mark 1", "Mark 2", "Mark 3"])
        store.delete(first.id)
        #expect(store.add(here).name == "Mark 4")
        store.delete(third.id)
        #expect(store.add(here).name == "Mark 5")
    }

    @Test func deletingEveryNumberedMarkStartsAgainAtOne() {
        let store = MarkStore(store: Store(url: url))
        let first = store.add(here)
        let second = store.add(here)
        store.delete(first.id)
        store.delete(second.id)
        #expect(store.add(here).name == "Mark 1")
    }

    @Test func renamingEveryNumberedMarkStartsAgainAtOne() {
        let store = MarkStore(store: Store(url: url))
        let first = store.add(here)
        let second = store.add(here)
        store.rename(first.id, to: "Car")
        #expect(store.add(here).name == "Mark 3")
        store.rename(second.id, to: "Trailhead")
        store.rename(store.marks[0].id, to: "Bench")
        #expect(store.add(here).name == "Mark 1")
    }

    @Test func onlyExactDefaultNamesCount() {
        let store = MarkStore(store: Store(url: url))
        let mark = store.add(here)
        store.rename(mark.id, to: "Mark 7b")
        #expect(store.add(here).name == "Mark 1")
        let other = store.add(here)
        store.rename(other.id, to: "Mark 9")
        #expect(store.add(here).name == "Mark 10")
    }

    @Test func enteredPointBecomesAMarkOnce() {
        let store = MarkStore(store: Store(url: url))
        let entered = Coordinate(latitude: 29.76, longitude: -95.36)
        let first = store.mark(at: entered)
        #expect(first.name == "Mark 1")
        #expect(store.mark(at: entered).id == first.id)
        #expect(store.marks.count == 1)
        #expect(store.mark(at: here).name == "Mark 2")
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
