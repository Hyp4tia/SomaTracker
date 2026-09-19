//
//  SomaChatSession.swift
//  SomaTracker
//
//  The conversation with Soma. It owns the messages and sends everything through the app's existing
//  engines: the same router, the same write, the same free-scan accounting. How a log is produced does
//  not change here; the chat is another way to reach it.
//

import Foundation
import Observation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// Backs the settings switch. Off means the AI tab behaves exactly as it did before this surface
/// existed, because the overlay never mounts.
enum SomaChatSettings {
    static let surfaceKey = "soma_chat_surface"
}

extension SomaChatIntent {
    /// Whether answering this costs an engine call. The day's own numbers, the streak and today's meals
    /// come from the store, so a free user keeps them; a log or a question that needs an engine does not.
    var needsEntitlement: Bool {
        switch self {
        case .status, .streak, .today: return false
        case .log, .ask, .advice: return true
        }
    }
}

@Observable
final class SomaChatSession {
    private(set) var messages: [SomaChatMessage] = []
    var input = ""
    private(set) var isThinking = false
    private(set) var thinkingLabel = "Reading your log"

    /// Photos attached but not sent yet.
    var pendingPhotos: [Data] = []
    /// Bumped on every send and clear. A photo load that started before the bump is discarded rather
    /// than appended to the next message, which is how photos used to ride along with the wrong send.
    private var attachGeneration = 0
    var pickerItems: [PhotosPickerItem] = [] {
        didSet { Task { await loadPickedItems() } }
    }

    /// Set when the paywall has to come up. The surface presents it and clears the flag.
    var needsPaywall = false

    struct VoiceAttachment {
        let relativePath: String?
        let samples: [Float]
        let duration: TimeInterval
    }

    private let router = AIRouter.shared

    // MARK: - Sending

    func send(context: ModelContext, subscription: SubscriptionManager) async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let photos = pendingPhotos
        guard !text.isEmpty || !photos.isEmpty else { return }
        guard subscription.canUseAIFeatures else {
            needsPaywall = true
            return
        }

        // An attached photo is the meal itself, whatever the words around it say.
        let intent: SomaChatIntent = photos.isEmpty ? SomaChatIntentClassifier.classify(text) : .log

        // "How many calories left" is answered from the store, so the paywall does not stand in front of
        // it. Only work that reaches an engine needs the subscription.
        if intent.needsEntitlement, !subscription.canUseAIFeatures {
            needsPaywall = true
            return
        }

        messages.append(.user(text: text, photos: photos))
        input = ""
        pendingPhotos = []
        attachGeneration += 1

