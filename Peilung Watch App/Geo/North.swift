// North.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// Which north bearings are shown and entered against. Orienteering maps are drawn
/// to magnetic north, so a bearing measured off one is magnetic.
enum NorthReference: String, CaseIterable, Identifiable {
    case magnetic, `true`

    var id: Self { self }

    static let storageKey = "north"

    var label: String {
        switch self {
        case .magnetic: "Magnetic"
        case .true: "True"
        }
    }
}

/// Converts between the true bearings used internally and the bearings shown.
/// Magnetic needs the declination from the compass; until it is known, bearings
/// are shown as true and labelled so.
struct North: Equatable {
    let isMagnetic: Bool
    let declination: Double

    init(_ reference: NorthReference, declination: Double?) {
        isMagnetic = reference == .magnetic && declination != nil
        self.declination = isMagnetic ? declination ?? 0 : 0
    }

    var suffix: String { isMagnetic ? "M" : "T" }

    func shown(_ trueBearing: Double) -> Double {
        Compass.normalized(trueBearing - declination)
    }

    func trueBearing(_ shownBearing: Double) -> Double {
        Compass.normalized(shownBearing + declination)
    }

    /// "054° M"
    func text(_ trueBearing: Double) -> String {
        Self.degrees(shown(trueBearing)) + " " + suffix
    }

    /// "054°", rounded to a whole degree with 360 shown as 000.
    static func degrees(_ value: Double) -> String {
        String(format: "%03d°", Int(value.rounded()) % 360)
    }
}
