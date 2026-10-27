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
    var reading: WidgetState.Reading?
    var distance: String?
    var units = Units.localeDefault
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
        return StatusEntry(date: now, goal: state.goal, reading: state.goal == nil ? nil : state.reading,
                           distance: await distance(state, at: now).map(state.units.format(meters:)), units: state.units)
    }

    @MainActor
    private func distance(_ state: WidgetState, at now: Date) async -> Double? {
        guard let start = state.trackingStart else { return nil }
        if let distance = state.trackedDistance { return Pedometers.shown(distance) }
        return Pedometers.shown(try? await Pedometers.make().distance(from: start, to: state.trackingEnd ?? now))
    }
}

struct StatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Status", provider: StatusProvider()) { entry in
            StatusWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Peilung")
        .description("Where you are navigating to, where you stood against it, and the distance tracked.")
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
            if let label = shortText ?? entry.distance {
                symbolImage.font(.title2).widgetLabel(label)
            } else {
                symbolImage.font(.title2)
            }
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                if let goal = entry.goal {
                    Text(goal)
                        .font(.headline)
                        .foregroundStyle(Self.amber)
                        .lineLimit(1)
                }
                if let reading = entry.reading {
                    Text(longText(reading))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("\(Text(reading.date, style: .relative)) ago")
                        .foregroundStyle(.secondary)
                } else if entry.goal == nil && entry.distance == nil {
                    Label("Not navigating or tracking distance", systemImage: Self.symbol)
                }
                if let distance = entry.distance, entry.reading == nil {
                    Text(distance + " tracked")
                }
            }
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
            if let reading = entry.reading, let shortText {
                Text("\(Image(systemName: symbol(reading))) \(shortText), \(Text(reading.date, style: .relative)) ago")
            } else if let text = entry.goal ?? entry.distance.map({ $0 + " tracked" }) {
                Label(text, systemImage: Self.symbol)
            } else {
                Image(systemName: Self.symbol)
            }
        default:
            ZStack {
                if renderingMode == .fullColor {
                    Circle().fill(Self.slate)
                } else {
                    AccessoryWidgetBackground()
                }
                if let reading = entry.reading {
                    VStack(spacing: 0) {
                        symbolImage.font(.body)
                        if let amount = amount(reading) {
                            Text(amount)
                                .font(.caption2.monospacedDigit())
                                .minimumScaleFactor(0.6)
                        }
                    }
                    .padding(4)
                } else {
                    symbolImage.font(.title3)
                }
            }
        }
    }

    private var symbolImage: some View {
        Image(systemName: entry.reading.map(symbol) ?? Self.symbol)
            .foregroundStyle(renderingMode == .fullColor ? Self.amber : .primary)
    }

    private func symbol(_ reading: WidgetState.Reading) -> String {
        switch reading.kind {
        case .line(let across, _): across == 0 ? "checkmark" : across > 0 ? "arrow.right" : "arrow.left"
        case .point: "scope"
        }
    }

    private func amount(_ reading: WidgetState.Reading) -> String? {
        switch reading.kind {
        case .line(let across, _): across == 0 ? nil : entry.units.rough(abs(across))
        case .point(let distance, _): entry.units.format(meters: distance)
        }
    }

    private var shortText: String? {
        entry.reading.map { reading in
            switch reading.kind {
            case .line(let across, _): entry.units.side(across)
            case .point(let distance, _): entry.units.format(meters: distance)
            }
        }
    }

    private func longText(_ reading: WidgetState.Reading) -> String {
        switch reading.kind {
        case .line(let across, let along): entry.units.side(across) + " · " + entry.units.progress(along)
        case .point(let distance, let bearing): entry.units.format(meters: distance) + " · " + bearing
        }
    }

    // The app icon's colors.
    private static let amber = Color(red: 0xF5 / 255, green: 0xA6 / 255, blue: 0x2E / 255)
    private static let slate = Color(red: 0x1E / 255, green: 0x2B / 255, blue: 0x33 / 255)
}
