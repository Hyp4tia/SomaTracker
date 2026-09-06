//
//  FoodNutritionDatabase.swift
//  SomaTracker
//
//  On-device nutritional intelligence engine for instant food lookup and natural language parsing.
//

import Foundation

struct FoodItemInfo {
    let name: String
    let calories: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let aliases: [String]
}

enum ParsedNutritionType {
    case water(amountML: Int)
    case food(title: String, calories: Int, proteinG: Double, carbsG: Double, fatG: Double)
}

struct ParsedNutritionResult {
    let type: ParsedNutritionType
    let title: String
    let calories: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let waterML: Int
    let summary: String

    var isWater: Bool {
        if case .water = type { return true }
        return false
    }
}

final class FoodNutritionDatabase {
    static let shared = FoodNutritionDatabase()

    private let foodDatabase: [FoodItemInfo] = [
        // MARK: - Fast Food / Popular Chains
        FoodItemInfo(
            name: "McDonald's Big Mac",
            calories: 590,
            proteinG: 25.0,
            carbsG: 46.0,
            fatG: 34.0,
            aliases: ["big mac", "bigmac", "mcdonalds big mac", "mcdonalds bigmac", "mcdonald big mac"]
        ),
        FoodItemInfo(
            name: "McDonald's Quarter Pounder",
            calories: 520,
            proteinG: 30.0,
            carbsG: 42.0,
            fatG: 26.0,
            aliases: ["quarter pounder", "quarter pounder with cheese", "mcdonalds quarter pounder"]
        ),
        FoodItemInfo(
            name: "McDonald's McChicken",
            calories: 400,
            proteinG: 14.0,
            carbsG: 39.0,
            fatG: 21.0,
            aliases: ["mcchicken", "mcdonalds mcchicken", "mc chicken"]
        ),
        FoodItemInfo(
            name: "McDonald's Chicken McNuggets (10 pc)",
            calories: 410,
            proteinG: 23.0,
            carbsG: 26.0,
            fatG: 24.0,
            aliases: ["mcnuggets", "chicken mcnuggets", "nuggets", "10 mcnuggets", "10 piece nuggets"]
        ),
        FoodItemInfo(
            name: "McDonald's French Fries (Medium)",
            calories: 320,
            proteinG: 4.0,
            carbsG: 43.0,
            fatG: 15.0,
            aliases: ["french fries", "fries", "mcdonalds fries"]
        ),
        FoodItemInfo(
            name: "McDonald's Cheeseburger",
            calories: 300,
            proteinG: 15.0,
            carbsG: 32.0,
            fatG: 13.0,
            aliases: ["cheeseburger", "mcdonalds cheeseburger"]
        ),
        FoodItemInfo(
            name: "Chipotle Chicken Burrito Bowl",
            calories: 680,
            proteinG: 52.0,
            carbsG: 68.0,
            fatG: 22.0,
            aliases: ["chipotle bowl", "burrito bowl", "chipotle chicken bowl", "chipotle"]
        ),
        FoodItemInfo(
            name: "Subway 6\" Turkey Breast Sub",
            calories: 280,
            proteinG: 18.0,
            carbsG: 40.0,
            fatG: 3.5,
            aliases: ["subway", "subway sub", "turkey sub"]
        ),

        // MARK: - Everyday Meals & Staples
        FoodItemInfo(
            name: "Scrambled Eggs (2) with Sourdough Toast",
            calories: 320,
            proteinG: 17.0,
            carbsG: 28.0,
            fatG: 14.0,
            aliases: ["eggs and toast", "scrambled eggs", "2 eggs", "eggs and sourdough", "breakfast eggs"]
        ),
        FoodItemInfo(
            name: "Boiled Egg (Single)",
            calories: 78,
            proteinG: 6.3,
            carbsG: 0.6,
            fatG: 5.3,
            aliases: ["egg", "1 egg", "boiled egg", "hard boiled egg"]
        ),
        FoodItemInfo(
            name: "Grilled Chicken Breast (200g)",
            calories: 330,
            proteinG: 62.0,
            carbsG: 0.0,
            fatG: 7.2,
            aliases: ["chicken breast", "grilled chicken", "chicken", "chicken and rice"]
        ),
        FoodItemInfo(
            name: "Grilled Salmon with Quinoa",
            calories: 540,
            proteinG: 42.0,
            carbsG: 40.0,
            fatG: 22.0,
            aliases: ["salmon", "grilled salmon", "salmon bowl", "salmon and rice", "salmon with quinoa"]
        ),
        FoodItemInfo(
            name: "Greek Yogurt (1 cup, 0% fat)",
            calories: 130,
            proteinG: 22.0,
            carbsG: 8.0,
            fatG: 0.5,
            aliases: ["greek yogurt", "yogurt", "chobani", "fage"]
        ),
        FoodItemInfo(
            name: "Whey Protein Shake (1 Scoop)",
            calories: 130,
            proteinG: 25.0,
            carbsG: 3.0,
            fatG: 1.5,
            aliases: ["protein shake", "whey", "protein powder", "shake"]
        ),
        FoodItemInfo(
            name: "Avocado Toast",
            calories: 290,
            proteinG: 8.0,
            carbsG: 26.0,
            fatG: 18.0,
            aliases: ["avocado toast", "avo toast"]
        ),
        FoodItemInfo(
            name: "Oatmeal with Banana & Honey",
            calories: 310,
            proteinG: 8.0,
            carbsG: 62.0,
            fatG: 4.5,
            aliases: ["oatmeal", "oats", "porridge", "bowl of oatmeal"]
        ),
        FoodItemInfo(
            name: "Ribeye Steak (250g)",
            calories: 650,
            proteinG: 54.0,
            carbsG: 0.0,
            fatG: 48.0,
            aliases: ["steak", "ribeye", "beef steak", "sirloin"]
        ),
        FoodItemInfo(
            name: "Caesar Salad with Chicken",
            calories: 440,
            proteinG: 34.0,
            carbsG: 16.0,
            fatG: 28.0,
            aliases: ["caesar salad", "chicken caesar salad", "salad"]
        ),
        FoodItemInfo(
            name: "Pepperoni Pizza (2 Slices)",
            calories: 580,
            proteinG: 24.0,
            carbsG: 64.0,
            fatG: 26.0,
            aliases: ["pizza", "pepperoni pizza", "slice of pizza", "2 slices pizza"]
        ),
        FoodItemInfo(
            name: "Iced Latte (Whole Milk)",
            calories: 150,
            proteinG: 8.0,
            carbsG: 14.0,
            fatG: 7.0,
            aliases: ["latte", "iced latte", "cappuccino", "coffee"]
        ),

        // MARK: - Egyptian & Middle Eastern Staples
        FoodItemInfo(
            name: "كشري مصري (Koshary)",
            calories: 650,
            proteinG: 18.0,
            carbsG: 115.0,
            fatG: 12.0,
            aliases: ["كشري", "طبق كشري", "علبة كشري", "كشري مصري", "koshary", "koshari", "koshery"]
        ),
        FoodItemInfo(
            name: "حواوشي مصري (Hawawshi)",
            calories: 580,
            proteinG: 28.0,
            carbsG: 45.0,
            fatG: 32.0,
            aliases: ["حواوشي", "رغيف حواوشي", "ساندوتش حواوشي", "hawawshi", "hawawshy", "hawawshe"]
        ),
        FoodItemInfo(
            name: "فول مدمس (Foul Mudammas)",
            calories: 220,
            proteinG: 14.0,
            carbsG: 32.0,
            fatG: 4.0,
            aliases: ["فول", "طبق فول", "ساندوتش فول", "فول بالزيت", "foul", "ful", "ful mudammas"]
        ),
        FoodItemInfo(
            name: "طعمية / فلافل (Ta'ameya / Falafel)",
            calories: 280,
            proteinG: 10.0,
            carbsG: 28.0,
            fatG: 15.0,
            aliases: ["طعمية", "فلافل", "ساندوتش طعمية", "قرص طعمية", "taameya", "ta'ameya", "falafel"]
        ),
        FoodItemInfo(
            name: "شاورما (Shawarma)",
            calories: 520,
            proteinG: 32.0,
            carbsG: 40.0,
            fatG: 24.0,
            aliases: ["شاورما", "ساندوتش شاورما", "شاورما فراخ", "شاورما لحمة", "شاورما عربي", "shawarma", "shawurma"]
        ),
        FoodItemInfo(
            name: "كفتة مشوية (Grilled Kofta)",
            calories: 420,
            proteinG: 30.0,
            carbsG: 6.0,
            fatG: 30.0,
            aliases: ["كفتة", "كفتة مشوية", "ساندوتش كفتة", "kofta", "kefta", "kufta"]
        ),
        FoodItemInfo(
            name: "كبدة إسكندراني (Alexandrian Liver)",
            calories: 380,
            proteinG: 34.0,
            carbsG: 12.0,
            fatG: 22.0,
            aliases: ["كبدة", "كبدة اسكندراني", "ساندوتش كبدة", "kebda", "kebda eskandarani"]
        ),
        FoodItemInfo(
            name: "ملوخية ورز وفراخ (Molokhia, Rice & Chicken)",
            calories: 550,
            proteinG: 42.0,
            carbsG: 55.0,
            fatG: 16.0,
            aliases: ["ملوخية", "ملوخيه", "ملوخية وفراخ", "طبق ملوخية", "molokhia", "molokhiya", "mulukhiyah"]
        ),
        FoodItemInfo(
            name: "فطير مشلتت (Feteer Meshaltet)",
            calories: 620,
            proteinG: 12.0,
            carbsG: 70.0,
            fatG: 32.0,
            aliases: ["فطير", "فطير مشلتت", "feteer", "fetir"]
        ),
        FoodItemInfo(
            name: "رز معمر (Roz Me'ammar)",
            calories: 490,
            proteinG: 12.0,
            carbsG: 68.0,
            fatG: 20.0,
            aliases: ["رز معمر", "ارز معمر", "roz maamar", "roz meammar"]
        ),
        FoodItemInfo(
            name: "جبنة قريش (Arish Cheese)",
            calories: 120,
            proteinG: 22.0,
            carbsG: 4.0,
            fatG: 2.0,
            aliases: ["جبنة قريش", "جبنه قريش", "قريش", "arish", "cottage cheese"]
        )
    ]

