// NavigateView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct NavigateView: View {
    @Environment(LocationModel.self) private var location
    @Environment(Navigator.self) private var navigator
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @AppStorage(Units.storageKey) private var units = Units.localeDefault
    @State private var isEditing = false

    var body: some View {
        Group {
            if let target = navigator.target {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    guidance(to: target, at: context.date)
                }
            } else {
                noTarget
            }
        }
        .navigationTitle("Navigate")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit target", systemImage: "pencil") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            TargetEntryView(start: location.coordinate ?? navigator.target?.coordinate ?? Coordinate(latitude: 0, longitude: 0)) {
                navigator.navigate(to: Target(name: "Target", coordinate: $0))
                isEditing = false
            }
        }
        #if DEBUG
        .onAppear { if Demo.opensEntry { isEditing = true } }
        #endif
    }

    private var noTarget: some View {
        VStack(spacing: 8) {
            Text("No target").font(.headline)
            Text("Enter coordinates, or pick a mark.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Enter") { isEditing = true }
        }
    }

    @ViewBuilder
    private func guidance(to target: Target, at now: Date) -> some View {
        let here = location.freshLocation(at: now).map { Coordinate($0.coordinate) }
        let distance = here?.distance(to: target.coordinate)
        let bearing = here?.bearing(to: target.coordinate)
        let isNear = distance.map { $0 < Compass.nearTargetMeters } ?? false

        VStack(spacing: 2) {
            Text(target.name)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if !isLuminanceReduced {
                CompassView(
                    arrow: isNear ? nil : bearing.map { $0 - (location.heading ?? 0) },
                    north: -(location.heading ?? 0),
                    isNear: isNear
                )
                .frame(maxHeight: .infinity)
            }
            if let distance, let bearing {
                Text(isNear ? "Near target" : units.format(meters: distance))
                    .font(.system(.title2, design: .rounded).weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(isNear ? units.format(meters: distance) : "\(Int(bearing.rounded()) % 360)° \(Compass.point(bearing))" + (location.heading == nil ? " · north up" : ""))
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
}
