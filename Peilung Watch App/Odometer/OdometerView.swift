// OdometerView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct OdometerView: View {
    @Environment(OdometerModel.self) private var odometer
    @Environment(LocationModel.self) private var location
    @Environment(Navigator.self) private var navigator
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @AppStorage(Units.storageKey) private var units = Units.localeDefault

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 6) {
                reading(at: context.date)
                if !isLuminanceReduced {
                    Spacer(minLength: 0)
                    controls
                }
            }
        }
        .navigationTitle("Odometer")
    }

    @ViewBuilder
    private func reading(at now: Date) -> some View {
        let state = odometer.state
        VStack(spacing: 2) {
            Text(odometer.distance.map(units.format(meters:)) ?? "—")
                .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(state.phase == .idle ? .secondary : .primary)
            switch state.phase {
            case .idle:
                Text("Walk, then check back.").font(.footnote).foregroundStyle(.secondary)
            case .running where isLuminanceReduced:
                if let start = state.startDate {
                    Text("since \(start.formatted(date: .omitted, time: .shortened))")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            case .running, .stopped:
                Text(Elapsed.format(state.elapsed(at: now)))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(state.phase == .stopped ? .secondary : .primary)
                if !isLuminanceReduced { backToStart }
            }
            if let message = odometer.message(at: now) {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    @ViewBuilder
    private var backToStart: some View {
        if let start = odometer.state.startCoordinate, let here = location.freshLocation() {
            Button {
                navigator.navigate(to: Target(name: "Start", coordinate: start))
            } label: {
                Label(units.format(meters: Coordinate(here.coordinate).distance(to: start)) + " to start",
                      systemImage: "arrow.uturn.backward")
                    .font(.footnote)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch odometer.state.phase {
        case .idle:
            Button("Start") {
                odometer.start(from: location.freshLocation().map { Coordinate($0.coordinate) })
                Haptics.play(.start)
            }
            .tint(.green)
            .disabled(!odometer.isAvailable || odometer.isDenied)
        case .running:
            Button("Stop") {
                odometer.stop()
                Haptics.play(.stop)
            }
            .tint(.red)
        case .stopped:
            Button("Reset") {
                odometer.reset()
                Haptics.play(.click)
            }
        }
    }
}
