//
//  MealAppEntity.swift
//  SomaTracker
//
//  A logged meal, in the shape the system understands. This is what lets Siri talk about a meal
//  Soma knows ("log that again", "find the pizza") instead of only running fixed commands.
//

import AppIntents
import CoreSpotlight
import Foundation
import SwiftData
import UniformTypeIdentifiers

struct MealAppEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Meal"
    static var defaultQuery = MealEntityQuery()

    let id: String
    let title: String
    let calories: Int
    let proteinG: Double
    let timestamp: Date
    let mealType: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(calories.formatted()) kcal · \(Int(proteinG.rounded()))g protein",
            image: .init(systemName: "fork.knife")
        )
    }

    @MainActor
    init(entry: FoodEntry) {
        self.id = MealAppEntity.identifier(for: entry)
        self.title = entry.name
        self.calories = entry.effectiveCalories
        self.proteinG = entry.proteinG
        self.timestamp = entry.timestamp
        self.mealType = entry.mealType
    }

    /// Stable for the life of one store: the persistent identifier's description carries the store
    /// ID and the row's primary key, which is what Spotlight and Siri both key off.
    @MainActor
    static func identifier(for entry: FoodEntry) -> String {
        String(describing: entry.id)
    }
}

/// Read-only access to recent meals. Kept in one place so Siri resolution, Spotlight and any future
/// snippet all see the same list.
@MainActor
enum SomaMeals {
    /// The container is resolved inside rather than as a default argument: default values are
    /// evaluated outside the main actor, where the shared container cannot be reached.
    static func recent(limit: Int = 50, context: ModelContext? = nil) -> [MealAppEntity] {
        guard let context = context ?? SomaPersistence.shared.mainContext as ModelContext? else { return [] }
        var descriptor = FetchDescriptor<FoodEntry>(
            sortBy: [SortDescriptor(\FoodEntry.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let entries = (try? context.fetch(descriptor)) ?? []
        return entries.map { MealAppEntity(entry: $0) }
    }
}

struct MealEntityQuery: EntityStringQuery, EnumerableEntityQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [MealAppEntity] {
        let wanted = Set(identifiers)
        return SomaMeals.recent(limit: 100).filter { wanted.contains($0.id) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [MealAppEntity] {
        let needle = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return SomaMeals.recent(limit: 20) }
        return SomaMeals.recent(limit: 100).filter { $0.title.lowercased().contains(needle) }
    }

    @MainActor
    func allEntities() async throws -> [MealAppEntity] {
        SomaMeals.recent(limit: 100)
    }

    @MainActor
    func suggestedEntities() async throws -> [MealAppEntity] {
        SomaMeals.recent(limit: 5)
    }
}

/// Spotlight needs a description of what it is indexing. iOS 18 and later only.
@available(iOS 18.0, *)
extension MealAppEntity: IndexedEntity {
    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = title
        attributes.contentDescription = "\(calories) kcal · \(Int(proteinG.rounded()))g protein"
        attributes.keywords = [title, mealType, "Soma", "meal", "calories"]
        attributes.contentCreationDate = timestamp
        return attributes
    }
}
