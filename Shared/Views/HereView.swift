// HereView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import CoreLocation
import SwiftUI

struct HereView: View {
    @Environment(LocationModel.self) private var location
    @Environment(MarkStore.self) private var marks
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @State private var savedName: String?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            content(at: context.date)
        }
        .navigationTitle("Here")
    }

    /// An old fix stays on screen, dimmed and dated, until a fresh one arrives;
    /// only a fresh one can be marked. GPS stops while the screen is dimmed, so the
    /// dimmed page shows the last fix without a date.
    @ViewBuilder
    private func content(at now: Date) -> some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            if let fix = location.location {
                let isFresh = !isLuminanceReduced && LocationModel.isFresh(fix.timestamp, at: now)
                VStack(alignment: .leading, spacing: 6) {
                    CoordinateText(coordinate: Coordinate(fix.coordinate))
                        .foregroundStyle(isFresh ? .primary : .secondary)
                    if isFresh {
                        Text("±\(Int(fix.horizontalAccuracy.rounded())) m")
                            .font(.footnote)
                            .foregroundStyle(accuracyColor(fix.horizontalAccuracy))
                    } else if !isLuminanceReduced {
                        Text("Updating · " + Elapsed.age(now.timeIntervalSince(fix.timestamp)))
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
                if !isLuminanceReduced {
                    markButton(fix)
                        .disabled(!isFresh)
                }
            } else {
                LocationStatusView()
                Spacer(minLength: 0)
            }
        }
    }

    private func markButton(_ fix: CLLocation) -> some View {
        Button {
            let mark = marks.add(Coordinate(fix.coordinate))
            Haptics.play(.success)
            savedName = mark.name
        } label: {
            Text(savedName.map { "Saved \($0)" } ?? "Mark")
        }
        .actionButton()
        .task(id: savedName) {
            guard savedName != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            savedName = nil
        }
    }

    private func accuracyColor(_ accuracy: CLLocationAccuracy) -> Color {
        switch accuracy {
        case ..<10: .green
        case ..<30: .yellow
        default: .red
        }
    }
}

/// Two monospaced DDM lines, the latitude's two-digit degrees padded so the degree
/// signs line up with the longitude's three.
struct CoordinateText: View {
    let coordinate: Coordinate

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            line(coordinate.latitudeText.prefix(1) + " " + coordinate.latitudeText.dropFirst())
            line(coordinate.longitudeText)
        }
    }

    private func line(_ text: String) -> some View {
        Text(text)
            .font(.system(.title3, design: .monospaced).weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}

/// Shown while there is no fix: denied, failed, or still waiting.
struct LocationStatusView: View {
    @Environment(LocationModel.self) private var location

    var body: some View {
        if location.isDenied {
            message(Device.allow("Location"))
        } else if let error = location.errorText {
            message(error)
        } else {
            ProgressView("Getting fix…")
        }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.orange)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}