        await handle(intent: intent, text: text, photos: photos, voice: nil, context: context, subscription: subscription)
    }

    func sendVoice(
        transcript: String,
        audioRelativePath: String?,
        alternatives: [String],
        samples: [Float],
        duration: TimeInterval,
        context: ModelContext,
        subscription: SubscriptionManager
    ) async {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        // Nothing was heard. Say so and drop the recording rather than sending silence to an engine and
        // leaving the file behind.
        guard !text.isEmpty else {
            if let audioRelativePath {
                let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                try? FileManager.default.removeItem(at: documents.appendingPathComponent(audioRelativePath))
            }
            messages.append(.notice(SpeechLanguage.resolved() == .arabic
                                    ? "مسمعتش حاجة. جرّب تاني وأتكلم عن وجبتك."
                                    : "I didn't catch anything. Try again and describe the meal."))
            return
        }

        let intent = SomaChatIntentClassifier.classify(text)
        if intent.needsEntitlement, !subscription.canUseAIFeatures {
            needsPaywall = true
            return
        }

        let voice = VoiceAttachment(relativePath: audioRelativePath, samples: samples, duration: duration)
        messages.append(.user(
            text: text,
            voiceRelativePath: audioRelativePath,
            voiceDuration: duration,
            voiceWaveformSamples: samples
        ))

        await handle(
            intent: intent,
            text: text,
            photos: [],
            voice: voice,
            alternatives: alternatives,
            context: context,
            subscription: subscription
        )
    }

    private func handle(
        intent: SomaChatIntent,
        text: String,
        photos: [Data],
        voice: VoiceAttachment?,
        alternatives: [String] = [],
        context: ModelContext,
        subscription: SubscriptionManager
    ) async {
        switch intent {
        case .status(let metric):
            // Answered from the log itself: no engine, no cost, and the same words Siri uses.
            messages.append(.answer(SomaToday(context: context).answer(for: metric)))

        case .streak:
            messages.append(.answer(SomaToday.streakAnswer(context: context)))

        case .today:
            messages.append(.answer(SomaToday(context: context).todayMealsAnswer))

        case .ask:
            await answerQuestion(text: text, photos: photos, subscription: subscription)

        case .advice:
            await advise(text: text, context: context)

        case .log:
            await analyze(
                text: text,
                photos: photos,
                voice: voice,
                alternatives: alternatives,
                context: context,
                subscription: subscription
            )
        }
    }

    // MARK: - Answers

    /// A question is answered, never written. The numbers come from the same engine a log would use, but
    /// the journal only changes if the user taps "Log this".
    private func answerQuestion(text: String, photos: [Data], subscription: SubscriptionManager) async {
        // The app's database answers for free when it knows the dish: exact numbers, no model call, no
        // cost, no waiting. The engines are only asked about dishes it does not know.
        if photos.isEmpty, let local = localDishAnswer(for: text) {
            messages.append(local)
            return
        }

        guard subscription.canUseAIFeatures else {
            needsPaywall = true
            return
        }

        isThinking = true
        thinkingLabel = SpeechLanguage.resolved() == .arabic ? "بفكر" : "Working that out"
        defer { isThinking = false }

        let analysis = await router.processMultimodalMeal(
            notes: text,
            photos: photos,
            audioURL: nil,
            directTranscription: nil,
            alternativeTranscriptions: []
        )

        if analysis.isNoFood || analysis.title == "No Food Detected" {
            messages.append(.notice(noFoodMessage))
            return
        }

        messages.append(.analysis(analysis, linkedEntryID: nil, isLogged: false))
    }

    /// Guidance is answered, never written. It carries the pages behind it when the web was searched.
    private func advise(text: String, context: ModelContext) async {
        isThinking = true
        thinkingLabel = SpeechLanguage.resolved() == .arabic ? "بفكر في يومك" : "Thinking about your day"
        defer { isThinking = false }

        // The digest is read here, on the main actor, because advice is about today's store.
        let day = SomaDayContext.build(context: context)
        let answer = await SomaChatAdvisor.answer(question: text, day: day)
        messages.append(.answer(answer.text, sources: answer.sources))
    }

    /// The app's own numbers for a dish it knows, as a reply the user can log. Marked as a fallback
    /// answer so the cloud review does not spend a call checking numbers that came from the app's own
    /// table.
    private func localDishAnswer(for text: String) -> SomaChatMessage? {
        let parsed = FoodNutritionDatabase.shared.parseInput(text)
        guard parsed.title != "No Food Detected" else { return nil }

        if parsed.isWater, parsed.waterML > 0 {
            return .analysis(
                AIMealAnalysisResult(
                    title: parsed.title,
                    location: "",
                    storyNarrative: parsed.summary,
                    calories: 0,
                    proteinG: 0,
                    carbsG: 0,
                    fatG: 0,
                    waterML: parsed.waterML,
                    confidence: 1,
                    items: [],
                    engine: .onDeviceFallback
                ),
                linkedEntryID: nil,
                isLogged: false
            )
        }

        guard parsed.calories > 0 else { return nil }
        return .analysis(
            AIMealAnalysisResult(
                title: parsed.title,
                location: "",
                storyNarrative: parsed.summary,
                calories: parsed.calories,
                proteinG: parsed.proteinG,
                carbsG: parsed.carbsG,
                fatG: parsed.fatG,
                waterML: 0,
                confidence: 1,
                items: [],
                engine: .onDeviceFallback
            ),
            linkedEntryID: nil,
            isLogged: false
        )
    }

    // MARK: - The log path

    private func analyze(
        text: String,
        photos: [Data],
        voice: VoiceAttachment?,
        alternatives: [String],
        context: ModelContext,
        subscription: SubscriptionManager
    ) async {
        // Hydration is exact from the local parser, so it skips every engine and never spends a scan.
        if photos.isEmpty {
            let local = FoodNutritionDatabase.shared.parseInput(text)
            if local.isWater {
                logWater(amountML: local.waterML, story: text, summary: local.summary, photos: [], voice: voice, context: context)
                return
            }
        }

        isThinking = true
        thinkingLabel = photos.isEmpty ? "Reading your log" : "Reading your photo"
        defer { isThinking = false }

        let analysis = await router.processMultimodalMeal(
            notes: text,
            photos: photos,
            audioURL: nil,
            directTranscription: text.isEmpty ? nil : text,
            alternativeTranscriptions: alternatives
        )

        if analysis.isNoFood || analysis.title == "No Food Detected" {
            messages.append(.notice(analysis.engine == .onDeviceFallback ? unreachableMessage : noFoodMessage))
            return
        }

        if analysis.isWaterLog {
            logWater(
                amountML: analysis.waterML,
                story: text,
                summary: analysis.storyNarrative.isEmpty ? analysis.title : analysis.storyNarrative,
                photos: photos,
                voice: voice,
                context: context
            )
            return
        }

        guard let written = SomaLogWriter.writeMeal(
            analysis,
            photos: photos,
            voiceRelativePath: voice?.relativePath,
            voiceWaveformSamples: voice?.samples ?? [],
            voiceDuration: voice?.duration ?? 0,
            mealType: "Soma Chat",
            context: context
        ) else {
            messages.append(.notice(saveFailedMessage))
            return
        }

        subscription.consumeFreeScanIfFreeUser()
        messages.append(.analysis(analysis, linkedEntryID: written.aiEntry.id, isLogged: true))

        // The same after-care the tab does: a real location, Health, and the cloud review.
        await finish(written: written, analysis: analysis, input: text, context: context)
    }

    /// Writes an answered question into the journal, on the user's say so.
    func log(message: SomaChatMessage, context: ModelContext, subscription: SubscriptionManager) async {
        // The live copy, not the one this button was rendered with: a second tap arrives holding a
        // version from before the first write finished, and writing twice would double the entry and
        // spend two scans.
        guard let index = messages.firstIndex(where: { $0.id == message.id }),
              !messages[index].isLogged else { return }
        let message = messages[index]

        guard subscription.canUseAIFeatures else {
            needsPaywall = true
            return
        }

        if message.waterML > 0 {
            logWater(amountML: message.waterML, story: message.text, summary: message.title, photos: [], voice: nil, context: context)
            markLogged(message)
            return
        }

        let analysis = AIMealAnalysisResult(
            title: message.title,
            location: message.location,
            storyNarrative: message.text,
            calories: message.calories,
            proteinG: message.proteinG,
            carbsG: message.carbsG,
            fatG: message.fatG,
            waterML: 0,
            confidence: 0.9,
            items: [],
            engine: message.engine
        )

        guard let written = SomaLogWriter.writeMeal(analysis, photos: [], mealType: "Soma Chat", context: context) else {
            messages.append(.notice(saveFailedMessage))
            return
        }

        subscription.consumeFreeScanIfFreeUser()
        markLogged(message, entryID: written.aiEntry.id)
        await finish(written: written, analysis: analysis, input: message.title, context: context)
    }

    private func markLogged(_ message: SomaChatMessage, entryID: UUID? = nil) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        messages[index].isLogged = true
        if let entryID { messages[index].linkedEntryID = entryID }
    }

    /// Location, Health, and the cloud review, then the bubble catches up with whatever the entry ended
    /// up saying. A correction shows here instead of leaving the chat and the journal disagreeing.
    private func finish(
        written: SomaLogWriter.Written,
        analysis: AIMealAnalysisResult,
        input: String,
        context: ModelContext
    ) async {
        let resolved = await LocationService.shared.fetchCurrentLocation()
        let entry = written.aiEntry

        // A placeholder is not a venue: the same rule the AI tab applies, from one place.
        if let named = SomaLogWriter.realLocation(analysis.location) {
            if !resolved.isEmpty, !named.contains(resolved) {
                entry.location = "\(named) · \(resolved)"
            }
        } else if !resolved.isEmpty {
            entry.location = resolved
        }
        do {
            try context.save()
        } catch {
            print("[SomaChat] Location patch not saved: \(error.localizedDescription)")
        }

        await HealthSyncService.shared.syncDay(written.dailyLog)

        await AIFactCheckService.review(
            input: input,
            analysis: analysis,
            foodEntry: written.foodEntry,
            aiEntry: entry,
            context: context
        )

        guard let index = messages.lastIndex(where: { $0.linkedEntryID == entry.id }) else { return }
        messages[index].calories = entry.calories
        messages[index].proteinG = entry.proteinG
        messages[index].carbsG = entry.carbsG
        messages[index].fatG = entry.fatG
        messages[index].location = entry.location
        messages[index].text = entry.breakdownNotes
    }

    private func logWater(
        amountML: Int,
        story: String,
        summary: String,
        photos: [Data],
        voice: VoiceAttachment?,
        context: ModelContext
    ) {
        let entry = AIMealEntry.logHydration(
            amountML: amountML,
            story: story,
            summary: summary,
            photos: photos,
            voiceRelativePath: voice?.relativePath,
            waveformSamples: voice?.samples ?? [],
            duration: voice?.duration ?? 0,
            in: context
        )

        // logHydration inserts but deliberately does not save, so the chat saves it here the way the AI
        // tab does after its own hydration path.
        do {
            try context.save()
        } catch {
            print("[SomaChat] Couldn't save the water log: \(error.localizedDescription)")
            messages.append(.notice(saveFailedMessage))
            return
        }

        messages.append(.hydration(entry))
        Task { await HealthSyncService.shared.syncDay(DailyLog.fetchOrCreateToday(context: context)) }
    }

    /// Empties the conversation. The journal is untouched, since the logs themselves are the record.
    /// Refused while an engine is mid-answer, because the reply would land in a conversation the user
    /// believes they emptied.
    func clear() {
        guard !isThinking else { return }
        messages.removeAll()
        attachGeneration += 1
        pendingPhotos = []
    }

    // MARK: - Attachments

    private func loadPickedItems() async {
        guard !pickerItems.isEmpty else { return }
        let items = pickerItems
        let generation = attachGeneration
        pickerItems = []

        var loaded: [Data] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpeg = SomaImage.jpeg(from: image) else { continue }
            loaded.append(jpeg)
        }

        guard generation == attachGeneration else { return }

        // Five is the ceiling the cloud request is built for.
        pendingPhotos = Array((pendingPhotos + loaded).prefix(5))
    }

    func attach(image: UIImage) {
        guard let jpeg = SomaImage.jpeg(from: image) else { return }
        pendingPhotos = Array((pendingPhotos + [jpeg]).prefix(5))
    }

    // MARK: - Words

    private var unreachableMessage: String {
        SpeechLanguage.resolved() == .arabic
            ? "تعذر الوصول إلى Soma AI. حاول مرة أخرى."
            : "Couldn't reach Soma AI. Please try again."
    }

    private var noFoodMessage: String {
        SpeechLanguage.resolved() == .arabic
            ? "مش لاقي أكل في السجل ده."
            : "I couldn't find any food in that."
    }

    private var saveFailedMessage: String {
        SpeechLanguage.resolved() == .arabic
            ? "مقدرتش أحفظ السجل ده. حاول مرة أخرى."
            : "Soma couldn't save that. Please try again."
    }
}
