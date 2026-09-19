//
//  SomaChatIntent.swift
//  SomaTracker
//
//  What the user meant. Logging is the app's main job, so anything that is not clearly a question keeps
//  the log path it has always had. A question is never written to the journal: "how many calories in a
//  burger" is asking, not eating.
//

import Foundation

enum SomaChatIntent: Equatable {
    /// A meal, a drink, or anything the user wants recorded.
    case log
    /// A question about the user's own day, answerable from the log with no engine involved.
    case status(NutritionMetric)
    /// The streak is its own question: it is not one of the day's meters.
    case streak
    /// A question about food or the day that needs numbers: answered, not logged.
    case ask
    /// A question asking for guidance: answered from the user's own day, and from the web when search is
    /// available.
    case advice
}

enum SomaChatIntentClassifier {
    /// Words that talk about the user's own day rather than about a dish.
    private static let dayWords: Set<String> = [
        "left", "remaining", "remain", "so", "far", "eaten", "ate", "eat", "eats", "eating", "consumed",
        "had", "have", "having", "today", "day", "week", "month", "goal", "target", "progress", "doing",
        "logged", "track",
        "باقي", "باقى", "باقية", "متبقي", "متبقى", "فاضل", "فاضلة", "النهاردة", "النهارده", "اليوم",
        "يوم", "أسبوع", "اسبوع", "شهر", "هدف", "وصلت", "سجلت", "اكلت", "شربت", "دخل"
    ]

    private static let questionWords: Set<String> = [
        "how", "what", "whats", "which", "should", "can", "could", "do", "does", "did", "is", "are",
        "am", "was", "were", "will", "would", "where", "when", "why", "tell", "show", "give", "know",
        "كم", "كام", "قد", "ايه", "إيه", "فين", "كيف", "ازاي", "إزاي", "هل", "ليه", "يعني", "قولي",
        "وريني", "اعرف", "ممكن"
    ]

    /// Verbs that ask for a record to be written, whatever else the sentence contains.
    private static let loggingWords: Set<String> = [
        "log", "logged", "add", "record", "track",
        "سجل", "سجلي", "ضيف", "اضف", "أضف", "اكتب"
    ]

    /// Arabic glues its suffixes onto a word, so the user's "my streak" arrives as "ستريكي" and the
    /// keyword "ستريك" would miss it. Latin keywords stay exact, because English does not do that and a
    /// prefix rule would start matching words like "ate" inside longer ones.
    /// Wording that asks for a suggestion rather than a fact.
    /// "اكل" and "آكل" are deliberately absent: "اكلت كشري" (I ate koshary) is the app's most common log,
    /// and an Arabic prefix rule would read that as asking for advice. The open-question fallback below
    /// catches "اكل ايه" instead. "track" is absent for the same reason, and "on track" is matched as a
    /// phrase.
    private static let adviceWords: Set<String> = [
        "should", "suggest", "suggestion", "suggestions", "recommend", "recommendation", "idea", "ideas",
        "help", "advice", "healthy", "better", "instead", "doing", "progress", "plan",
        "أنصحني", "انصحني", "اقترح", "اقترحي", "رايك", "رأيك", "اعمل", "أعمل",
        "افضل", "أفضل", "احسن", "أحسن", "بديل", "صحي", "صحية", "نصيحة", "ساعدني"
    ]

    /// Ordered phrases, because one of these words alone means something else.
    private static let advicePhrases: [[String]] = [["on", "track"]]

    /// Nouns that ask about a dish rather than reporting one. "Burger info" was logged as a burger,
    /// because a food word with no verb and no question mark looked like a log.
    private static let infoWords: Set<String> = [
        "info", "information", "details", "detail", "about", "nutrition", "macros", "breakdown",
        "ingredients", "facts", "review", "معلومات", "تفاصيل", "مكونات", "عن"
    ]

    /// Verbs and nouns that report an actual meal, which is what makes a sentence a log.
    private static let consumptionWords: Set<String> = [
        "ate", "eat", "eaten", "eating", "had", "drank", "drink", "finished", "breakfast", "lunch", "dinner",
        "اكلت", "شربت", "كلت", "فطرت", "اتغديت", "اتعشيت", "نهشت"
    ]

