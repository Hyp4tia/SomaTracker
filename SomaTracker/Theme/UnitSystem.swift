import Foundation

/// User-selectable measurement system. Persisted via @AppStorage("unitSystem").
enum UnitSystem: String, CaseIterable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }

    var title: String {
        switch self {
        case .metric: "Metric"
        case .imperial: "Imperial"
        }
    }
}

/// Conversion + formatting helpers. All values are stored canonically in metric
/// (water = ml, weight = kg, height = cm); these only convert for display/input.
enum Units {
    static let storageKey = "unitSystem"

    private static let mlPerFlOz = 29.5735
    private static let lbPerKg = 2.2046226
    private static let cmPerInch = 2.54

    // MARK: - Water (stored in ml)

    static func waterUnit(_ system: UnitSystem) -> String {
        system == .metric ? "ml" : "fl oz"
    }

    /// Converts stored ml into the display value for the given system.
    static func waterValue(ml: Int, system: UnitSystem) -> Int {
        switch system {
        case .metric: return ml
        case .imperial: return Int((Double(ml) / mlPerFlOz).rounded())
        }
    }

    /// Converts a value entered in the current system back into ml for storage.
    static func waterToML(_ value: Int, system: UnitSystem) -> Int {
        switch system {
        case .metric: return value
        case .imperial: return Int((Double(value) * mlPerFlOz).rounded())
        }
    }

    /// Quick-add presets in the current system's unit.
    static func waterQuickAmounts(_ system: UnitSystem) -> [Int] {
        system == .metric ? [200, 250, 500, 750] : [8, 12, 16, 20]
    }

    // MARK: - Weight (stored in kg)

    static func weightUnit(_ system: UnitSystem) -> String {
        system == .metric ? "kg" : "lb"
    }

    static func weightValue(kg: Double, system: UnitSystem) -> Double {
        system == .metric ? kg : kg * lbPerKg
    }

    static func weightToKG(_ value: Double, system: UnitSystem) -> Double {
        system == .metric ? value : value / lbPerKg
    }

    // MARK: - Height (stored in cm)

    static func heightUnit(_ system: UnitSystem) -> String {
        system == .metric ? "cm" : "in"
    }

    static func heightValue(cm: Double, system: UnitSystem) -> Double {
        system == .metric ? cm : cm / cmPerInch
    }

    static func heightToCM(_ value: Double, system: UnitSystem) -> Double {
        system == .metric ? value : value * cmPerInch
    }
}
