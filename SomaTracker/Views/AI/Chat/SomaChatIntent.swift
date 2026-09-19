//
//  SomaChatIntent.swift
//  SomaTracker
//
//  What the user meant. Logging is the app's main job, so a sentence that reports eating keeps the log
//  path. A question is never written to the journal, and the ordering below is the whole reason why:
//  logging verbs used to be checked first, so "how many calories did I log today" was recorded as a
//  400 kcal entry instead of answered.
//

import Foundation

enum SomaChatIntent: Equatable {
    /// A meal, a drink, or anything the user wants recorded.
    case log
    /// A question about the user's own day, answerable from the log with no engine involved.
    case status(NutritionMetric)
    /// The streak is its own question: it is not one of the day's meters.
    case streak
    /// "What did I eat today": answered by naming today's meals, from the store, with no engine.
    case today
    /// A question about food or the day that needs numbers: answered, not logged.
    case ask
    /// A question asking for guidance: answered from the user's own day, and from the web when search is
    /// available.
    case advice
}

enum SomaChatIntentClassifier {
    /// Words that talk about the user's own day rather than about a dish. "log" and "سجل" are here so a
    /// question like "how much water did I log" resolves to the day's water instead of a dish lookup.
    private static let dayWords: Set<String> = [
        "left", "remaining", "remain", "so", "far", "eaten", "ate", "eat", "eats", "eating", "consumed",
        "had", "have", "having", "today", "day", "week", "month", "goal", "target", "progress", "doing",
        "logged", "log", "track",
        "باقي", "باقى", "باقية", "متبقي", "متبقى", "فاضل", "فاضلة", "النهاردة", "النهارده", "اليوم",
        "يوم", "أسبوع", "اسبوع", "شهر", "هدف", "وصلت", "سجل", "سجلت", "اكلت", "شربت", "دخل"
    ]

    private static let questionWords: Set<String> = [
        "how", "what", "whats", "which", "should", "can", "could", "do", "does", "did", "is", "are",
        "am", "was", "were", "will", "would", "where", "when", "why", "tell", "show", "give", "know",
        "كم", "كام", "قد", "ايه", "إيه", "فين", "كيف", "ازاي", "إزاي", "هل", "ليه", "يعني", "قولي",
        "وريني", "اعرف", "ممكن"
    ]

    /// Verbs that ask for a record to be written, when the sentence is not a question.
    private static let loggingWords: Set<String> = [
        "log", "logged", "add", "record", "track",
        "سجل", "سجلي", "ضيف", "اضف", "أضف", "اكتب"
    ]

    /// Wording that asks for a suggestion rather than a fact.
    private static let adviceWords: Set<String> = [
        "should", "suggest", "suggestion", "suggestions", "recommend", "recommendation", "idea", "ideas",
        "help", "advice", "healthy", "better", "instead", "plan",
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

    /// Past-tense reporting. A sentence built on one of these is a log even when it also contains
    /// advice-sounding words, which "I ate a healthy salad" did not used to be.
    private static let reportingVerbs: Set<String> = [
        "ate", "eaten", "had", "drank", "finished",
        "اكلت", "أكلت", "كلت", "شربت", "فطرت", "اتغديت", "اتعشيت", "نهشت"
    ]

    /// Meal names are nouns, so they can belong to a question ("suggest a high protein dinner") and must
    /// not by themselves make a sentence a log.
    private static let mealNouns: Set<String> = ["breakfast", "lunch", "dinner", "snack", "فطار", "غدا", "عشا"]

    /// Asking what was eaten, which the store can answer in one line without an engine.
    private static let eatingAsked: Set<String> = ["eat", "ate", "eaten", "drank", "اكلت", "أكلت", "شربت"]

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

    /// Arabic punctuation lives inside the range the tokenizer keeps, which left "كشري؟" as a single
    /// token with no question mark to detect. Punctuation is stripped before tokenizing instead.
    private static func words(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet(charactersIn: "؟?،,؛;.!!"))
            .joined(separator: " ")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "\u{0600}-\u{06FF}")).inverted)
            .filter { !$0.isEmpty }
    }

    static func classify(_ text: String) -> SomaChatIntent {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .log }

        let tokens = words(trimmed)
        let tokenSet = Set(tokens)

        // Arabic writes its own question mark, and Siri dictates one-word questions with it.
        let endsWithQuestion = trimmed.hasSuffix("?") || trimmed.hasSuffix("؟")
        let hasQuestionWord = containsAny(questionWords, in: tokenSet)
        let reportsEating = containsAny(reportingVerbs, in: tokenSet)
        let namedMetric = metric(in: tokenSet)
        let infoAsked = containsAny(infoWords, in: tokenSet)
        let mentionsDay = containsAny(dayWords, in: tokenSet)
        let wantsAdvice = containsAny(adviceWords, in: tokenSet)
            || advicePhrases.contains { containsPhrase($0, in: tokens) }

        // 0. A sentence that opens with a logging verb is an instruction: "log 500 calories" and
        //    "track 250 water" must not be read as questions just because they contain a metric.
        if let first = tokens.first, containsAny(loggingWords, in: [first]), !endsWithQuestion, !hasQuestionWord {
            return .log
        }

        // 1. Reporting a meal is a log, unless the sentence is actually a question. Checked before
        //    everything else, and deliberately not gated on advice words: "I ate a healthy salad" and
        //    "I had salad instead of pasta" are meals, however they are worded.
        if reportsEating, !endsWithQuestion, !hasQuestionWord {
            return .log
        }

        // 2. An explicit request to record, when it is not phrased as a question. "how many calories did
        //    I log today" contains "log" and must not land here, which is the bug this ordering fixes.
        let asksAboutFoodOrDay = endsWithQuestion || hasQuestionWord || infoAsked
            || (namedMetric != nil && namedMetric != .water)
        if !asksAboutFoodOrDay, containsAny(loggingWords, in: tokenSet) {
            return .log
        }

        // 3. Guidance, which is a question even when it reads as an instruction.
        if wantsAdvice { return .advice }

        // 4. Anything left is a log: a bare dish name, a portion, a drink.
        guard asksAboutFoodOrDay else { return .log }

        if containsAny(["streak", "ستريك", "سلسلة"], in: tokenSet) { return .streak }

        if let metric = namedMetric, mentionsDay { return .status(metric) }

        if namedMetric != nil { return .ask }

        // 5. "What did I eat today" is a question about today's own meals, which the store answers exactly
        //    and for free. It is checked before any dish lookup, because the parser happily finds food in
        //    a sentence like this one.
        if containsAny(eatingAsked, in: tokenSet), mentionsDay { return .today }

        // 6. A question that names a dish gets its numbers, with the option to log it: the app's own
        //    database decides first, and failing that, wording like "burger info" or "كلمني عن البرجر" is
        //    a lookup as long as the question is not about the user's own day.
        if FoodNutritionDatabase.shared.parseInput(tokens.joined(separator: " ")).title != "No Food Detected" {
            return .ask
        }
        if infoAsked, !mentionsDay { return .ask }

        // 7. A short question that named nothing else is asking about whatever it named: "برجر؟".
        if tokens.count <= 2 { return .ask }

        // 8. Otherwise it is open, and the day's numbers are the answer.
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
