//
//  AIFactCheckService.swift
//  SomaTracker
//
//  The on-device model answers instantly, and every one of its answers is then reviewed by the cloud
//  model. The log lands immediately so nothing waits on the network, and when the review disagrees
//  materially the entry is corrected and the journal records what changed.
//

import Foundation
import SwiftData

@MainActor
enum AIFactCheckService {
    static let defaultsKey = "soma_fact_check"

    /// The rule this exists for: the cloud is always the second opinion, so it defaults on.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true
    }

    /// How far the cloud has to disagree before an entry is rewritten. Small gaps are noise, and
    /// rewriting on noise would be worse than leaving a good estimate alone.
    private static let calorieTolerance = 0.15

    /// Reviews an on-device estimate and corrects the entry if the cloud disagrees. Called after the
    /// entry is saved and on screen, so the user never waits for a network round trip.
    static func review(
        input: String,
        analysis: AIMealAnalysisResult,
        foodEntry: FoodEntry?,
        aiEntry: AIMealEntry?,
        context: ModelContext
    ) async {
        guard isEnabled, analysis.engine == .onDevice else { return }
        guard APIConfiguration.shared.hasCloudVisionReady else { return }
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let verdict: AIMealReview
        do {
            verdict = try await GeminiAIService().review(description: input, estimate: analysis)
        } catch {
            // A failed review leaves the on-device answer standing rather than flagging anything.
            #if DEBUG
            print("[FactCheck] Cloud review unavailable: \(error.localizedDescription)")
            #endif
            return
        }

        guard isTrustworthy(verdict), isMaterial(verdict, against: analysis) else { return }

        apply(verdict, to: foodEntry, and: aiEntry)

        do {
            try context.save()
        } catch {
            print("[FactCheck] Couldn't save the correction: \(error.localizedDescription)")
            return
        }

        // Health mirrors the entry, so the corrected numbers have to reach it too.
        await HealthSyncService.shared.syncDay(foodEntry?.dailyLog ?? aiEntry?.dailyLog)
    }

    /// The instruction shows a schema example, and a model that repeats it verbatim did not read the
    /// meal at all, so that reply is discarded rather than applied as a correction.
    private static func isTrustworthy(_ verdict: AIMealReview) -> Bool {
        let echoed = verdict.calories == 650
            && verdict.proteinG == 18
            && verdict.carbsG == 115
            && verdict.fatG == 12
        guard !echoed else {
            #if DEBUG
            print("[FactCheck] Reviewer echoed the schema example; ignoring it.")
            #endif
            return false
        }

        // The reviewer's own numbers have to hold together before they are allowed to overwrite ours.
        let macroCalories = verdict.proteinG * 4 + verdict.carbsG * 4 + verdict.fatG * 9
        guard macroCalories > 0 else { return false }
        return abs(Double(verdict.calories) - macroCalories) / Double(verdict.calories) <= 0.25
    }

    private static func isMaterial(_ verdict: AIMealReview, against analysis: AIMealAnalysisResult) -> Bool {
        guard verdict.calories > 0 else { return false }
        let gap = abs(Double(verdict.calories - analysis.calories)) / Double(max(1, analysis.calories))
        return gap > calorieTolerance
    }

    private static func apply(_ verdict: AIMealReview, to foodEntry: FoodEntry?, and aiEntry: AIMealEntry?) {
        if let foodEntry {
            foodEntry.calories = verdict.calories
            foodEntry.proteinG = verdict.proteinG
            foodEntry.carbsG = verdict.carbsG
            foodEntry.fatG = verdict.fatG
        }

        if let aiEntry {
            aiEntry.calories = verdict.calories
            aiEntry.proteinG = verdict.proteinG
            aiEntry.carbsG = verdict.carbsG
            aiEntry.fatG = verdict.fatG

            let note = verdict.reason.isEmpty
                ? "Reviewed by Soma's cloud model."
                : "Reviewed by Soma's cloud model: \(verdict.reason)"
            aiEntry.breakdownNotes = aiEntry.breakdownNotes.isEmpty
                ? note
                : "\(aiEntry.breakdownNotes)\n\(note)"
        }
    }
}
