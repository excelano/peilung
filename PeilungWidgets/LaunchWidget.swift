// LaunchWidget.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI
import WidgetKit

@main
struct PeilungWidgets: WidgetBundle {
    var body: some Widget {
        LaunchWidget()
    }
}

struct LaunchEntry: TimelineEntry {
    let date: Date
}

/// Nothing on the complication changes, so the timeline is one entry that never expires.
struct LaunchProvider: TimelineProvider {
    func placeholder(in context: Context) -> LaunchEntry {
        LaunchEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (LaunchEntry) -> Void) {
        completion(LaunchEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LaunchEntry>) -> Void) {
        completion(Timeline(entries: [LaunchEntry(date: .now)], policy: .never))
    }
}

struct LaunchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Launch", provider: LaunchProvider()) { _ in
            LaunchWidgetView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Peilung")
        .description("Opens Peilung.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

struct LaunchWidgetView: View {
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
                Text("Compass, bearing, odometer")
                    .font(.footnote)
            }
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
