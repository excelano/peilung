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
    /// only a fresh one can be marked.
    @ViewBuilder
    private func content(at now: Date) -> some View {
        VStack(spacing: 6) {
            if let fix = location.location {
                let isFresh = LocationModel.isFresh(fix.timestamp, at: now, dimmed: isLuminanceReduced)
                VStack(alignment: .leading, spacing: 6) {
                    CoordinateText(coordinate: Coordinate(fix.coordinate))
                        .foregroundStyle(isFresh ? .primary : .secondary)
                    if isFresh {
                        Text("±\(Int(fix.horizontalAccuracy.rounded())) m")
                            .font(.footnote)
                            .foregroundStyle(accuracyColor(fix.horizontalAccuracy))
                    } else {
                        Text("Updating · " + Elapsed.age(now.timeIntervalSince(fix.timestamp)))
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !isLuminanceReduced {
                    Spacer(minLength: 0)
                    markButton(fix)
                        .disabled(!isFresh)
                }
            } else {
                LocationStatusView()
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

/// Two monospaced DDM lines.
struct CoordinateText: View {
    let coordinate: Coordinate

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            line(coordinate.latitudeText)
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
            Text("Location access denied. Enable it in Settings > Privacy.")
                .font(.footnote)
        } else if let error = location.errorText {
            Text(error).font(.footnote)
        } else {
            ProgressView("Getting fix…")
        }
    }
}
