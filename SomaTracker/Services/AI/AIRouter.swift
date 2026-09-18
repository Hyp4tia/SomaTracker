//
//  AIRouter.swift
//  SomaTracker
//
//  Smart coordinator combining on-device Apple Speech, Food Nutrition Engine,
//  and optional bundled cloud vision.
//

import Foundation

final class AIRouter {
    static let shared = AIRouter()

    private let speechService = SpeechRecognitionService()

    private init() {}

    func processMultimodalMeal(
        notes: String?,
        photos: [Data],
        audioURL: URL?,
        directTranscription: String? = nil,
        alternativeTranscriptions: [String] = []
    ) async -> AIMealAnalysisResult {
        // Step 1: Voice transcription (if audio file provided and not already transcribed)
        var voiceTranscript: String? = directTranscription
        if voiceTranscript == nil, let audioURL = audioURL {
            let transcribed = await speechService.transcribeAudioFile(at: audioURL)
            if !transcribed.isEmpty {
                voiceTranscript = transcribed
            }
        }

        let effectiveNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveVoice = voiceTranscript?.trimmingCharacters(in: .whitespacesAndNewlines)

        var textElements: [String] = []
        if let n = effectiveNotes, !n.isEmpty {
            textElements.append(n)
        }
        if let v = effectiveVoice, !v.isEmpty, v != effectiveNotes {
            textElements.append(v)
        }
        let combinedText = textElements.joined(separator: " ")

        // Guard against completely empty/silent input (no photos, no notes, no transcribed speech)
        if photos.isEmpty && combinedText.isEmpty {
            return .noFoodDetected
        }

        let config = APIConfiguration.shared

        // Step 2: Apple's own engine answers first. For text and voice it is instant, free, and the
        // user's words never leave the iPhone; on iOS 27 it reads photos too. The cloud is the
        // second opinion, taking over when this device cannot run the model, when the model does not
        // read the language of the log (Arabic today), when a local answer takes too long, or when
        // it fails the numeric consistency checks.
        let appleEngineCanTry = OnDeviceAISettings.isEnabled
            && (photos.isEmpty || OnDeviceAIService.supportsImageInput)
        if appleEngineCanTry {
            do {
                return try await OnDeviceAIService.shared.analyze(
                    userNotes: !combinedText.isEmpty ? combinedText : notes,
                    photoDataList: photos,
                    voiceTranscription: effectiveVoice,
                    alternativeTranscriptions: alternativeTranscriptions
                )
            } catch {
                #if DEBUG
                print("[AIRouter] Apple engine declined (\(error)); asking the cloud engine.")
                #endif
            }
        }

        // Step 3: Route to Gemini Flash for all modalities (Photos, Voice Audio, Arabic/English Text)
        if config.hasCloudVisionReady {
            do {
                let service = GeminiAIService()

                return try await service.analyze(
                    userNotes: !combinedText.isEmpty ? combinedText : notes,
                    photoDataList: photos,
                    audioData: nil,
                    audioMimeType: nil,
                    voiceTranscription: effectiveVoice,
                    alternativeTranscriptions: alternativeTranscriptions
                )
            } catch {
                print("[AIRouter] Gemini AI request error: \(error.localizedDescription). Falling back to on-device engine.")
                // Fall back to on-device nutritional engine seamlessly
            }
        }

        // Reaching here after a configured cloud attempt means the call failed, so the result is a
        // fallback and the UI is told, rather than blaming the user's input for an outage.
        let fallbackEngine: AIMealAnalysisResult.Engine = config.hasCloudVisionReady ? .onDeviceFallback : .onDevice

        // Step 4: On-Device Intelligent Nutrition & NLP Engine
        let parsed = FoodNutritionDatabase.shared.parseInput(combinedText)

        let narrative = !combinedText.isEmpty
            ? combinedText
            : "Logged with Soma AI Voice & Vision."

        if parsed.title == "No Food Detected" {
            return .noFoodDetected.attributed(to: fallbackEngine)
        }

        return AIMealAnalysisResult(
            title: parsed.title,
            location: "",
            storyNarrative: narrative,
            calories: parsed.calories,
            proteinG: parsed.proteinG,
            carbsG: parsed.carbsG,
            fatG: parsed.fatG,
            waterML: parsed.waterML,
            confidence: 0.94,
            items: [
                AIFoodItemBreakdown(
                    name: parsed.title,
                    portion: "1 serving",
                    calories: parsed.calories,
                    proteinG: parsed.proteinG,
                    carbsG: parsed.carbsG,
                    fatG: parsed.fatG
                )
            ],
            engine: fallbackEngine
        )
    }
}
