// CompassView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// A ring with its north mark at `north` degrees and an arrow at `arrow` degrees,
/// both clockwise from the top of the screen. No arrow means no usable direction.
struct CompassView: View {
    let arrow: Double?
    let north: Double
    let isNear: Bool

    @State private var shownArrow = 0.0
    @State private var shownNorth = 0.0

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.5), lineWidth: 2)
                Text("N")
                    .font(.system(size: size * 0.14, weight: .bold))
                    .foregroundStyle(.red)
                    .offset(y: -size * 0.38)
                    .rotationEffect(.degrees(shownNorth))
                if isNear {
                    Image(systemName: "scope")
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(.green)
                } else if arrow != nil {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: size * 0.45))
                        .foregroundStyle(.tint)
                        .rotationEffect(.degrees(shownArrow))
                }
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: arrow, initial: true) {
            guard let arrow else { return }
            withAnimation(.easeOut(duration: 0.25)) { shownArrow = Compass.unwrapped(arrow, from: shownArrow) }
        }
        .onChange(of: north, initial: true) {
            withAnimation(.easeOut(duration: 0.25)) { shownNorth = Compass.unwrapped(north, from: shownNorth) }
        }
        .accessibilityHidden(true)
    }
}
