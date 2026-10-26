// Pedometer.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import CoreMotion
import Foundation

/// Walking distance since a date. The simulator has no pedometer, so it gets a fake.
@MainActor
protocol Pedometer: AnyObject {
    var isAvailable: Bool { get }
    var isDenied: Bool { get }
    /// Calls `handler` on the main actor with the distance in meters since `start`.
    func startUpdates(from start: Date, handler: @escaping @MainActor (Result<Double, Error>) -> Void)
    func stopUpdates()
    func distance(from start: Date, to end: Date) async throws -> Double
}

enum Pedometers {
    @MainActor
    static func make() -> Pedometer {
        #if targetEnvironment(simulator)
        SimulatedPedometer()
        #else
        MotionPedometer()
        #endif
    }
}

@MainActor
final class MotionPedometer: Pedometer {
    private let pedometer = CMPedometer()

    var isAvailable: Bool { CMPedometer.isDistanceAvailable() }

    var isDenied: Bool {
        let status = CMPedometer.authorizationStatus()
        return status == .denied || status == .restricted
    }

    func startUpdates(from start: Date, handler: @escaping @MainActor (Result<Double, Error>) -> Void) {
        pedometer.stopUpdates()
        pedometer.startUpdates(from: start) { @Sendable data, error in
            let result = Self.result(data, error)
            Task { @MainActor in handler(result) }
        }
    }

    func stopUpdates() {
        pedometer.stopUpdates()
    }

    func distance(from start: Date, to end: Date) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            pedometer.queryPedometerData(from: start, to: end) { @Sendable data, error in
                continuation.resume(with: Self.result(data, error))
            }
        }
    }

    private nonisolated static func result(_ data: CMPedometerData?, _ error: Error?) -> Result<Double, Error> {
        if let error { return .failure(error) }
        return .success(data?.distance?.doubleValue ?? 0)
    }
}

/// Walks at a steady 1.3 m/s from the start date, ticking once a second.
@MainActor
final class SimulatedPedometer: Pedometer {
    private static let speed = 1.3
    private var timer: Timer?

    var isAvailable: Bool { true }
    var isDenied: Bool { false }

    func startUpdates(from start: Date, handler: @escaping @MainActor (Result<Double, Error>) -> Void) {
        stopUpdates()
        handler(.success(Date.now.timeIntervalSince(start) * Self.speed))
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in handler(.success(Date.now.timeIntervalSince(start) * Self.speed)) }
        }
    }

    func stopUpdates() {
        timer?.invalidate()
        timer = nil
    }

    func distance(from start: Date, to end: Date) async throws -> Double {
        end.timeIntervalSince(start) * Self.speed
    }
}
