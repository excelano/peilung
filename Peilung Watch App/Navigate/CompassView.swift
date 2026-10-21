// CompassView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// A ring with its north mark at `north` degrees and a marker at `arrow` degrees,
/// both clockwise from the top of the screen. No arrow means no usable direction.
struct CompassView: View {
    enum Marker: Equatable {
        case arrow(onCourse: Bool)
        /// The plain compass: a fixed mark at 12 o'clock to read the heading against.
        case index
        /// At the target, where direction no longer means anything.
        case scope
    }

    let arrow: Double?
    let north: Double
    let marker: Marker

    /// Readings after the first turn the marks; the first places them, so opening the page does not spin it.
    private static let turn = Animation.easeOut(duration: 0.25)

    @State private var shownArrow = 0.0
    @State private var shownNorth = 0.0

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.5), lineWidth: 2)
                ForEach([90.0, 180, 270], id: \.self) { quarter in
                    Capsule()
                        .fill(.secondary)
                        .frame(width: 2, height: size * 0.09)
                        .offset(y: -size * 0.455)
                        .rotationEffect(.degrees(shownNorth + quarter))
                }
                Text("N")
                    .font(.system(size: size * 0.14, weight: .bold))
                    .foregroundStyle(.red)
                    .offset(y: -size * 0.38)
                    .rotationEffect(.degrees(shownNorth))
                switch marker {
                case .index:
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: size * 0.11))
                        .foregroundStyle(.tint)
                        .offset(y: -size * 0.5)
                case .scope:
                    Image(systemName: "scope")
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(.green)
                case .arrow(let onCourse):
                    if arrow != nil {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: size * 0.45))
                            .foregroundStyle(onCourse ? AnyShapeStyle(.green) : AnyShapeStyle(.tint))
                            .rotationEffect(.degrees(shownArrow))
                    }
                }
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: arrow, initial: true) { old, new in
            guard let new else { return }
            withAnimation(old == nil || old == new ? nil : Self.turn) { shownArrow = Compass.unwrapped(new, from: shownArrow) }
        }
        .onChange(of: north, initial: true) { old, new in
            withAnimation(old == new ? nil : Self.turn) { shownNorth = Compass.unwrapped(new, from: shownNorth) }
        }
        .accessibilityHidden(true)
    }
}
