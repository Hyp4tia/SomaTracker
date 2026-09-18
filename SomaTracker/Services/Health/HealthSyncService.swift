//
//  HealthSyncService.swift
//  SomaTracker
//
//  Mirrors what Soma logs into Apple Health: dietary energy, protein, carbs, fat and water.
//  Soma only ever reads its own step count back out of Health.
//

import Foundation
import HealthKit

@MainActor
final class HealthSyncService {
    static let shared = HealthSyncService()

    /// The sample types Soma writes. HealthKitManager reads this list when it asks for
    /// permission, so the read and write sets can never drift apart.
    static let shareTypeIdentifiers: [HKQuantityTypeIdentifier] = [
        .dietaryEnergyConsumed,
        .dietaryProtein,
        .dietaryCarbohydrates,
        .dietaryFatTotal,
        .dietaryWater,
    ]

    /// Marks a sample as written by Soma. Every delete is scoped to it, so rewriting a day (or
    /// Reset All Data) can only ever clear Soma's own entries, never another app's.
    private static let originKey = "soma.origin"
    private static let originValue = "soma-tracker"

    private let healthStore = HKHealthStore()

    private init() {}

    // MARK: - Sync

    /// Rewrites one day in Health from the day's current entries. Called after every create,
    /// edit and delete: Health then always matches Soma, and nothing has to remember which
    /// sample belonged to which entry.
    func syncDay(_ log: DailyLog?) async {
        guard let log, canWrite else { return }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: log.date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }

        await deleteSamples(from: start, to: end)

        let samples = log.foodEntries.flatMap { samples(for: $0) } + log.waterEntries.flatMap { samples(for: $0) }
        guard !samples.isEmpty else { return }

        do {
            try await healthStore.save(samples)
        } catch {
            print("[HealthSync] Couldn't write the day to Health: \(error.localizedDescription)")
        }
    }

    /// Clears every sample Soma has written, for Reset All Data.
    func removeAllSamples() async {
        guard canWrite else { return }
        await deleteSamples(from: nil, to: nil)
    }

    // MARK: - Samples

    private func samples(for entry: FoodEntry) -> [HKQuantitySample] {
        let metadata: [String: Any] = [
            Self.originKey: Self.originValue,
            HKMetadataKeyFoodType: entry.name,
        ]
        // Health reads a zero-length food sample as a timestamp, so give each one a minute.
        let end = entry.timestamp.addingTimeInterval(60)

        let quantities: [(HKQuantityTypeIdentifier, Double, HKUnit)] = [
            (.dietaryEnergyConsumed, Double(entry.effectiveCalories), .kilocalorie()),
            (.dietaryProtein, entry.proteinG, .gram()),
            (.dietaryCarbohydrates, entry.carbsG, .gram()),
            (.dietaryFatTotal, entry.fatG, .gram()),
        ]

        var samples: [HKQuantitySample] = []
        for (identifier, value, unit) in quantities where value > 0 {
            samples.append(HKQuantitySample(
                type: HKQuantityType(identifier),
                quantity: HKQuantity(unit: unit, doubleValue: value),
                start: entry.timestamp,
                end: end,
                metadata: metadata
            ))
        }
        return samples
    }

    private func samples(for entry: WaterEntry) -> [HKQuantitySample] {
        guard entry.amount > 0 else { return [] }
        return [HKQuantitySample(
            type: HKQuantityType(.dietaryWater),
            quantity: HKQuantity(unit: .literUnit(with: .milli), doubleValue: Double(entry.amount)),
            start: entry.timestamp,
            end: entry.timestamp.addingTimeInterval(60),
            metadata: [Self.originKey: Self.originValue]
        )]
    }

    // MARK: - Helpers

    /// Writing needs permission the user may never have granted, and a silent no-op beats
    /// throwing an authorization error on every log.
    private var canWrite: Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        return healthStore.authorizationStatus(for: HKQuantityType(.dietaryEnergyConsumed)) == .sharingAuthorized
    }

    private func deleteSamples(from start: Date?, to end: Date?) async {
        var predicates = [HKQuery.predicateForObjects(withMetadataKey: Self.originKey)]
        if let start, let end {
            predicates.append(HKQuery.predicateForSamples(withStart: start, end: end))
        }
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        for identifier in Self.shareTypeIdentifiers {
            do {
                try await healthStore.deleteObjects(of: HKQuantityType(identifier), predicate: predicate)
            } catch {
                print("[HealthSync] Couldn't clear \(identifier.rawValue): \(error.localizedDescription)")
            }
        }
    }
}
