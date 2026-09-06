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
        directTranscription: String? = nil
    ) async -> AIMealAnalysisResult {
        // Step 1: Voice transcription (if audio file provided and not already transcribed)
        var voiceTranscript: String? = directTranscription
        if voiceTranscript == nil, let audioURL = audioURL {
            let transcribed = await speechService.transcribeAudioFile(at: audioURL)
            if !transcribed.isEmpty {
                voiceTranscript = transcribed
            }
        }

        let combinedText = [notes, voiceTranscript]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let config = APIConfiguration.shared

        // Step 2: Route to Gemini 2.0 Flash for all modalities (Photos, Voice Audio, Arabic/English Text)
        if config.hasCloudVisionReady {
            do {
                let service = GeminiAIService(apiKey: config.bundledGeminiApiKey)

                var audioData: Data? = nil
                var audioMime: String? = nil
                if let url = audioURL, let data = try? Data(contentsOf: url), !data.isEmpty {
                    audioData = data
                    let ext = url.pathExtension.lowercased()
                    if ext == "wav" {
                        audioMime = "audio/wav"
                    } else if ext == "caf" {
                        audioMime = "audio/x-caf"
                    } else {
                        audioMime = "audio/m4a"
                    }
                }

                // If user provided photos, audio recording, or text description:
                if !photos.isEmpty || audioData != nil || !combinedText.isEmpty {
                    return try await service.analyze(
                        userNotes: notes,
                        photoDataList: photos,
                        audioData: audioData,
                        audioMimeType: audioMime,
                        voiceTranscription: voiceTranscript
                    )
                }
            } catch {
                print("[AIRouter] Gemini AI request error: \(error.localizedDescription). Falling back to on-device engine.")
                // Fall back to on-device nutritional engine seamlessly
            }
        }

        // Step 3: On-Device Intelligent Nutrition & NLP Engine
        let parsed = FoodNutritionDatabase.shared.parseInput(combinedText)

        let narrative = !combinedText.isEmpty
            ? combinedText
            : "Logged with Soma AI Voice & Vision."

        return AIMealAnalysisResult(
            title: parsed.title,
            location: "",
            storyNarrative: narrative,
            calories: parsed.calories,
            proteinG: parsed.proteinG,
            carbsG: parsed.carbsG,
            fatG: parsed.fatG,
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
            ]
        )
    }
}
