//
//  SomaFoodSuggestion.swift
//  SomaTracker
//
//  Suggesting what to eat next: real dishes from the app's own database, with numbers it already knows,
//  chosen to be like what this person eats and to fit what is left of the day. The model's job is to pick
//  and explain, not to invent a meal and its numbers.
//

import Foundation

/// Broad kinds of food, used to match a suggestion to what somebody already eats.
enum SomaFoodCategory: CaseIterable {
    case breakfast, sandwich, grill, ricePlate, dairy, fruit, vegetable, drink, sweet, other

    static func of(_ text: String) -> SomaFoodCategory {
        let lower = text.lowercased()

        if lower.matches(["فول", "طعمية", "فلافل", "فطير", "بيض", "foul", "falafel", "taameya", "egg", "feteer"]) { return .breakfast }
        if lower.matches(["ساندوتش", "سندوتش", "برجر", "شاورما", "بانيه", "shawarma", "burger", "sandwich", "wrap", "nugget", "pizza", "بيتزا"]) { return .sandwich }
        if lower.matches(["كفتة", "كباب", "مشوي", "فراخ", "دجاج", "لحم", "كبدة", "سمك", "حواوشي", "grill", "chicken", "beef", "steak", "kofta", "kebab", "fish", "hawawshi"]) { return .grill }
        if lower.matches(["كشري", "رز", "مكرونة", "معكرونة", "pasta", "rice", "koshary", "noodle"]) { return .ricePlate }
        if lower.matches(["زبادي", "لبن", "جبنة", "جبن", "yogurt", "yoghurt", "milk", "cheese", "لبنة"]) { return .dairy }
        if lower.matches(["موز", "تفاح", "برتقان", "عنب", "فراولة", "مانجا", "بطيخ", "تمر", "فاكهة", "banana", "apple", "orange", "grape", "strawberry", "mango", "watermelon", "date", "fruit"]) { return .fruit }
        if lower.matches(["سلطة", "خضار", "طماطم", "خيار", "بامية", "ملوخية", "محشي", "شوربة", "salad", "vegetable", "soup", "molokhia", "bamia"]) { return .vegetable }
        if lower.matches(["عصير", "قهوة", "شاي", "كولا", "بيبسي", "juice", "coffee", "tea", "cola", "pepsi", "soda"]) { return .drink }
        if lower.matches(["حلوى", "بسكويت", "شوكولاتة", "كيك", "كنافة", "بسبوسة", "sweet", "cookie", "biscuit", "chocolate", "cake", "dessert"]) { return .sweet }

        return .other
    }
}

private extension String {
    func matches(_ needles: [String]) -> Bool {
        needles.contains { contains($0) }
    }
}

enum SomaFoodSuggestion {
    /// Dishes worth putting in front of the model for this particular day.
    ///
    /// "Like what they like" is the matching rule: a suggestion must come from the same broad kinds of
    /// food the user already eats, fit the room left in the day, and not be something they have already
    /// logged today. When protein is short, protein density decides the order.
    static func candidates(
        remainingCalories: Int,
        remainingProteinG: Int,
        favouriteNames: [String],
        todayTitles: [String],
        limit: Int = 6
    ) -> [String] {
        let pool = FoodNutritionDatabase.shared.items
        let alreadyEaten = Set(todayTitles.map { $0.lowercased() })
        let likedCategories = Set(favouriteNames.map { SomaFoodCategory.of($0) })
        let proteinIsShort = remainingProteinG > 25

        let scored: [(item: FoodItemInfo, score: Double)] = pool.compactMap { item in
            guard item.calories > 0, !alreadyEaten.contains(item.name.lowercased()) else { return nil }

            let calories = Double(item.calories)
            // It either fits what is left, or it is a small top-up once the goal is already met.
            if remainingCalories > 0, calories > Double(remainingCalories) * 1.05 { return nil }
            if remainingCalories <= 0, calories > 250 { return nil }

            let category = SomaFoodCategory.of(item.name + " " + item.aliases.joined(separator: " "))

            var score = 0.0
            if likedCategories.contains(category) { score += 2 }
            if proteinIsShort { score += item.proteinG / max(1, calories / 100) }
            if remainingCalories > 200 { score += min(1, calories / Double(remainingCalories)) }
            return (item, score)
        }

        return scored
            .sorted { $0.score == $1.score ? $0.item.calories < $1.item.calories : $0.score > $1.score }
            .prefix(limit)
            .map { "\($0.item.name) (\($0.item.calories) kcal, \(Int($0.item.proteinG.rounded())) g protein)" }
    }
}
