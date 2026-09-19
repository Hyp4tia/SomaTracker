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
}

enum SomaChatIntentClassifier {
    /// Words that talk about the user's own day rather than about a dish.
    private static let dayWords: Set<String> = [
        "left", "remaining", "remain", "so", "far", "eaten", "ate", "consumed", "had", "today",
        "goal", "target", "progress", "doing", "logged", "track",
        "باقي", "باقى", "باقية", "متبقي", "متبقى", "فاضل", "فاضلة", "النهاردة", "النهارده", "اليوم",
        "هدف", "وصلت", "سجلت", "اكلت", "دخل"
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
    private static func contains(_ keyword: String, in tokens: Set<String>) -> Bool {
        if tokens.contains(keyword) { return true }
        guard keyword.unicodeScalars.contains(where: { $0.value > 0x7F }) else { return false }
        return tokens.contains { $0.hasPrefix(keyword) }
    }

    private static func containsAny(_ keywords: Set<String>, in tokens: Set<String>) -> Bool {
        keywords.contains { contains($0, in: tokens) }
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
        let isQuestion = trimmed.hasSuffix("?") || containsAny(questionWords, in: tokenSet)

        guard isQuestion else { return .log }

        // "log a burger" is a request to record, even though it reads like an instruction.
        if containsAny(loggingWords, in: tokenSet) { return .log }

        if containsAny(["streak", "ستريك", "سلسلة"], in: tokenSet) {
            return .streak
        }

        if let metric = metric(in: tokenSet), containsAny(dayWords, in: tokenSet) {
            return .status(metric)
        }

        return .ask
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
