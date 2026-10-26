// StatusWidget.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI
import WidgetKit

@main
struct PeilungWidgets: WidgetBundle {
    var body: some Widget {
        StatusWidget()
    }
}

struct StatusEntry: TimelineEntry {
    let date: Date
    var goal: String?
    var distance: String?
}

/// Reads what the watch app left in the App Group; a running odometer's distance comes
/// from the pedometer, which keeps counting while the app is closed.
struct StatusProvider: TimelineProvider {
    /// How often a running odometer's distance is refreshed.
    static let refresh: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> StatusEntry {
        StatusEntry(date: .now)
    }

    // WidgetKit's completion handlers are not Sendable, but it accepts them on any thread.
    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        nonisolated(unsafe) let completion = completion
        Task { @MainActor in completion(await entry(WidgetState.store.load(), at: .now)) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        nonisolated(unsafe) let completion = completion
        Task { @MainActor in
            let now = Date.now
            let state = WidgetState.store.load()
            completion(Timeline(entries: [await entry(state, at: now)],
                                policy: state?.isTracking == true ? .after(now.addingTimeInterval(Self.refresh)) : .never))
        }
    }

    @MainActor
    private func entry(_ state: WidgetState?, at now: Date) async -> StatusEntry {
        guard let state else { return StatusEntry(date: now) }
        return StatusEntry(date: now, goal: state.goal, distance: await distance(state, at: now).map(state.units.format(meters:)))
    }

    @MainActor
    private func distance(_ state: WidgetState, at now: Date) async -> Double? {
        guard let start = state.trackingStart else { return nil }
        if let distance = state.trackedDistance { return distance }
        return try? await Pedometers.make().distance(from: start, to: state.trackingEnd ?? now)
    }
}

struct StatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Status", provider: StatusProvider()) { entry in
            StatusWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Peilung")
        .description("Where you are navigating to, and the distance tracked.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

struct StatusWidgetView: View {
    let entry: StatusEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    private static let symbol = "location.north.fill"

    var body: some View {
        switch family {
        case .accessoryCorner:
            Image(systemName: Self.symbol)
                .font(.title2)
                .foregroundStyle(Self.amber)
                .widgetLabel("Peilung")
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Label("Peilung", systemImage: Self.symbol)
                    .font(.headline)
                    .foregroundStyle(Self.amber)
                if entry.goal == nil && entry.distance == nil {
                    Text("Not navigating or tracking distance")
                } else {
                    if let goal = entry.goal {
                        Text(goal).lineLimit(1)
                    }
                    if let distance = entry.distance {
                        Text(distance + " tracked")
                    }
                }
            }
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
            Label("Peilung", systemImage: Self.symbol)
        default:
            ZStack {
                if renderingMode == .fullColor {
                    Circle().fill(Self.slate)
                } else {
                    AccessoryWidgetBackground()
                }
                Image(systemName: Self.symbol)
                    .font(.title3)
                    .foregroundStyle(renderingMode == .fullColor ? Self.amber : .primary)
            }
        }
    }

    // The app icon's colors.
    private static let amber = Color(red: 0xF5 / 255, green: 0xA6 / 255, blue: 0x2E / 255)
    private static let slate = Color(red: 0x1E / 255, green: 0x2B / 255, blue: 0x33 / 255)
}
