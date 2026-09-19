//
//  OnDeviceAIService.swift
//  SomaTracker
//
//  Apple's own models as the first engine: the on-device one answers text and voice logs in a
//  fraction of a second, for free, with the user's words never leaving the iPhone, and reads photos
//  from iOS 27 onward. Anything it cannot do well escalates instead of showing a guess: either to
//  Apple's Private Cloud Compute model (opt-in, needs the entitlement) or to the cloud engine in
//  AIRouter.
//

import CoreGraphics
import Foundation
import FoundationModels
import ImageIO

/// Why a local attempt gave up. Every case escalates to the cloud, because a wrong log is worse
/// than a slower one.
enum AIEngineError: Error {
    /// No Apple Intelligence on this device, or the model is still downloading.
    case unavailable
    /// Photos before iOS 27, or raw audio: the local model cannot take that input.
    case unsupportedInput
    /// Apple Intelligence does not read the language of this log yet (Arabic today).
    case languageUnsupported
    /// The local answer took too long, so the cloud gets the turn.
    case timedOut
    /// The local answer did not hold together numerically.
    case inconsistentResult
    case generationFailed(String)
}

/// Who answers, and whether the cloud checks the answer. This used to be two switches,
/// "on-device analysis" and "fact-check with the cloud", which described the same traffic once both
/// were on: with either one, the cloud was involved in every log. One choice says it plainly.
enum AnalysisMode: String, CaseIterable, Identifiable {
    /// This iPhone answers, and the cloud model verifies what it said. The app's default.
    case localFirst
    /// The cloud answers everything. Nothing runs on this iPhone.
    case cloudFirst

    var id: String { rawValue }

    var title: String {
        switch self {
        case .localFirst: return "On-device first"
        case .cloudFirst: return "Cloud first"
        }
    }

    var detail: String {
        switch self {
        case .localFirst: return "Answered instantly on this iPhone, then checked by the cloud"
        case .cloudFirst: return "Every log is answered by the cloud, nothing runs locally"
        }
    }
}

enum OnDeviceAISettings {
    static let modeKey = "soma_analysis_mode"

    /// What the mode used to be stored as, read once for an install that predates this screen.
    private static let legacyOnDeviceKey = "soma_on_device_ai"

    static var mode: AnalysisMode {
        get {
            if let raw = UserDefaults.standard.string(forKey: modeKey),
               let stored = AnalysisMode(rawValue: raw) {
                return stored
            }
            // Anyone who had turned on-device analysis off keeps cloud-first behaviour.
            return UserDefaults.standard.object(forKey: legacyOnDeviceKey) as? Bool == false
                ? .cloudFirst
                : .localFirst
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: modeKey)
        }
    }

    /// True when this iPhone answers first, which is also when the cloud has something to review.
    /// Every call site reads this, so the mode is the single source of truth.
    static var isEnabled: Bool { mode == .localFirst }

    /// Photos take the cloud route by default. Gemini reads a plate in about two seconds and reads
    /// it better; the on-device model takes longer and guesses. This switch is for the person who
    /// would rather the photo never leave the iPhone and accept that trade.
    static let photosOnDeviceKey = "soma_photos_on_device"

    static var photosOnDevice: Bool {
        UserDefaults.standard.bool(forKey: photosOnDeviceKey)
    }
}

enum AppleServerAISettings {
    /// Opt-in until the Private Cloud Compute entitlement is assigned to the developer account:
    /// without it the model is unavailable, and an attempt would only add latency in front of the
    /// cloud engine. Flip this on the day the entitlement lands.
    static let defaultsKey = "soma_private_cloud_ai"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: defaultsKey)
    }
}

final class OnDeviceAIService: AIServiceProtocol {
    static let shared = OnDeviceAIService()

    /// How long a local answer may take for a text or voice log. It is normally done in well under
    /// a second, so a slow answer means a cold or busy device, and the cloud is the better bet.
    private let textDeadline: TimeInterval = 2.5

