import Foundation
import Observation
import SwiftData
import UIKit

@Observable
@MainActor
final class SomaChatSession {
    private(set) var messages: [SomaChatMessage] = []
    var input = ""
    private(set) var isThinking = false
    var needsPaywall = false
    var pendingPhotos: [Data] = []

    func attach(_ image: UIImage) {
        guard let data = SomaImage.jpeg(from: image) else { return }
        pendingPhotos = Array((pendingPhotos + [data]).prefix(5))
    }

    func removePendingPhoto(at index: Int) {
        guard pendingPhotos.indices.contains(index) else { return }
        pendingPhotos.remove(at: index)
    }

    func send(context: ModelContext, subscription: SubscriptionManager) async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let photos = pendingPhotos
        guard !text.isEmpty || !photos.isEmpty, !isThinking else { return }

        let intent = photos.isEmpty ? SomaChatIntentClassifier.classify(text) : .log
        let localWater = intent == .log ? FoodNutritionDatabase.shared.parseInput(text) : nil
        let needsEngine = intent.needsEngine && localWater?.isWater != true
        if needsEngine && !subscription.canUseAIFeatures {
            needsPaywall = true
            return
        }

        messages.append(.user(text, photos: photos))
        input = ""
        pendingPhotos = []

        switch intent {
        case .status(let metric):
            messages.append(.answer(SomaDayAnswers(context: context).answer(for: metric)))
        case .streak:
            messages.append(.answer(SomaDayAnswers(context: context).streakAnswer))
        case .today:
            messages.append(.answer(SomaDayAnswers(context: context).todayAnswer))
        case .ask:
            await answerNutrition(text, context: context, subscription: subscription)
        case .advice:
            await answerAdvice(text, day: SomaDayAnswers(context: context), subscription: subscription)
        case .log:
            await log(
                text,
                photos: photos,
                localParse: localWater,
                context: context,
                subscription: subscription
            )
        }
    }

    func clear() {
        guard !isThinking else { return }
        messages.removeAll()
        pendingPhotos = []
    }

    private func answerNutrition(
        _ text: String,
        context: ModelContext,
        subscription: SubscriptionManager
    ) async {
        isThinking = true
        defer { isThinking = false }

        let result = await AIRouter.shared.processMultimodalMeal(notes: text, photos: [], audioURL: nil)
        if !result.isNoFood {
            messages.append(.nutrition(result))
            subscription.consumeFreeScanIfFreeUser()
            return
        }

        do {
            let answer = try await GeminiAIService().answer(
                question: text,
                context: SomaDayAnswers(context: context).promptContext
            )
            guard !answer.isEmpty else { throw SomaChatError.emptyAnswer }
            messages.append(.answer(answer))
            subscription.consumeFreeScanIfFreeUser()
        } catch {
            messages.append(.notice("Couldn't reach Soma AI. Please try again."))
        }
    }

    private func answerAdvice(_ text: String, day: SomaDayAnswers, subscription: SubscriptionManager) async {
        isThinking = true
        defer { isThinking = false }

        do {
            let answer = try await GeminiAIService().answer(question: text, context: day.promptContext)
            guard !answer.isEmpty else { throw SomaChatError.emptyAnswer }
            messages.append(.answer(answer))
            subscription.consumeFreeScanIfFreeUser()
        } catch {
            messages.append(.notice("Couldn't reach Soma AI. Please try again."))
        }
    }

    private func log(
        _ text: String,
        photos: [Data],
        localParse: ParsedNutritionResult?,
        context: ModelContext,
        subscription: SubscriptionManager
    ) async {
        if photos.isEmpty, let local = localParse, local.isWater {
            guard let entry = SomaChatLogWriter.writeWater(
                amountML: local.waterML,
                input: text,
                summary: local.summary,
                context: context
            ) else {
                messages.append(.notice(saveFailedMessage))
                return
            }
            messages.append(.hydration(amountML: entry.waterML))
            await HealthSyncService.shared.syncDay(entry.dailyLog)
            return
        }

        isThinking = true
        defer { isThinking = false }

        let result = await AIRouter.shared.processMultimodalMeal(notes: text, photos: photos, audioURL: nil)
        guard !result.isNoFood else {
            messages.append(.notice("I couldn't find food to log. Try describing the meal and portion."))
            return
        }

        if result.isWaterLog {
            guard let entry = SomaChatLogWriter.writeWater(
                amountML: result.waterML,
                input: text,
                summary: result.storyNarrative,
                context: context
            ) else {
                messages.append(.notice(saveFailedMessage))
                return
            }
            messages.append(.hydration(amountML: entry.waterML))
            subscription.consumeFreeScanIfFreeUser()
            await HealthSyncService.shared.syncDay(entry.dailyLog)
            return
        }

        guard let written = SomaChatLogWriter.writeMeal(
            result,
            input: text,
            photos: photos,
            context: context
        ) else {
            messages.append(.notice(saveFailedMessage))
            return
        }
        messages.append(.receipt(result))
        subscription.consumeFreeScanIfFreeUser()
        isThinking = false
        await HealthSyncService.shared.syncDay(written.day)
        Task {
            await AIFactCheckService.review(
                input: text,
                analysis: result,
                foodEntry: written.foodEntry,
                aiEntry: written.aiEntry,
                context: context
            )
        }
    }

    private let saveFailedMessage = "Soma couldn't save that. Please try again."
}

private extension SomaChatIntent {
    var needsEngine: Bool {
        switch self {
        case .status, .streak, .today:
            return false
        case .log, .ask, .advice:
            return true
        }
    }
}

private enum SomaChatError: Error {
    case emptyAnswer
}
