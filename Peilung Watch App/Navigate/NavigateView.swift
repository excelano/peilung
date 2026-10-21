// NavigateView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct NavigateView: View {
    @Environment(LocationModel.self) private var location
    @Environment(Navigator.self) private var navigator
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @AppStorage(Units.storageKey) private var units = Units.localeDefault
    @AppStorage(NorthReference.storageKey) private var reference = NorthReference.magnetic
    @State private var entry: Entry?
    @State private var hold = BearingHold()
    @State private var isConfirmingStop = false

    enum Entry: Identifiable {
        case coordinates, bearing
        var id: Self { self }
    }

    private var north: North { North(reference, declination: location.declination) }

    var body: some View {
        Group {
            switch navigator.goal {
            case .point(let target):
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    pointGuidance(to: target, at: context.date)
                }
            case .bearing(let line):
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    bearingGuidance(along: line, at: context.date)
                }
            case nil:
                compass
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Bearing", systemImage: "location.north.line") { entry = .bearing }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Coordinates", systemImage: "pencil") { entry = .coordinates }
            }
        }
        .sheet(item: $entry) { kind in
            switch kind {
            case .coordinates:
                TargetEntryView(start: location.coordinate ?? navigator.goalCoordinate ?? Coordinate(latitude: 0, longitude: 0)) {
                    navigator.navigate(to: Target(name: "Target", coordinate: $0))
                    entry = nil
                }
            case .bearing:
                BearingEntryView {
                    hold = BearingHold()
                    navigator.follow($0)
                    entry = nil
                }
            }
        }
        .confirmationDialog("Stop navigating?", isPresented: $isConfirmingStop) {
            Button("Stop", role: .destructive) { navigator.clear() }
        }
        .onChange(of: location.heading) { cueDrift() }
        .onAppear {
            cueDrift()
            #if DEBUG
            entry = Demo.entry
            #endif
        }
    }

    /// With nowhere to go, a plain compass: the arrow is where the watch points.
    private var compass: some View {
        VStack(spacing: 2) {
            if !isLuminanceReduced {
                CompassView(
                    arrow: location.heading == nil ? nil : 0,
                    north: -(location.heading ?? 0),
                    marker: .arrow(onCourse: false)
                )
                .frame(maxHeight: .infinity)
            }
            Text(location.heading.map(north.text) ?? "No compass")
                .font(.system(.title2, design: .rounded).weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let warning = CompassWarning.text(location.headingAccuracy) {
                compassWarning(warning)
            }
        }
    }

    /// The goal's name; tapping it offers to stop navigating.
    private func goalTitle(_ title: String) -> some View {
        Button {
            isConfirmingStop = true
        } label: {
            HStack(spacing: 3) {
                Text(title).lineLimit(1)
                Image(systemName: "xmark.circle.fill")
            }
            .font(.footnote.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private func compassWarning(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.orange)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
    }

    @ViewBuilder
    private func pointGuidance(to target: Target, at now: Date) -> some View {
        let here = location.freshLocation(at: now).map { Coordinate($0.coordinate) }
        let distance = here?.distance(to: target.coordinate)
        let bearing = here?.bearing(to: target.coordinate)
        let isNear = distance.map { $0 < Compass.nearTargetMeters } ?? false

        VStack(spacing: 2) {
            goalTitle(target.name)
            if !isLuminanceReduced {
                CompassView(
                    arrow: isNear ? nil : bearing.map { $0 - (location.heading ?? 0) },
                    north: -(location.heading ?? 0),
                    marker: isNear ? .scope : .arrow(onCourse: false)
                )
                .frame(maxHeight: .infinity)
            }
            if let distance, let bearing {
                Text(isNear ? "Near target" : units.format(meters: distance))
                    .font(.system(.title2, design: .rounded).weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(isNear ? units.format(meters: distance) : north.text(bearing) + (location.heading == nil ? " · north up" : ""))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else if location.location == nil {
                LocationStatusView()
            } else {
                Text("Waiting for a fresh fix…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func bearingGuidance(along line: BearingLine, at now: Date) -> some View {
        let deviation = location.heading.map { Compass.signed(line.bearing - $0) }
        let offset = location.freshLocation(at: now).flatMap { line.offset(of: Coordinate($0.coordinate)) }

        VStack(spacing: 2) {
            goalTitle("Bearing " + north.text(line.bearing))
            if !isLuminanceReduced {
                CompassView(
                    arrow: deviation ?? line.bearing,
                    north: -(location.heading ?? 0),
                    marker: .arrow(onCourse: deviation != nil && hold.isOn)
                )
                .frame(maxHeight: .infinity)
            }
            Group {
                if let deviation {
                    if hold.isOn {
                        Text("On bearing").foregroundStyle(.green)
                    } else {
                        Text("Turn \(Int(abs(deviation).rounded()))° \(deviation > 0 ? "right" : "left")")
                    }
                } else {
                    Text("No compass · north up")
                }
            }
            .font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            if let offset {
                Text(offsetText(offset))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            if let warning = CompassWarning.text(location.headingAccuracy) {
                compassWarning(warning)
            }
        }
    }

    /// "14 m left · 220 m along"
    private func offsetText(_ offset: (across: Double, along: Double)) -> String {
        let side = abs(offset.across) < 0.5 ? "on line" : units.format(meters: abs(offset.across)) + (offset.across > 0 ? " right" : " left")
        let progress = offset.along < 0 ? units.format(meters: -offset.along) + " behind" : units.format(meters: offset.along) + " along"
        return side + " · " + progress
    }

    private func cueDrift() {
        guard case .bearing(let line) = navigator.goal, let heading = location.heading else { return }
        switch hold.update(deviation: line.bearing - heading) {
        case .onBearing: Haptics.play(.success)
        case .turnLeft: Haptics.play(.navigationLeftTurn)
        case .turnRight: Haptics.play(.navigationRightTurn)
        case nil: break
        }
    }
}

extension Navigator {
    /// The point being navigated to, if the goal is a point.
    var goalCoordinate: Coordinate? {
        if case .point(let target) = goal { return target.coordinate }
        return nil
    }
}