    /// Reading a plate is heavier local work than reading a sentence.
    private let imageDeadline: TimeInterval = 10

    private let serverDeadline: TimeInterval = 15

    /// Two photos is the practical ceiling on-device: the window is 4K tokens and every image
    /// spends a large slice of it.
    private static let maxLocalPhotos = 2

    enum Status {
        case ready
        case needsNewerSystem
        case languageUnsupported(String)
        case unavailable(String)
    }

    /// What the settings screen shows, so the toggle never promises something this iPhone cannot do.
    static var status: Status {
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                // The model runs, but only in the languages Apple Intelligence supports. Arabic is
                // not one of them, so an Arabic app language must not be told otherwise.
                if !SystemLanguageModel.default.supportsLocale() {
                    return .languageUnsupported(
                        "Apple Intelligence does not support \(currentLanguageName) yet, so logs go to the cloud"
                    )
                }
                return .ready
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible:
                    return .unavailable("This iPhone does not support Apple Intelligence")
                case .appleIntelligenceNotEnabled:
                    return .unavailable("Turn on Apple Intelligence in iOS Settings")
                case .modelNotReady:
                    return .unavailable("The on-device model is still downloading")
                @unknown default:
                    return .unavailable("Not available on this iPhone")
                }
            @unknown default:
                return .unavailable("Not available on this iPhone")
            }
        }
        return .needsNewerSystem
    }

    static var isReady: Bool {
        if case .ready = status { return true }
        return false
    }

    /// iOS 27 is where the on-device model learned to read images.
    static var supportsImageInput: Bool {
        if #available(iOS 27.0, *) { return true }
        return false
    }

    private static var currentLanguageName: String {
        let code = Locale.current.language.languageCode?.identifier ?? "this language"
        return Locale.current.localizedString(forLanguageCode: code) ?? code
    }

    // MARK: - Analysis

    func analyze(
        userNotes: String?,
        photoDataList: [Data],
        audioData: Data? = nil,
        audioMimeType: String? = nil,
        voiceTranscription: String? = nil,
        alternativeTranscriptions: [String] = []
    ) async throws -> AIMealAnalysisResult {
        guard #available(iOS 26.0, *) else { throw AIEngineError.unavailable }
        guard case .available = SystemLanguageModel.default.availability else { throw AIEngineError.unavailable }
        guard photoDataList.isEmpty || Self.supportsImageInput else { throw AIEngineError.unsupportedInput }
        guard audioData?.isEmpty ?? true else { throw AIEngineError.unsupportedInput }
        guard Self.mayRead(
            userNotes: userNotes,
            voiceTranscription: voiceTranscription,
            alternatives: alternativeTranscriptions
        ) else { throw AIEngineError.languageUnsupported }

        // Photos are capped before the prompt is built, so the model is told exactly how many
        // images it is being shown.
        let photoData = photoDataList.count > Self.maxLocalPhotos
            ? Array(photoDataList.prefix(Self.maxLocalPhotos))
            : photoDataList

        let started = Date()

        let prompt = SomaAIPrompts.mealPrompt(
            notes: userNotes,
            voiceTranscription: voiceTranscription,
            alternativeTranscriptions: alternativeTranscriptions,
            photoCount: photoData.count
        )
        let instructions = SomaAIPrompts.onDeviceSystemInstruction(outputLanguage: SpeechLanguage.resolved())
        let budget = photoData.isEmpty ? textDeadline : imageDeadline

        do {
            let result = try await generateWithinDeadline(
                prompt: prompt,
                instructions: instructions,
                photoData: photoData,
                budget: budget,
                engine: .onDevice
            )
            guard Self.isConsistent(result) else { throw AIEngineError.inconsistentResult }

            #if DEBUG
            print("[OnDeviceAI] answered in \(String(format: "%.2f", Date().timeIntervalSince(started)))s: \(result.title), \(result.calories) kcal")
            #endif
            return result
        } catch {
            // A timeout means this device is the bottleneck, so another wait on top of it would only
            // delay the same answer.
            if let engineError = error as? AIEngineError, case .timedOut = engineError { throw engineError }

            if let server = try? await privateCloudAnswer(prompt: prompt, photoData: photoData) {
                return server
            }
            throw error is AIEngineError ? error : AIEngineError.generationFailed(error.localizedDescription)
        }
    }

    /// Apple Intelligence reads a fixed set of languages, and Arabic is not in it yet: an Arabic
    /// prompt can throw LanguageModelError.unsupportedLanguageOrLocale. Skipping the attempt keeps
    /// that failure out of the user's way and sends the log straight to the cloud instead. The check
    /// reads the model's own language list, so the day Arabic is added this starts working by itself.
    @available(iOS 26.0, *)
    private static func mayRead(userNotes: String?, voiceTranscription: String?, alternatives: [String]) -> Bool {
        guard SystemLanguageModel.default.supportsLocale() else { return false }

        let combined = ([userNotes, voiceTranscription].compactMap { $0 } + alternatives).joined(separator: " ")
        guard combined.range(of: "\\p{Arabic}", options: .regularExpression) != nil else { return true }

        return SystemLanguageModel.default.supportedLanguages.contains {
            $0.languageCode?.identifier == "ar"
        }
    }

    /// One guided generation, abandoned if the model takes longer than the budget, so a busy or cold
    /// device hands the turn on instead of holding the spinner. Photo bytes are passed as plain
    /// Data: the project defaults to main-actor isolation, so the child task must not reach back
    /// into isolated state.
    @available(iOS 26.0, *)
    private func generateWithinDeadline(
        prompt: String,
        instructions: String,
        photoData: [Data],
        budget: TimeInterval,
        engine: AIMealAnalysisResult.Engine
    ) async throws -> AIMealAnalysisResult {
        let images = photoData

        return try await withThrowingTaskGroup(of: AIMealAnalysisResult.self) { group in
            group.addTask {
                let session = LanguageModelSession(instructions: instructions)
                let meal: GeneratedMeal

                if images.isEmpty {
                    meal = try await session.respond(to: prompt, generating: GeneratedMeal.self).content
                } else {
                    guard #available(iOS 27.0, *) else { throw AIEngineError.unsupportedInput }

                    let attachments = images.compactMap { data -> CGImage? in
                        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
                        return CGImageSourceCreateImageAtIndex(source, 0, nil)
                    }
                    guard !attachments.isEmpty else { throw AIEngineError.unsupportedInput }

                    meal = try await session.respond(generating: GeneratedMeal.self) {
                        prompt
                        for image in attachments {
                            Attachment(image)
                        }
                    }.content
                }

                return meal.asAnalysisResult(engine: engine)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(budget * 1_000_000_000))
                throw AIEngineError.timedOut
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw AIEngineError.timedOut }
            return first
        }
    }

    /// Apple's server model, reached through the same session API. Off by default because it needs
    /// the Private Cloud Compute entitlement; while it is off, or unavailable, or out of its daily
    /// quota, this returns nil and the caller falls through to the cloud engine as before.
    private func privateCloudAnswer(prompt: String, photoData: [Data]) async throws -> AIMealAnalysisResult? {
        guard AppleServerAISettings.isEnabled else { return nil }
        guard #available(iOS 27.0, *) else { return nil }

        let model = PrivateCloudComputeLanguageModel()
        guard model.isAvailable, !model.quotaUsage.isLimitReached else { return nil }

        let instructions = SomaAIPrompts.onDeviceSystemInstruction(outputLanguage: SpeechLanguage.resolved())
        let images = photoData
        let deadline = serverDeadline

        return try await withThrowingTaskGroup(of: AIMealAnalysisResult.self) { group in
            group.addTask {
                let session = LanguageModelSession(model: model, instructions: instructions)
                let meal: GeneratedMeal

                if images.isEmpty {
                    meal = try await session.respond(to: prompt, generating: GeneratedMeal.self).content
                } else {
                    let attachments = images.compactMap { data -> CGImage? in
                        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
                        return CGImageSourceCreateImageAtIndex(source, 0, nil)
                    }
                    guard !attachments.isEmpty else { throw AIEngineError.unsupportedInput }

                    meal = try await session.respond(generating: GeneratedMeal.self) {
                        prompt
                        for image in attachments {
                            Attachment(image)
                        }
                    }.content
                }

                return meal.asAnalysisResult(engine: .privateCloud)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(deadline * 1_000_000_000))
                throw AIEngineError.timedOut
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw AIEngineError.timedOut }
            guard Self.isConsistent(first) else { throw AIEngineError.inconsistentResult }
            return first
        }
    }

    /// The on-device model is much smaller than the cloud one, so its answer is only accepted when
    /// the numbers hold together. A rejection escalates rather than showing a bad estimate.
    private static func isConsistent(_ result: AIMealAnalysisResult) -> Bool {
        guard !result.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }

        // Water is 0 kcal by definition, so the calorie checks below would reject every water log.
        if result.waterML > 0 {
            return result.calories == 0
                && result.proteinG == 0 && result.carbsG == 0 && result.fatG == 0
                && result.waterML <= 5_000
        }

        guard result.calories > 0, result.calories <= 5_000 else { return false }
        guard result.proteinG >= 0, result.carbsG >= 0, result.fatG >= 0 else { return false }
        guard result.proteinG <= 400, result.carbsG <= 900, result.fatG <= 400 else { return false }

        // Rule 4 of the shared prompt, enforced: calories must match the macro breakdown.
        let macroCalories = result.proteinG * 4 + result.carbsG * 4 + result.fatG * 9
        guard macroCalories > 0 else { return false }
        return abs(Double(result.calories) - macroCalories) / Double(result.calories) <= 0.25
    }
}

