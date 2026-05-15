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
    var dailyLog: DailyLog?

    init(amount: Int, timestamp: Date = .now) {
        self.amount = amount
        self.timestamp = timestamp
    }
}
