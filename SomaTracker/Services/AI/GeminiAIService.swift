//
//  GeminiAIService.swift
//  SomaTracker
//
//  Multimodal AI analysis using Google Gemini Flash API with structured JSON output.
//

import Foundation

final class GeminiAIService: AIServiceProtocol {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func analyze(
        userNotes: String?,
        photoDataList: [Data],
        audioData: Data? = nil,
        audioMimeType: String? = nil,
        voiceTranscription: String? = nil,
        alternativeTranscriptions: [String] = []
    ) async throws -> AIMealAnalysisResult {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "GeminiAIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Gemini API key is not configured."])
        }

        let candidateModels = [
            "gemini-3-flash-preview",
            "gemini-2.5-flash",
            "gemini-flash-latest",
            "gemini-3.5-flash",
            "gemini-2.5-flash-lite"
        ]

        var parts: [[String: Any]] = []

        // 1. Text description & user query
        var promptLines: [String] = ["Analyze this meal entry:"]
        if let notes = userNotes, !notes.isEmpty {
            promptLines.append("Spoken or written description: \"\(notes)\"")
        }
        if let voice = voiceTranscription, !voice.isEmpty, voice != userNotes {
            promptLines.append("Voice dictation transcription: \"\(voice)\"")
        }
        if !alternativeTranscriptions.isEmpty {
            promptLines.append("Acoustic candidate variations (from fast speech / alternative hypotheses): [\(alternativeTranscriptions.map { "\"\($0)\"" }.joined(separator: ", "))]")
        }
        promptLines.append("""
        Please estimate the meal title, general location or setting if mentioned (otherwise empty string), a brief natural narrative (1-2 sentences), total calories, protein (g), carbs (g), and fat (g), and item breakdown.
        """)
        let combinedPrompt = promptLines.joined(separator: "\n")
        parts.append(["text": combinedPrompt])

        // 2. Multimodal Photos (up to 5, base64 encoded)
        for photo in photoDataList.prefix(5) {
            let base64String = photo.base64EncodedString()
            parts.append([
                "inline_data": [
                    "mime_type": "image/jpeg",
                    "data": base64String
                ]
            ])
        }

        // 3. Multimodal Audio Voice Note (Raw acoustic audio fallback if transcription was empty)
        if let audio = audioData, !audio.isEmpty {
            let mime = audioMimeType ?? "audio/m4a"
            parts.append([
                "inline_data": [
                    "mime_type": mime,
                    "data": audio.base64EncodedString()
                ]
            ])
        }

        let systemInstruction = """
        You are Soma AI, an elite multilingual nutrition and diet intelligence engine following an elevated, minimal aesthetic.
        You natively understand all languages and regional dialects, with deep native mastery of Arabic and its dialects, especially Egyptian Arabic (اللهجة المصرية: e.g. كشري، حواوشي، فول، طعمية، ملوخية، كفتة، كبدة إسكندراني، شاورما، رز معمر، فطير مشلتت، كباب، ممبار، بامية، محشي، عصير قصب, and Franco-Arab/Arabizi like "akalt koshary" or "sandwitch hawawshi").

        Rules:
        1. Language Matching: If the user inputs text, audio, or food in Arabic or Egyptian dialect, return the "title" and "storyNarrative" in natural, warm Arabic (matching their dialect/phrasing). If the user uses English, respond in English.
        2. Macro Accuracy: Accurately estimate traditional portion sizes, cooking oils/ghee, and typical regional recipes (e.g. baladi bread, tahini, fava beans). For international, restaurant, or fast-food meals (e.g. pizzas, burgers, chicken ranch pizza, pasta, wraps), provide realistic restaurant-grade macros and portions.
        3. Hydration: If the user is logging water (e.g. "مية", "ماء", "شربت مية", "water", "hydration"), include the water amount in ml in the title (e.g. "ماء ٢٥٠ مل" or "250ml Water") and set calories to 0.
        4. Speech & Dialect Slurring Tolerance: The input comes from speech-to-text dictation. Fast speakers, slurred pronunciation, and regional accents (especially Egyptian Arabic) often drop letters (e.g. dropping hamzas like "كوبايه" -> "كوباية" or "مايه" -> "ماء", dropping glottal stops like "أهوة" -> "قهوة", or blending connected words like "شايبلبن" or "سندوتشينحواوشي", or slurred English fast-food phrases). Intelligently reconstruct the user's intended food items, ingredients, and quantities dynamically from the acoustic phonetic context, regardless of slurring, typos, or omitted letters.
        5. Silence & Non-Food Guard: If the input (audio, text, or photo) contains NO food, NO drinks, is pure room silence, microphone static, ambient background noise, or unintelligible non-food sounds, you MUST return title "No Food Detected" with 0 calories and empty items. NEVER fabricate, invent, or hallucinate food when no food or beverage is present or mentioned.
        6. Return ONLY valid JSON matching this schema:
        {
          "title": "Short descriptive meal title (e.g. كشري مصري or Grilled Salmon Bowl, or 'No Food Detected' if silent/no food)",
          "location": "City, restaurant name or setting if mentioned (e.g. كشري التحرير or Downtown Cairo), otherwise empty string",
          "storyNarrative": "A warm, natural 1-2 sentence description of the meal and nutritional value",
          "calories": 650,
          "proteinG": 18.0,
          "carbsG": 115.0,
          "fatG": 12.0,
          "confidence": 0.95,
          "items": [
            {
              "name": "كشري",
              "portion": "طبق وسط",
              "calories": 650,
              "proteinG": 18.0,
              "carbsG": 115.0,
              "fatG": 12.0
            }
          ]
        }
        """

        let requestBody: [String: Any] = [
            "system_instruction": [
                "parts": [["text": systemInstruction]]
            ],
            "contents": [
                ["parts": parts]
            ],
            "generationConfig": [
                "response_mime_type": "application/json",
                "temperature": 0.2
            ]
        ]

        let requestData = try JSONSerialization.data(withJSONObject: requestBody)

        var lastError: Error? = nil
        for modelName in candidateModels {
            let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(apiKey)"
            guard let url = URL(string: endpoint) else { continue }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = requestData
            request.timeoutInterval = 25

            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    let errorText = String(data: data, encoding: .utf8) ?? "Unknown server response"
                    print("[GeminiAIService] Model \(modelName) returned error: \(errorText)")
                    lastError = NSError(domain: "GeminiAIService", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: errorText])
                    continue
                }

                // Parse Gemini Response JSON
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let candidates = json?["candidates"] as? [[String: Any]],
                      let firstCandidate = candidates.first,
                      let content = firstCandidate["content"] as? [String: Any],
                      let responseParts = content["parts"] as? [[String: Any]],
                      let textPayload = responseParts.first?["text"] as? String else {
                    continue
                }

                // Clean any code block fences (e.g. ```json ... ```)
                var cleanedText = textPayload.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleanedText.hasPrefix("```json") {
                    cleanedText = String(cleanedText.dropFirst(7))
                } else if cleanedText.hasPrefix("```") {
                    cleanedText = String(cleanedText.dropFirst(3))
                }
                if cleanedText.hasSuffix("```") {
                    cleanedText = String(cleanedText.dropLast(3))
                }
                cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)

                // Extract balanced JSON object from first '{' to its matching '}' to remove any trailing LLM quirks
                if let firstOpen = cleanedText.firstIndex(of: "{") {
                    var depth = 0
                    var lastClose: String.Index? = nil
                    for index in cleanedText[firstOpen...].indices {
                        let ch = cleanedText[index]
                        if ch == "{" {
                            depth += 1
                        } else if ch == "}" {
                            depth -= 1
                            if depth == 0 {
                                lastClose = index
                                break
                            }
                        }
                    }
                    if let lastClose = lastClose {
                        cleanedText = String(cleanedText[firstOpen...lastClose])
                    }
                }

                guard let payloadData = cleanedText.data(using: .utf8) else {
                    continue
                }

                let decodedResult = try JSONDecoder().decode(AIMealAnalysisResult.self, from: payloadData)
                return decodedResult
            } catch {
                print("[GeminiAIService] Failed with model \(modelName): \(error.localizedDescription)")
                lastError = error
                continue
            }
        }

        throw lastError ?? NSError(domain: "GeminiAIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "All Gemini AI model endpoints failed."])
    }
}
