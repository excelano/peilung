// NavigateView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct NavigateView: View {
    @Environment(LocationModel.self) private var location
    @Environment(Navigator.self) private var navigator
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Units.storageKey) private var units = Units.localeDefault
    @AppStorage(NorthReference.storageKey) private var reference = NorthReference.magnetic
    @State private var entry: Entry?
    @State private var hold = BearingHold()
    @State private var arrival = Arrival()
    @State private var isConfirmingStop = false

    enum Entry: Identifiable {
        case coordinates, bearing
        var id: Self { self }
    }

    private var north: North { North(reference, declination: location.declination) }

    /// The heading as shown, which also turns the ring so its N is the chosen north.
    private var shownHeading: Double? { location.magneticHeading.map { north.shown(magnetic: $0) } }

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
                    navigator.follow($0)
                    entry = nil
                }
            }
        }
        .confirmationDialog("Stop navigating?", isPresented: $isConfirmingStop) {
            Button("Stop", role: .destructive) { navigator.clear() }
        }
        .onChange(of: navigator.goal) {
            hold = BearingHold()
            arrival = Arrival()
        }
        .onChange(of: location.magneticHeading) { cueDrift() }
        .onChange(of: location.location?.timestamp) { cueArrival() }
        .onChange(of: scenePhase) {
            cueDrift()
            cueArrival()
        }
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
                    arrow: shownHeading == nil ? nil : 0,
                    north: -(shownHeading ?? 0),
                    marker: .arrow(onCourse: false)
                )
                .frame(maxHeight: .infinity)
            }
            Text(location.magneticHeading.map { north.text(magnetic: $0) } ?? "No compass")
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
        let here = location.freshLocation(at: now, dimmed: isLuminanceReduced).map { Coordinate($0.coordinate) }
        let distance = here?.distance(to: target.coordinate)
        let bearing = here?.bearing(to: target.coordinate)
        let isNear = distance.map { $0 < Compass.nearTargetMeters } ?? false
        let trueHeading = location.magneticHeading.map { north.trueBearing(magnetic: $0) ?? $0 }

        VStack(spacing: 2) {
            goalTitle(target.name)
            if !isLuminanceReduced {
                CompassView(
                    arrow: isNear ? nil : bearing.map { $0 - (trueHeading ?? 0) },
                    north: -(shownHeading ?? 0),
                    marker: isNear ? .scope : .arrow(onCourse: false)
                )
                .frame(maxHeight: .infinity)
            }
            if let distance, let bearing {
                Text(isNear ? "Near target" : units.format(meters: distance))
                    .font(.system(.title2, design: .rounded).weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(isNear ? units.format(meters: distance) : north.text(true: bearing) + (trueHeading == nil ? " · north up" : ""))
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
        let deviation = location.magneticHeading.map { Compass.signed(line.magnetic - $0) }
        let offset = location.freshLocation(at: now, dimmed: isLuminanceReduced)
            .flatMap { line.offset(of: Coordinate($0.coordinate), declination: location.declination) }

        VStack(spacing: 2) {
            goalTitle("Bearing " + north.text(magnetic: line.magnetic))
            if !isLuminanceReduced {
                CompassView(
                    arrow: deviation ?? north.shown(magnetic: line.magnetic),
                    north: -(shownHeading ?? 0),
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
                Text(units.offset(offset))
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

    /// Cues tap only while the screen is up, so a swinging arm with the wrist down stays quiet.
    private var canCue: Bool { scenePhase == .active && !isLuminanceReduced }

    private func cueArrival() {
        guard canCue, case .point(let target) = navigator.goal, let fix = location.freshLocation() else { return }
        if arrival.update(distance: Coordinate(fix.coordinate).distance(to: target.coordinate)) {
            Haptics.play(.notification)
        }
    }

    private func cueDrift() {
        guard canCue, case .bearing(let line) = navigator.goal, let heading = location.magneticHeading else { return }
        switch hold.update(deviation: line.magnetic - heading) {
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
