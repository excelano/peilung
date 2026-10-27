// WidgetState.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// What the watch app leaves in the App Group for the widget: the goal as Navigate
/// titles it, and the odometer's run, whose distance the widget asks the pedometer for.
struct WidgetState: Codable, Equatable {
    var goal: String?
    var reading: Reading?
    var trackingStart: Date?
    var trackingEnd: Date?
    /// The distance at Stop, once the pedometer has settled it.
    var trackedDistance: Double?
    var units: Units

    var isTracking: Bool { trackingStart != nil && trackingEnd == nil }

    static var store: Store<WidgetState> { Store(name: "widget", in: AppGroup.applicationSupport) }

    struct Reading: Codable, Equatable {
        enum Kind: Codable, Equatable {
            case line(across: Double, along: Double)
            case point(distance: Double, bearing: String)
        }

        var kind: Kind
        var date: Date
    }
}