// MARK: - Guided generation types

@available(iOS 26.0, *)
@Generable
private struct GeneratedMeal {
    @Guide(description: "Short descriptive meal title in the user's own language")
    var title: String

    @Guide(description: "City, restaurant, brand, delivery app or setting if mentioned, otherwise an empty string")
    var location: String

    @Guide(description: "One or two warm sentences describing the meal and its nutrition")
    var storyNarrative: String

    @Guide(description: "Total calories, consistent with the macro breakdown")
    var calories: Int

    @Guide(description: "Protein in grams")
    var proteinG: Double

    @Guide(description: "Carbohydrates in grams")
    var carbsG: Double

    @Guide(description: "Fat in grams")
    var fatG: Double

    @Guide(description: "Water amount in millilitres when the log is water, otherwise exactly 0")
    var waterML: Int

    @Guide(description: "Every component of the meal with its portion. Empty for a water log")
    var items: [GeneratedItem]
}

@available(iOS 26.0, *)
@Generable
private struct GeneratedItem {
    @Guide(description: "Name of the component")
    var name: String

    @Guide(description: "Portion, in the user's own language")
    var portion: String

    var calories: Int
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
}

@available(iOS 26.0, *)
private extension GeneratedMeal {
    /// Bridges the generated shape into the app's own result type, so nothing downstream needs to
    /// know which engine answered.
    func asAnalysisResult(engine: AIMealAnalysisResult.Engine) -> AIMealAnalysisResult {
        AIMealAnalysisResult(
            title: title,
            location: location,
            storyNarrative: storyNarrative,
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            waterML: max(0, waterML),
            confidence: 0.9,
            items: items.map {
                AIFoodItemBreakdown(
                    name: $0.name,
                    portion: $0.portion,
                    calories: $0.calories,
                    proteinG: $0.proteinG,
                    carbsG: $0.carbsG,
                    fatG: $0.fatG
                )
            },
            engine: engine
        )
    }
}
