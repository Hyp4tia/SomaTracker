//
//  WaterEntry.swift
//  SomaTracker
//

import Foundation
import SwiftData

@Model
final class WaterEntry {
    var amount: Int
    var timestamp: Date
    var label: String?
    var dailyLog: DailyLog?

    var resolvedTitle: String {
        if let customLabel = label?.trimmingCharacters(in: .whitespacesAndNewlines), !customLabel.isEmpty {
            return customLabel
        }
        let hour = Calendar.current.component(.hour, from: timestamp)
        switch hour {
        case 5..<11:
            return "Morning Hydration"
        case 11..<14:
            return "Midday Hydration"
        case 14..<17:
            return "Afternoon Refresher"
        case 17..<22:
            return "Evening Hydration"
        default:
            return "Night Hydration"
        }
    }

    init(amount: Int, timestamp: Date = .now, label: String? = nil) {
        self.amount = amount
        self.timestamp = timestamp
        self.label = label
    }
}
