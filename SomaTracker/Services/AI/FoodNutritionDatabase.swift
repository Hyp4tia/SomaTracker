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
            name: "Latte (Whole Milk)",
            calories: 150,
            proteinG: 8.0,
            carbsG: 14.0,
            fatG: 7.0,
            // Both Arabic spellings: this matcher is a plain substring test with no Arabic folding,
            // so a user who writes "ايس لاتيه" would miss an alias stored as "آيس لاتيه".
            aliases: [
                "latte", "iced latte", "cappuccino", "coffee",
                "لاتيه", "آيس لاتيه", "ايس لاتيه", "قهوة باللبن",
            ]
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
        ),
        // MARK: - Beverages, Sodas & Low-Calorie Drinks
        FoodItemInfo(
            name: "7up Lemon Mojito (245ml)",
            calories: 2,
            proteinG: 0.0,
            carbsG: 0.5,
            fatG: 0.0,
            aliases: ["7up lemon mojito", "7up mojito", "seven up mojito", "سفن اب موهيتو", "سفن موهيتو", "سفن اب ليمون موهيتو", "7up lemon", "mojito can"]
        ),
        FoodItemInfo(
            name: "7up Free / Diet (250ml)",
            calories: 2,
            proteinG: 0.0,
            carbsG: 0.4,
            fatG: 0.0,
            aliases: ["7up free", "7up diet", "diet 7up", "سفن اب دايت", "سفن اب فري"]
        ),
        FoodItemInfo(
            name: "7up Regular Can (330ml)",
            calories: 140,
            proteinG: 0.0,
            carbsG: 36.0,
            fatG: 0.0,
            aliases: ["7up", "seven up", "can of 7up", "سفن اب", "سفن"]
        ),
        FoodItemInfo(
            name: "Diet Pepsi / Pepsi Black (330ml)",
            calories: 1,
            proteinG: 0.0,
            carbsG: 0.2,
            fatG: 0.0,
            aliases: ["diet pepsi", "pepsi black", "pepsi zero", "pepsi diet", "بيبسي دايت", "بيبسي بلاك", "بيبسي زيرو"]
        ),
        FoodItemInfo(
            name: "Pepsi Regular Can (330ml)",
            calories: 150,
            proteinG: 0.0,
            carbsG: 41.0,
            fatG: 0.0,
            aliases: ["pepsi", "can of pepsi", "بيبسي", "كان بيبسي"]
        ),
        FoodItemInfo(
            name: "Coca-Cola Zero Sugar (330ml)",
            calories: 1,
            proteinG: 0.0,
            carbsG: 0.0,
            fatG: 0.0,
            aliases: ["coke zero", "coca cola zero", "diet coke", "كولا زيرو", "كوكاكولا زيرو", "كولا دايت"]
        ),
        FoodItemInfo(
            name: "Coca-Cola Regular Can (330ml)",
            calories: 140,
            proteinG: 0.0,
            carbsG: 35.0,
            fatG: 0.0,
            aliases: ["coca cola", "coke", "can of coke", "كوكاكولا", "كولا"]
        ),
        FoodItemInfo(
            name: "Red Bull Sugarfree (250ml)",
            calories: 5,
            proteinG: 0.0,
            carbsG: 0.0,
            fatG: 0.0,
            aliases: ["red bull sugarfree", "sugarfree red bull", "redbull zero", "ريد بول دايت"]
        ),
        FoodItemInfo(
            name: "Red Bull Energy Drink (250ml)",
            calories: 115,
            proteinG: 1.0,
            carbsG: 27.0,
            fatG: 0.0,
            aliases: ["red bull", "redbull", "ريد بول", "مشروب طاقة"]
        ),
        FoodItemInfo(
            name: "Black Coffee / Espresso (No Sugar)",
            calories: 5,
            proteinG: 0.3,
            carbsG: 0.0,
            fatG: 0.0,
            aliases: ["black coffee", "espresso", "americano", "قهوة سادة", "قهوة سودا", "اسبريسو", "امريكانو"]
        ),
        FoodItemInfo(
            name: "Fresh Orange Juice (250ml)",
            calories: 110,
            proteinG: 1.7,
            carbsG: 26.0,
            fatG: 0.5,
            aliases: ["orange juice", "fresh orange juice", "عصير برتقال", "عصير لمون", "lemonade"]
        ),
        FoodItemInfo(
            name: "شاي بلبن (Tea with Milk)",
            calories: 90,
            proteinG: 3.0,
            carbsG: 12.0,
            fatG: 3.0,
            aliases: ["شاي بلبن", "شاي باللبن", "شاي بحليب"]
        ),
        FoodItemInfo(
            name: "عصير مانجو (Mango Juice)",
            calories: 150,
            proteinG: 1.0,
            carbsG: 36.0,
            fatG: 0.5,
            // Juice only: plain "مانجو" is the fruit, not a glass of juice.
            aliases: ["عصير مانجو", "عصير مانجا", "مانجو عصير", "mango juice"]
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

        guard !cleaned.isEmpty else {
            return ParsedNutritionResult(
                type: .food(title: "No Food Detected", calories: 0, proteinG: 0, carbsG: 0, fatG: 0),
                title: "No Food Detected",
                calories: 0,
                proteinG: 0,
                carbsG: 0,
                fatG: 0,
                waterML: 0,
                summary: "No food detected."
            )
        }

        let lower = cleaned.lowercased()

        // 1. Water logging (English & Arabic: water, hydration, مية, ماء, مويه, ماي)
        let isFlavoredOrSoda = lower.contains("soda") || lower.contains("pepsi") || lower.contains("cola")
            || lower.contains("7up") || lower.contains("seven up") || lower.contains("sprite")
            || lower.contains("mojito") || lower.contains("juice") || lower.contains("coffee")
            || lower.contains("tea") || lower.contains("عصير") || lower.contains("بيبسي")
            || lower.contains("كولا") || lower.contains("سفن") || lower.contains("قهوة") || lower.contains("شاي")

        // Every spelling dictation produces for water, including the ones it writes with an alef or
        // a taa marbuta ("مياه", "مايه"): those used to miss this branch and land in the food log.
        let arabicWaterNouns = ["مية", "ماء", "مياه", "مايه", "ميّه", "مويه", "موية", "ماي", "ازازة", "زجاجة", "قارورة", "كوباية", "كوبايتين", "كاسة"]
        let arabicWater = arabicWaterNouns.contains { lower.contains($0) }

        let hasWaterKeyword = !isFlavoredOrSoda && (
            arabicWater
            || lower.contains("water") || lower.contains("hydration")
            || lower.contains("drink water") || lower.contains("drinking water")
            || (lower == "ازازة" || lower == "زجاجة" || lower == "كوباية" || lower == "كوبايتين")
        )

        // A sentence that also names real food is a meal log. "شربت مية مع الكشري" used to be
        // swallowed here and logged as a default glass of water, with the meal lost.
        if hasWaterKeyword && databaseMatch(in: lower) == nil {
            var extractedAmount: Int
            if let num = extractFirstNumber(from: lower) {
                // "2 كوباية مية" means two cups, not two millilitres.
                extractedAmount = num <= 20 && ["كوباية", "كوب", "كاسة", "cup", "glass"].contains(where: { lower.contains($0) })
                    ? num * 250
                    : num
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

            let displayTitle = arabicWater ? "شرب ماء" : "Water Intake"
            return ParsedNutritionResult(
                type: .water(amountML: extractedAmount),
                title: displayTitle,
                calories: 0,
                proteinG: 0,
                carbsG: 0,
                fatG: 0,
                waterML: extractedAmount,
                summary: arabicWater
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

        // 4. Fuzzy database search for branded fast food, staples, and Egyptian favorites.
        if let item = databaseMatch(in: lower) {
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

        // 5. Intelligent NLP Fallback for unlisted meal descriptions
        let extractedNumber = extractFirstNumber(from: lower)

        let dietaryContextWords = [
            "eat", "ate", "had", "food", "meal", "snack", "breakfast", "lunch", "dinner", "supper",
            "drink", "drank", "cup", "plate", "bowl", "slice", "serving", "portion", "piece",
            "bread", "sandwich", "rice", "chicken", "beef", "meat", "fish", "soup", "salad",
            "calories", "kcal", "protein", "carbs", "fat", "grams",
            "أكل", "أكلت", "تناولت", "شرب", "شربت", "فطار", "غدا", "عشا", "سناك", "وجبة",
            "طبق", "كوب", "كوباية", "قطعة", "شريحة", "رغيف", "عيش", "ساندوتش", "سندوتش",
            "رز", "فراخ", "لحمة", "سمك", "شوربة", "سلطة", "سعرة", "سعرات", "بروتين", "كارب", "جرام"
        ]
        let hasDietaryContext = dietaryContextWords.contains(where: { lower.contains($0) })

        // If no nutrition number is provided and text has zero dietary keywords, it is not food
        if extractedNumber == nil && !hasDietaryContext {
            return ParsedNutritionResult(
                type: .food(title: "No Food Detected", calories: 0, proteinG: 0, carbsG: 0, fatG: 0),
                title: "No Food Detected",
                calories: 0,
                proteinG: 0,
                carbsG: 0,
                fatG: 0,
                waterML: 0,
                summary: "No food detected."
            )
        }

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

    /// The most specific database entry mentioned in the text, if any. The longest alias wins so
    /// "black coffee" beats "coffee" on the latte row.
    private func databaseMatch(in lower: String) -> FoodItemInfo? {
        foodDatabase
            .flatMap { item in
                item.aliases.filter { lower.contains($0) }.map { (item: item, aliasLength: $0.count) }
            }
            .max(by: { $0.aliasLength < $1.aliasLength })?
            .item
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
        // 1. Direct digits (e.g. 50, 100, 250, 500)
        let pattern = "\\d+"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            if let firstMatch = matches.first {
                let matchString = nsString.substring(with: firstMatch.range)
                if let val = Int(matchString) {
                    return val
                }
            }
        }

        // 2. Common spoken English & Arabic number words
        let wordNumbers: [(word: String, value: Int)] = [
            ("thousand", 1000), ("الف", 1000), ("ألف", 1000),
            ("nine hundred", 900), ("تسعمية", 900),
            ("eight hundred", 800), ("تمنمية", 800),
            ("seven hundred", 700), ("سبعمية", 700),
            ("six hundred", 600), ("ستمية", 600),
            ("five hundred", 500), ("خمسمية", 500),
            ("four hundred", 400), ("ربعمية", 400),
            ("three hundred", 300), ("تلتماية", 300),
            ("two hundred", 200), ("ميتين", 200), ("مائتين", 200),
            ("one hundred", 100), ("a hundred", 100), ("hundred", 100),
            ("ninety", 90), ("تسعين", 90),
            ("eighty", 80), ("تمانين", 80), ("ثمانين", 80),
            ("seventy", 70), ("سبعين", 70),
            ("sixty", 60), ("ستين", 60),
            ("fifty", 50), ("خمسين", 50),
            ("forty", 40), ("اربعين", 40), ("أربعين", 40),
            ("thirty", 30), ("تلاتين", 30), ("ثلاثين", 30),
            ("twenty five", 25), ("خمسة وعشرين", 25),
            ("twenty", 20), ("عشرين", 20),
            ("fifteen", 15), ("خمسطاشر", 15),
            ("ten", 10), ("عشرة", 10)
        ]

        for (word, val) in wordNumbers {
            if text.contains(word) {
                return val
            }
        }

        return nil
    }
}
