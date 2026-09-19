//
//  SomaChatMessage.swift
//  SomaTracker
//
//  One turn in the conversation. Plain values only, so a bubble renders without touching SwiftData.
//

import Foundation

struct SomaChatMessage: Identifiable {
    enum Author {
        case user, soma
    }

    enum Kind {
        /// What the user sent.
        case user
        /// Soma's reply carrying macros: the result of a log.
        case analysis
        /// Soma's written reply: a status answer or advice.
        case answer
        /// Something went wrong, said plainly rather than logging a guess.
        case notice
    }

    let id = UUID()
    let kind: Kind
    let author: Author
    let timestamp = Date()

    var text = ""
    var photos: [Data] = []
    var voiceRelativePath: String?
    var voiceDuration: TimeInterval = 0
    /// The recording's own samples, so the chat draws the memo rather than a decorative pattern.
    var voiceWaveformSamples: [Float] = []

    var title = ""
    var location = ""
    var calories = 0
    var proteinG: Double = 0
    var carbsG: Double = 0
    var fatG: Double = 0
    var waterML = 0

    /// The journal entry this reply created, so a later correction or deletion can find it.
    var linkedEntryID: UUID?

    /// True once the numbers are in the journal. An answered question starts false and offers to log.
    var isLogged = false

    /// Which engine answered, so logging an answered question later still reports the truth.
    var engine: AIMealAnalysisResult.Engine = .onDevice

    /// Pages the answer came from, when the web was searched for it.
    var sources: [SomaWebSource] = []

    static func user(
        text: String,
        photos: [Data] = [],
        voiceRelativePath: String? = nil,
        voiceDuration: TimeInterval = 0,
        voiceWaveformSamples: [Float] = []
    ) -> SomaChatMessage {
        SomaChatMessage(
            kind: .user,
            author: .user,
            text: text,
            photos: photos,
            voiceRelativePath: voiceRelativePath,
            voiceDuration: voiceDuration,
            voiceWaveformSamples: voiceWaveformSamples
        )
    }

    static func analysis(_ analysis: AIMealAnalysisResult, linkedEntryID: UUID?, isLogged: Bool) -> SomaChatMessage {
        SomaChatMessage(
            kind: .analysis,
            author: .soma,
            text: analysis.storyNarrative,
            title: analysis.title,
            location: analysis.location,
            calories: analysis.calories,
            proteinG: analysis.proteinG,
            carbsG: analysis.carbsG,
            fatG: analysis.fatG,
            waterML: analysis.waterML,
            linkedEntryID: linkedEntryID,
            isLogged: isLogged,
            engine: analysis.engine
        )
    }

    static func hydration(_ entry: AIMealEntry) -> SomaChatMessage {
        SomaChatMessage(
            kind: .analysis,
            author: .soma,
            text: entry.storyText,
            title: entry.title,
            location: entry.location,
            waterML: entry.waterML,
            linkedEntryID: entry.id,
            isLogged: true,
            engine: .onDevice
        )
    }

    static func answer(_ text: String, sources: [SomaWebSource] = []) -> SomaChatMessage {
        SomaChatMessage(kind: .answer, author: .soma, text: text, sources: sources)
    }

    static func notice(_ text: String) -> SomaChatMessage {
        SomaChatMessage(kind: .notice, author: .soma, text: text)
    }
}