    private static func contains(_ keyword: String, in tokens: Set<String>) -> Bool {
        if tokens.contains(keyword) { return true }
        guard keyword.unicodeScalars.contains(where: { $0.value > 0x7F }) else { return false }
        return tokens.contains { $0.hasPrefix(keyword) }
    }

    private static func containsAny(_ keywords: Set<String>, in tokens: Set<String>) -> Bool {
        keywords.contains { contains($0, in: tokens) }
    }

    private static func containsPhrase(_ phrase: [String], in tokens: [String]) -> Bool {
        guard !phrase.isEmpty, tokens.count >= phrase.count else { return false }
        for start in 0...(tokens.count - phrase.count) {
            if Array(tokens[start..<(start + phrase.count)]) == phrase { return true }
        }
        return false
    }


    private static func words(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "\u{0600}-\u{06FF}")).inverted)
            .filter { !$0.isEmpty }
    }

    static func classify(_ text: String) -> SomaChatIntent {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .log }

        let tokens = words(trimmed)
        let tokenSet = Set(tokens)
        // Asking for guidance counts even when it is phrased as an instruction, which "suggest a high
        // protein dinner" and "أنصحني بحاجة خفيفة" both are. It is worked out before the logging verbs
        // because "on track" is a question while "track 250 water" is a request to record.
        let wantsAdvice = containsAny(adviceWords, in: tokenSet)
            || advicePhrases.contains { containsPhrase($0, in: tokens) }

        // "log a burger" and "track 250 water" are requests to record, whatever else they contain.
        if !wantsAdvice, containsAny(loggingWords, in: tokenSet) { return .log }

        // A sentence that reports eating is a log, so it must not be read as a question just because it
        // mentions calories. Water is the exception to the metric rule: "مية" on its own is the app's
        // most common log, and asking about water always comes with a question word anyway.
        let describesEating = containsAny(consumptionWords, in: tokenSet)
        let namedMetric = metric(in: tokenSet)
        let asksAboutFood = containsAny(infoWords, in: tokenSet) || (namedMetric != nil && namedMetric != .water)

        let isQuestion = trimmed.hasSuffix("?")
            || wantsAdvice
            || containsAny(questionWords, in: tokenSet)
            || (!describesEating && asksAboutFood)

        guard isQuestion else { return .log }

        // Advice before a dish lookup: "what should I eat" mentions eating, and is not asking for numbers.
        if wantsAdvice {
            return .advice
        }

        if containsAny(["streak", "ستريك", "سلسلة"], in: tokenSet) {
            return .streak
        }

        if let metric = metric(in: tokenSet), containsAny(dayWords, in: tokenSet) {
            return .status(metric)
        }

        // A question that names a dish gets its numbers, with the option to log it: first the app's own
        // database decides, and failing that, wording like "burger info" or "كلمني عن البرجر" is a
        // lookup as long as the question is not about the user's own day.
        if namedMetric != nil { return .ask }
        if FoodNutritionDatabase.shared.parseInput(trimmed).title != "No Food Detected" { return .ask }
        if containsAny(infoWords, in: tokenSet), !containsAny(dayWords, in: tokenSet) { return .ask }

        // Otherwise it is open, and the day's numbers are the answer.
        return .advice
    }

    private static func metric(in tokens: Set<String>) -> NutritionMetric? {
        if containsAny(["calories", "calorie", "kcal", "سعرة", "سعره", "سعرات", "كالوري", "كالورى"], in: tokens) {
            return .calories
        }
        if containsAny(["protein", "بروتين"], in: tokens) {
            return .protein
        }
        if containsAny(["water", "hydration", "مية", "ماء", "مياه", "موية"], in: tokens) {
            return .water
        }
        if containsAny(["steps", "step", "خطوات", "ستيبس"], in: tokens) {
            return .steps
        }
        return nil
    }
}
