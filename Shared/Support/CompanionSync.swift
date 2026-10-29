// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import os
import WatchConnectivity

private let log = Logger(subsystem: "com.excelano.peilung", category: "sync")

private enum ContextKey {
    static let goal = "goal"
    static let goalChanged = "goalChanged"
    static let settings = "settings"
    static let settingsChanged = "settingsChanged"
    static let odometer = "odometer"
    static let odometerChanged = "odometerChanged"
    static let marks = "marks"
}

private struct Received: Sendable {
    var goal: (Goal?, Date)?
    var settings: ([String: String], Date)?
    var odometer: (OdometerState, Date)?
    var marks: MarkStore.Contents?
}

@MainActor
final class CompanionSync: NSObject, WCSessionDelegate {
    static let settingsKeys = [Units.storageKey, NorthReference.storageKey, CoordinateFormat.storageKey]
    static let settingsChangedKey = "settingsChanged"

    private let navigator: Navigator
    private let odometer: OdometerModel
    private let marks: MarkStore
    private let defaults: UserDefaults
    private var settings: [String: String]
    private var settingsChanged: Date?

    init(navigator: Navigator, odometer: OdometerModel, marks: MarkStore, defaults: UserDefaults = .standard) {
        self.navigator = navigator
        self.odometer = odometer
        self.marks = marks
        self.defaults = defaults
        settings = Self.settings(in: defaults)
        settingsChanged = defaults.object(forKey: Self.settingsChangedKey) as? Date
    }

    func start() {
        guard WCSession.isSupported() else { return }
        navigator.onChange = { [weak self] in self?.send() }
        odometer.onChange = { [weak self] in self?.send() }
        marks.onChange = { [weak self] in self?.send() }
        _ = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: defaults,
                                                   queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.settingsDidChange() }
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private static func settings(in defaults: UserDefaults) -> [String: String] {
        settingsKeys.reduce(into: [:]) { settings, key in settings[key] = defaults.string(forKey: key) }
    }

    private func settingsDidChange() {
        let current = Self.settings(in: defaults)
        guard current != settings else { return }
        settings = current
        settingsChanged = .now
        defaults.set(settingsChanged, forKey: Self.settingsChangedKey)
        send()
    }

    private func receiveSettings(_ received: [String: String], changed: Date) {
        guard changed > settingsChanged ?? .distantPast else { return }
        settingsChanged = changed
        defaults.set(changed, forKey: Self.settingsChangedKey)
        for (key, value) in received where Self.settingsKeys.contains(key) {
            defaults.set(value, forKey: key)
        }
        settings = Self.settings(in: defaults)
    }

    private func apply(_ received: Received) {
        if let (goal, changed) = received.goal {
            navigator.receive(goal, changed: changed)
        }
        if let (settings, changed) = received.settings {
            receiveSettings(settings, changed: changed)
        }
        if let (run, changed) = received.odometer {
            odometer.receive(run, changed: changed)
        }
        if let contents = received.marks, marks.receive(contents) {
            send()
        }
    }

    private func send() {
        let session = WCSession.default
        guard session.activationState == .activated, session.isCounterpartInstalled else { return }
        var context: [String: Any] = [:]
        if let changed = navigator.goalChanged {
            context[ContextKey.goalChanged] = changed
            if let goal = navigator.goal {
                context[ContextKey.goal] = try? JSONEncoder().encode(goal)
            }
        }
        if let settingsChanged {
            context[ContextKey.settingsChanged] = settingsChanged
            context[ContextKey.settings] = settings
        }
        if let changed = odometer.changed {
            context[ContextKey.odometerChanged] = changed
            context[ContextKey.odometer] = try? JSONEncoder().encode(odometer.run)
        }
        context[ContextKey.marks] = try? JSONEncoder().encode(marks.contents)
        do {
            try session.updateApplicationContext(context)
        } catch {
            log.error("Sending to the paired device failed: \(error, privacy: .public)")
        }
    }

    private nonisolated static func received(from context: [String: Any]) -> Received {
        var received = Received()
        if let changed = context[ContextKey.goalChanged] as? Date {
            if let data = context[ContextKey.goal] as? Data {
                received.goal = (try? JSONDecoder().decode(Goal.self, from: data)).map { ($0, changed) }
            } else {
                received.goal = (nil, changed)
            }
        }
        if let changed = context[ContextKey.settingsChanged] as? Date,
           let settings = context[ContextKey.settings] as? [String: String] {
            received.settings = (settings, changed)
        }
        if let changed = context[ContextKey.odometerChanged] as? Date,
           let data = context[ContextKey.odometer] as? Data,
           let run = try? JSONDecoder().decode(OdometerState.self, from: data) {
            received.odometer = (run, changed)
        }
        if let data = context[ContextKey.marks] as? Data {
            received.marks = try? JSONDecoder().decode(MarkStore.Contents.self, from: data)
        }
        return received
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if let error {
            log.error("Activating the session failed: \(error, privacy: .public)")
        }
        let received = Self.received(from: session.receivedApplicationContext)
        Task { @MainActor in
            apply(received)
            send()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        let received = Self.received(from: context)
        Task { @MainActor in apply(received) }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in send() }
    }
    #endif
}

private extension WCSession {
    var isCounterpartInstalled: Bool {
        #if os(iOS)
        isPaired && isWatchAppInstalled
        #else
        isCompanionAppInstalled
        #endif
    }
}
