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
    var aiMealEntryId: UUID? = nil

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

    init(amount: Int, timestamp: Date = .now, label: String? = nil, aiMealEntryId: UUID? = nil) {
        self.amount = amount
        self.timestamp = timestamp
        self.label = label
        self.aiMealEntryId = aiMealEntryId
    }
}

extension WaterEntry {
    /// The water half of a log that named both a drink and a meal ("شربت خمسة لتر موية وأكلت...").
    /// It rides along in the meal's own save, so one utterance fills both trackers in one write.
    static func loggedWithMeal(_ millilitres: Int, linkedTo entryId: UUID) -> WaterEntry? {
        let amount = min(millilitres, 5_000)
        guard amount > 0 else { return nil }
        return WaterEntry(amount: amount, timestamp: .now, label: "Soma AI", aiMealEntryId: entryId)
    }

    /// Deletes the water entry from its daily log and cleans up any linked AIMealEntry & audio file.
    func deleteWithSyncedAIEntry(from log: DailyLog?, in context: ModelContext) {
        log?.waterEntries.removeAll { $0.id == self.id }

        let targetAiId = self.aiMealEntryId
        let entryTime = self.timestamp

        let descriptor = FetchDescriptor<AIMealEntry>()
        if let aiEntries = try? context.fetch(descriptor) {
            for aiMeal in aiEntries {
                let isMatchById = (targetAiId != nil && aiMeal.id == targetAiId)
                let isMatchByHeuristic = targetAiId == nil &&
                    (self.label?.contains("AI") == true) &&
                    abs(aiMeal.timestamp.timeIntervalSince(entryTime)) < 120 &&
                    (aiMeal.title.contains("Hydration") || aiMeal.title.contains("Water"))

                if isMatchById || isMatchByHeuristic {
                    if let relPath = aiMeal.voiceAudioRelativePath {
                        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        try? FileManager.default.removeItem(at: docs.appendingPathComponent(relPath))
                    }
                    context.delete(aiMeal)
                }
            }
        }

        context.delete(self)
        try? context.save()
    }
}
