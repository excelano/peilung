// OdometerState.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// The persisted part of the odometer: when it started, where, and when it stopped.
struct OdometerState: Codable, Equatable {
    /// A fix arriving this long after Start can still become the start position.
    static let startFixWindow: TimeInterval = 60
    /// How far back the watch keeps pedometer history.
    static let historyLimit: TimeInterval = 7 * 24 * 3600

    private(set) var startDate: Date?
    private(set) var endDate: Date?
    private(set) var startCoordinate: Coordinate?
    /// The distance at Stop, so a stopped reading needs no further pedometer queries.
    var finalDistance: Double?

    enum Phase { case idle, running, stopped }

    var phase: Phase {
        if startDate == nil { return .idle }
        return endDate == nil ? .running : .stopped
    }

    mutating func start(at date: Date, from coordinate: Coordinate?) {
        self = OdometerState(startDate: date, startCoordinate: coordinate)
    }

    mutating func stop(at date: Date) {
        guard phase == .running else { return }
        endDate = date
    }

    mutating func reset() {
        self = OdometerState()
    }

    mutating func adopt(_ run: OdometerState) {
        let distance = run.startDate == startDate && run.endDate == endDate ? finalDistance : nil
        self = run
        finalDistance = distance
    }

    /// Records `coordinate` as the start position if none was available at Start and
    /// the run is still young enough for it to be close to where Start was pressed.
    mutating func offerStartFix(_ coordinate: Coordinate, at date: Date) {
        guard phase == .running, startCoordinate == nil, let startDate,
              date.timeIntervalSince(startDate) <= Self.startFixWindow else { return }
        startCoordinate = coordinate
    }

    func elapsed(at now: Date) -> TimeInterval {
        guard let startDate else { return 0 }
        return (endDate ?? now).timeIntervalSince(startDate)
    }

    func exceedsHistory(at now: Date) -> Bool {
        guard let startDate else { return false }
        return now.timeIntervalSince(startDate) > Self.historyLimit
    }
}
