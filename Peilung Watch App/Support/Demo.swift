// Demo.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

#if DEBUG
import CoreLocation
import Foundation

/// Debug launch arguments for screenshots and simulator checks, which cannot answer
/// the location prompt:
///
///     --demo odometer|here|navigate|bearing|marks   fixed position and compass, a running
///                                                   odometer, marks, and a point or bearing goal
///     --entry coordinates|bearing                   also opens that entry sheet on Navigate
enum Demo {
    static let here = Coordinate(latitude: 29.75205, longitude: -95.3742667)

    private static func argument(after flag: String) -> String? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    private static var scene: String? { argument(after: "--demo") }

    static var page: Page? {
        switch scene {
        case "odometer": .odometer
        case "here": .here
        case "navigate", "bearing": .navigate
        case "marks": .marks
        default: nil
        }
    }

    static var entry: NavigateView.Entry? {
        switch argument(after: "--entry") {
        case "coordinates": .coordinates
        case "bearing": .bearing
        default: nil
        }
    }

    /// Writes the demo's saved state; runs before the models load it.
    static func prepareStores(odometer: Store<OdometerState>, marks: Store<MarkStore.Contents>, goal: Store<Goal>) {
        let now = Date.now
        var state = OdometerState()
        state.start(at: now.addingTimeInterval(-47 * 60), from: offset(north: -1650, east: -2400))
        odometer.save(state)

        let named: [(String, Double, Double, TimeInterval)] = [
            ("GC7XQ2M", 140, 190, 6 * 60),
            ("Car", -1650, -2400, 52 * 60),
            ("Trailhead bench", -1400, -2050, 49 * 60),
        ]
        var contents = MarkStore.Contents()
        for (name, north, east, age) in named {
            contents.marks.append(Mark(name: name, coordinate: offset(north: north, east: east), date: now.addingTimeInterval(-age)))
        }
        contents.nextNumber = 4
        marks.save(contents)

        if scene == "bearing" {
            // Taken 220 m back along 074° true; here is now 14 m left of the line.
            goal.save(.bearing(BearingLine(bearing: 74, origin: offset(north: -74.1, east: -207.6))))
        } else {
            goal.save(.point(Target(name: "GC7XQ2M", coordinate: offset(north: 140, east: 190))))
        }
    }

    @MainActor
    static func apply(location: LocationModel, navigator: Navigator, page: Page) {
        let fix = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: here.latitude, longitude: here.longitude),
            altitude: 15, horizontalAccuracy: 4, verticalAccuracy: 6,
            timestamp: .distantFuture
        )
        location.simulate(fix, heading: scene == "bearing" ? 71 : 20, declination: 2, accuracy: 8)
        navigator.page = page
    }

    private static func offset(north: Double, east: Double) -> Coordinate {
        let metersPerDegree = 111_320.0
        return Coordinate(
            latitude: here.latitude + north / metersPerDegree,
            longitude: here.longitude + east / (metersPerDegree * cos(here.latitude * .pi / 180))
        )
    }
}
#endif
