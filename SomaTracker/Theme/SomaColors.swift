import SwiftUI

enum SomaColors {
    static let navy = Color(hex: "23225C")
    static let white = Color.white
    static let buyMeCoffeeYellow = Color(hex: "FFDD00")
    static let statsBackground = Color(.systemGroupedBackground)

    // Semantic Metric Palettes
    static let coral = Color(hex: "FF5C39")        // Calories / Food
    static let aqua = Color(hex: "1EA8E6")         // Water / Hydration
    static let iris = Color(hex: "7C5CFC")         // Protein
    static let emerald = Color(hex: "10B981")      // Steps / Activity
    static let streakOrange = Color(hex: "FF9500") // Streaks
}

extension Color {
    init(hex: String) {
        let cleanedHex = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        var value: UInt64 = 0
        Scanner(string: cleanedHex).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double
        let opacity: Double

        switch cleanedHex.count {
        case 6:
            red = Double((value & 0xFF0000) >> 16) / 255
            green = Double((value & 0x00FF00) >> 8) / 255
            blue = Double(value & 0x0000FF) / 255
            opacity = 1
        case 8:
            red = Double((value & 0xFF000000) >> 24) / 255
            green = Double((value & 0x00FF0000) >> 16) / 255
            blue = Double((value & 0x0000FF00) >> 8) / 255
            opacity = Double(value & 0x000000FF) / 255
        default:
            red = 0
            green = 0
            blue = 0
            opacity = 1
        }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
