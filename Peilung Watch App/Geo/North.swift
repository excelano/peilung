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

/// Shows bearings against the chosen north. The compass reads magnetic and GPS
/// bearings are true; the declination (true minus magnetic) converts between them.
/// Until it is known, a bearing is shown in its own north and labelled so.
struct North: Equatable {
    let reference: NorthReference
    let declination: Double?

    init(_ reference: NorthReference, declination: Double?) {
        self.reference = reference
        self.declination = declination
    }

    /// Whether a magnetic reading is shown as true.
    private var showsMagneticAsTrue: Bool { reference == .true && declination != nil }

    /// "M" or "T", for a magnetic reading as shown.
    var magneticSuffix: String { showsMagneticAsTrue ? "T" : "M" }

    /// A magnetic reading as shown.
    func shown(magnetic: Double) -> Double {
        Compass.normalized(magnetic + (showsMagneticAsTrue ? declination ?? 0 : 0))
    }

    /// A bearing entered as shown, back to magnetic.
    func magnetic(shown: Double) -> Double {
        Compass.normalized(shown - (showsMagneticAsTrue ? declination ?? 0 : 0))
    }

    /// A magnetic reading as true, once the declination is known.
    func trueBearing(magnetic: Double) -> Double? {
        declination.map { Compass.normalized(magnetic + $0) }
    }

    /// "054° M"
    func text(magnetic: Double) -> String {
        Self.degrees(shown(magnetic: magnetic)) + " " + magneticSuffix
    }

    /// A true bearing from GPS, "054° M" once the declination is known when magnetic is chosen.
    func text(true value: Double) -> String {
        if reference == .magnetic, let declination {
            return Self.degrees(Compass.normalized(value - declination)) + " M"
        }
        return Self.degrees(value) + " T"
    }

    /// "054°", rounded to a whole degree with 360 shown as 000.
    static func degrees(_ value: Double) -> String {
        String(format: "%03d°", Int(value.rounded()) % 360)
    }
}
