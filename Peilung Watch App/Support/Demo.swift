// Demo.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

#if DEBUG
import CoreLocation
import Foundation

/// Debug launch arguments for screenshots and simulator checks, which cannot answer
/// the location prompt:
///
///     --demo odometer|here|navigate|marks   fixed position, a running odometer, marks and a target
///     --entry                               also opens the target entry sheet
enum Demo {
    static let here = Coordinate(latitude: 29.75205, longitude: -95.3742667)

    static var page: Page? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--demo"), index + 1 < arguments.count else { return nil }
        return switch arguments[index + 1] {
        case "odometer": .odometer
        case "here": .here
        case "navigate": .navigate
        case "marks": .marks
        default: nil
        }
    }

    static var opensEntry: Bool { CommandLine.arguments.contains("--entry") }

    /// Writes the demo's saved state; runs before the models load it.
    static func prepareStores(odometer: Store<OdometerState>, marks: Store<MarkStore.Contents>, target: Store<Target>) {
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

        target.save(Target(name: "GC7XQ2M", coordinate: offset(north: 140, east: 190)))
    }

    @MainActor
    static func apply(location: LocationModel, navigator: Navigator, page: Page) {
        let fix = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: here.latitude, longitude: here.longitude),
            altitude: 15, horizontalAccuracy: 4, verticalAccuracy: 6,
            timestamp: .distantFuture
        )
        location.simulate(fix, heading: 20)
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
