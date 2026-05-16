//
//  HealthKitManager.swift
//  SomaTracker
//

import Foundation
import HealthKit
import Observation
import SwiftData

@MainActor
@Observable
final class HealthKitManager {
    private(set) var todaySteps: Int = 0
    private(set) var isAuthorized: Bool = false

    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?
    // Stored as a property so the observer closure captures only self (Sendable),
    // keeping ModelContext access on @MainActor at all times.
    private var modelContext: ModelContext?

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let stepType = HKQuantityType(.stepCount)
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [stepType])
            isAuthorized = true
        } catch {
            isAuthorized = false
        }
    }

    // MARK: - Fetch

    func fetchTodaySteps() async -> Int {
        guard HKHealthStore.isHealthDataAvailable() else { return 0 }

        let stepType = HKQuantityType(.stepCount)
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: .now)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let count = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(count))
            }
            healthStore.execute(query)
        }
    }

    func refreshTodaySteps(modelContext: ModelContext) async {
        let steps = await fetchTodaySteps()
        todaySteps = steps

        let log = DailyLog.fetchOrCreateToday(context: modelContext)
        log.steps = steps
        try? modelContext.save()
    }

    // MARK: - Observer

    func startObserving(modelContext: ModelContext) {
        self.modelContext = modelContext
        guard observerQuery == nil else { return }

        let stepType = HKQuantityType(.stepCount)

        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, done, error in
            // Signal HealthKit immediately per docs — processing happens asynchronously below.
            defer { done() }
            guard error == nil else { return }
            Task { @MainActor [weak self] in
                guard let self, let ctx = self.modelContext else { return }
                await self.refreshTodaySteps(modelContext: ctx)
            }
        }

        observerQuery = query
        healthStore.execute(query)
        // Wake the app in the background on every new step batch.
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { _, _ in }
    }
}