    private init() {}

    /// Main parsing function that understands natural text in English, Arabic, and Egyptian dialects:
    /// - "log 100 water" / "سجل ١٠٠ مية" / "شربت مية" -> 100 ml water
    /// - "i ate a mcdonalds today, bigmac" -> Big Mac
    /// - "أكلت طبق كشري" -> Koshary (650 kcal, 18g P)
    /// - "ساندوتشين حواوشي" -> Hawawshi (580 kcal, 28g P)
    /// - "500 calories" / "٥٠٠ سعرة" -> 500 kcal
    /// - "40 protein" / "٤٠ بروتين" -> 40g protein
    func parseInput(_ input: String) -> ParsedNutritionResult {
        let normalizedText = normalizeNumerals(input)
        let cleaned = normalizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = cleaned.lowercased()

        // 1. Water logging (English & Arabic: water, hydration, مية, ماء, مويه, ماي, ازازة, زجاجة, كوباية, كوبايتين)
        let hasWaterKeyword = lower.contains("water") || lower.contains("drink") || lower.contains("hydration")
            || lower.contains("مية") || lower.contains("ماء") || lower.contains("مويه") || lower.contains("ماي")
            || lower.contains("ازازة") || lower.contains("زجاجة") || lower.contains("قارورة")
            || lower.contains("كوباية") || lower.contains("كوبايتين")

        if hasWaterKeyword {
            var extractedAmount: Int
            if let num = extractFirstNumber(from: lower) {
                extractedAmount = num
            } else if lower.contains("كوبايتين") || lower.contains("كوبين") || lower.contains("two cups") {
                extractedAmount = 500
            } else if lower.contains("كوباية") || lower.contains("كوب") || lower.contains("كاسة") || lower.contains("cup") {
                extractedAmount = 250
            } else if lower.contains("ازازة كبيرة") || lower.contains("زجاجة كبيرة") || lower.contains("large bottle") {
                extractedAmount = 1500
            } else if lower.contains("ازازة") || lower.contains("زجاجة") || lower.contains("قارورة") || lower.contains("bottle") {
                extractedAmount = 500
            } else if lower.contains("نص لتر") || lower.contains("نصف لتر") {
                extractedAmount = 500
            } else if lower.contains("لتر") || lower.contains("liter") {
                extractedAmount = 1000
            } else {
                extractedAmount = 250
            }

            let displayTitle = lower.contains("مية") || lower.contains("ماء") || lower.contains("ماي") || lower.contains("مويه")
                || lower.contains("ازازة") || lower.contains("كوباية")
                ? "شرب ماء"
                : "Water Intake"
            return ParsedNutritionResult(
                type: .water(amountML: extractedAmount),
                title: displayTitle,
                calories: 0,
                proteinG: 0,
                carbsG: 0,
                fatG: 0,
                waterML: extractedAmount,
                summary: lower.contains("مية") || lower.contains("ماء") || lower.contains("ازازة") || lower.contains("كوباية")
                    ? "تم تسجيل \(extractedAmount) مل ماء"
                    : "Logged \(extractedAmount) ml of water"
            )
        }

        // 2. Explicit Calorie-only command: "500 calories", "٥٠٠ سعرة", "كالوري"
        if (lower.contains("calorie") || lower.contains("kcal") || lower.contains("سعرة") || lower.contains("سعرات") || lower.contains("كالوري"))
            && !lower.contains("protein") && !lower.contains("بروتين") {
            let cal = extractFirstNumber(from: lower) ?? 400
            let title = lower.contains("سعرة") || lower.contains("كالوري") ? "سعرات سريعة" : "Quick Calories"
            return ParsedNutritionResult(
                type: .food(title: title, calories: cal, proteinG: 0, carbsG: 0, fatG: 0),
                title: title,
                calories: cal,
                proteinG: 0,
                carbsG: 0,
                fatG: 0,
                waterML: 0,
                summary: "Logged \(cal) kcal"
            )
        }

        // 3. Explicit Protein-only command: "40 protein", "٤٠ جرام بروتين"
        if (lower.contains("protein") || lower.contains("بروتين"))
            && !lower.contains("shake") && !lower.contains("powder") && !lower.contains("bar") {
            let prot = Double(extractFirstNumber(from: lower) ?? 30)
            let cal = Int(round(prot * 4.0))
            let title = lower.contains("بروتين") ? "جرعة بروتين" : "Protein Boost"
            return ParsedNutritionResult(
                type: .food(title: title, calories: cal, proteinG: prot, carbsG: 0, fatG: 0),
                title: title,
                calories: cal,
                proteinG: prot,
                carbsG: 0,
                fatG: 0,
                waterML: 0,
                summary: "Logged \(Int(prot))g protein (\(cal) kcal)"
            )
        }

        // 4. Fuzzy database search for branded fast food, staples, and Egyptian favorites
        for item in foodDatabase {
            for alias in item.aliases {
                if lower.contains(alias) {
                    return ParsedNutritionResult(
                        type: .food(
                            title: item.name,
                            calories: item.calories,
                            proteinG: item.proteinG,
                            carbsG: item.carbsG,
                            fatG: item.fatG
                        ),
                        title: item.name,
                        calories: item.calories,
                        proteinG: item.proteinG,
                        carbsG: item.carbsG,
                        fatG: item.fatG,
                        waterML: 0,
                        summary: "Logged \(item.name): \(item.calories) kcal, \(Int(item.proteinG))g protein"
                    )
                }
            }
        }

        // 5. Intelligent NLP Fallback for unlisted meal descriptions
        let extractedNumber = extractFirstNumber(from: lower)
        let estCal = extractedNumber != nil && extractedNumber! >= 50 && extractedNumber! <= 3000 ? extractedNumber! : 450
        let estProtein = Double(max(15, Int(round(Double(estCal) * 0.06))))
        let estCarbs = Double(max(20, Int(round(Double(estCal) * 0.10))))
        let estFat = Double(max(8, Int(round(Double(estCal) * 0.03))))

        // Clean user title
        var title = cleaned
            .replacingOccurrences(of: "i ate", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "i had", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "today", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "log", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "أكلت", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "شربت", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "سجل", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,.-"))

        if title.isEmpty {
            title = "Meal Entry"
        }
        if title.count > 30 {
            title = String(title.prefix(28)) + "..."
        }

        return ParsedNutritionResult(
            type: .food(
                title: title,
                calories: estCal,
                proteinG: estProtein,
                carbsG: estCarbs,
                fatG: estFat
            ),
            title: title,
            calories: estCal,
            proteinG: estProtein,
            carbsG: estCarbs,
            fatG: estFat,
            waterML: 0,
            summary: "Logged \(title): \(estCal) kcal, \(Int(estProtein))g protein"
        )
    }

    /// Converts Eastern Arabic numerals (٠-٩) to ASCII numerals (0-9)
    private func normalizeNumerals(_ text: String) -> String {
        var result = text
        let arabicIndic = [
            "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4",
            "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9"
        ]
        for (ar, en) in arabicIndic {
            result = result.replacingOccurrences(of: ar, with: en)
        }
        return result
    }

    private func extractFirstNumber(from text: String) -> Int? {
        let pattern = "\\d+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))

        if let firstMatch = matches.first {
            let matchString = nsString.substring(with: firstMatch.range)
            return Int(matchString)
        }
        return nil
    }
}
