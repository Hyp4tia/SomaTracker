import Foundation

enum SomaChatMetric: Equatable {
    case calories
    case protein
    case water
    case steps
    case summary
}

enum SomaChatIntent: Equatable {
    case log
    case status(SomaChatMetric)
    case streak
    case today
    case ask
    case advice
}

enum SomaChatIntentClassifier {
    static func classify(_ input: String) -> SomaChatIntent {
        let normalized = normalize(input)
        let tokens = Set(normalized.split(separator: " ").map(String.init))

        if containsAny(normalized, ["streak", "سلسلة", "ستريك"]) {
            return .streak
        }

        let howToLog = containsAny(normalized, [
            "how do i log", "how to log", "where do i log", "how do i track",
            "ازاي اسجل", "اسجل ازاي", "إزاي أسجل", "أسجل إزاي"
        ])
        if howToLog {
            return .ask
        }

        let asksAboutPastLog = containsAny(normalized, [
            "did i log", "did i eat", "what did i log", "what did i eat",
            "سجلت ايه", "سجلت إيه", "اكلت ايه", "أكلت إيه"
        ])

        let reportingVerb = !asksAboutPastLog && (containsAny(normalized, [
            "i ate", "i had", "i drank", "i've eaten", "ive eaten", "logged",
            "اكلت", "أكلت", "شربت", "سجلت", "ضيف", "أضف"
        ]) || !tokens.isDisjoint(with: ["log", "track", "سجل", "سجّل"]))
        if reportingVerb {
            return .log
        }

        let dayReference = containsAny(normalized, [
            "today", "my day", "did i log", "did i eat", "have left", "left today",
            "remaining", "on track", "النهاردة", "اليوم", "اكلت ايه", "أكلت إيه",
            "فاضل كام", "باقي كام", "فاضل ايه", "باقي ايه"
        ])
        if dayReference {
            if containsAny(normalized, ["protein", "بروتين"]) { return .status(.protein) }
            if containsAny(normalized, ["water", "hydration", "مياه", "ماية", "ماء"]) { return .status(.water) }
            if containsAny(normalized, ["step", "steps", "خطوة", "خطوات"]) { return .status(.steps) }
            if containsAny(normalized, ["calorie", "calories", "kcal", "سعر", "كالوري"]) { return .status(.calories) }
            if containsAny(normalized, ["what did i eat", "what have i eaten", "did i eat", "did i log", "اكلت ايه", "أكلت إيه"]) { return .today }
            return .status(.summary)
        }

        if containsAny(normalized, [
            "what should i eat", "what can i eat", "suggest", "recommend", "healthy", "healthier",
            "اقترح", "اكل ايه", "أكل إيه", "اختارلي", "اخترلي", "انصحني", "صحي", "مفيد", "افضل", "أفضل"
        ]) {
            return .advice
        }

        let asksQuestion = input.contains("?") || input.contains("؟") || containsAny(normalized, [
            "compare", "difference", "قارن", "فرق"
        ]) || !tokens.isDisjoint(with: [
            "what", "how", "many", "much", "is", "are", "does", "do", "can", "should",
            "كام", "كم", "ايه", "إيه", "هل", "قد"
        ])
        if asksQuestion {
            return .ask
        }

        // Anything left is a statement Soma cannot place, and it is a question far more often than it
        // is an order to write: "burger calories", "protein 30g", "chicken rice". Logging must be
        // something the user actually said they ate or drank, never a guess from a stray food word.
        // When in doubt: answer, do not write.
        return .ask
    }

    private static func normalize(_ input: String) -> String {
        input
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: nil)
            .lowercased()
            .components(separatedBy: CharacterSet.punctuationCharacters)
            .joined(separator: " ")
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
    }

    private static func containsAny(_ text: String, _ phrases: [String]) -> Bool {
        phrases.contains { text.contains($0) }
    }
}
