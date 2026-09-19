//
//  SomaChatAdvisor.swift
//  SomaTracker
//
//  Advice questions: "what should I eat tonight", "am I on track". Two sources of truth feed it, and
//  both are the user's: their own history and day, from this app, and the live web for what is actually
//  available where they are.
//
//  The order is deliberate. Live search first when it can work, because it is the only path that can
//  look outside the app. Then Apple's on-device model, which is instant and free. Then the cloud without
//  search. Then the numbers themselves, which are always true even when nobody can answer.
//

import Foundation

enum SomaChatAdvisor {
    /// Backs the settings switch. Advice still works with search off; it just stops looking outside.
    static let searchKey = "soma_advice_web_search"

    /// When search cannot run, remember it for a day rather than paying for a doomed attempt on every
    /// question: grounding with Google Search is a paid-tier feature, so an unbilled project refuses it.
    private static let searchRetryKey = "soma_advice_search_retry_after"

    static var searchEnabled: Bool {
        UserDefaults.standard.object(forKey: searchKey) as? Bool ?? true
    }

    private static var searchWorthTrying: Bool {
        guard searchEnabled else { return false }
        guard let retryAfter = UserDefaults.standard.object(forKey: searchRetryKey) as? Date else { return true }
        return Date() >= retryAfter
    }

    private static func noteSearchUnavailable() {
        UserDefaults.standard.set(Date().addingTimeInterval(24 * 3_600), forKey: searchRetryKey)
    }

    private static func noteSearchWorking() {
        UserDefaults.standard.removeObject(forKey: searchRetryKey)
    }

    @MainActor
    static func answer(question: String, day: SomaDayContext) async -> SomaAIAnswer {
        let language = SpeechLanguage.resolved()
        let cloudReady = APIConfiguration.shared.hasCloudVisionReady

        if searchWorthTrying, cloudReady {
            do {
                let searched = try await GeminiAIService().answer(
                    systemInstruction: instruction(for: language, webSearch: true),
                    question: "\(day.promptDigest)\n\nThe user asks: \(question)",
                    searchGrounding: true
                )
                if searched.usedSearch, !searched.text.isEmpty {
                    noteSearchWorking()
                    return searched
                }
                noteSearchUnavailable()
            } catch {
                #if DEBUG
                print("[SomaChatAdvisor] Live search did not run: \(error.localizedDescription)")
                #endif
                noteSearchUnavailable()
            }
        }

        // Apple's model: instant, free, and the numbers never leave the phone.
        if OnDeviceAISettings.isEnabled,
           let local = await OnDeviceAIService.shared.answer(
                question: question,
                digest: day.promptDigest,
                outputLanguage: language
           ) {
            return SomaAIAnswer(text: local, sources: [], usedSearch: false)
        }

        if cloudReady,
           let cloud = try? await GeminiAIService().answer(
                systemInstruction: instruction(for: language, webSearch: false),
                question: "\(day.promptDigest)\n\nThe user asks: \(question)"
           ),
           !cloud.text.isEmpty {
            return cloud
        }

        return SomaAIAnswer(text: fallback(day: day, language: language), sources: [], usedSearch: false)
    }

    static func instruction(for language: SpeechLanguage, webSearch: Bool) -> String {
        let searchRule = webSearch
            ? "6. You may search the web for what is actually available near the user: restaurants, brands, menu items, delivery apps. Name the place or brand when a result comes from a search."
            : "6. You cannot search the web for this answer, so stay with dishes you are sure exist where the user lives."

        return """
        You are Soma, the assistant inside the user's own food and hydration journal. You can see the user's numbers below and nothing else about them.
        Write in \(language.analysisLanguageName).
        Rules:
        1. Use ONLY the numbers given to you. Never invent a number, a goal, or a food the user has not eaten.
        2. Prefer what this person already eats. When one of Soma's own options fits what is left, suggest it and keep its numbers exactly as written.
        3. Be practical: two or three specific dishes or snacks that fit the calories and protein left.
        4. If little is left, say so plainly and suggest something light. If protein is short, favour protein.
        5. Two to four short sentences. No headings, no bullet lists, no percentages.
        \(searchRule)
        7. Sound like a helpful friend, not a disclaimer. Mention that you are not a doctor only when the question is actually medical.
        """
    }

    private static func fallback(day: SomaDayContext, language: SpeechLanguage) -> String {
        if language == .arabic {
            return "مش قادر أوصل لـ Soma AI دلوقتي. عندك \(day.remainingCalories) كالوري و\(day.remainingProteinG) جرام بروتين باقيين النهاردة."
        }
        return "I can't reach Soma AI right now. You have \(day.remainingCalories) kcal and \(day.remainingProteinG) g of protein left today."
    }
}
