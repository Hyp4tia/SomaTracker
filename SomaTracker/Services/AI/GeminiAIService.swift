//
//  GeminiAIService.swift
//  SomaTracker
//
//  Multimodal AI analysis using Google Gemini Flash API with structured JSON output.
//

import Foundation

final class GeminiAIService: AIServiceProtocol {
    private let apiKey: String
    private let proxyEndpoint: String
    private let proxyClientSecret: String

    init(
        apiKey: String = APIConfiguration.shared.bundledGeminiApiKey,
        proxyEndpoint: String = APIConfiguration.shared.proxyEndpointURL,
        proxyClientSecret: String = APIConfiguration.shared.proxyClientSecret
    ) {
        self.apiKey = apiKey
        self.proxyEndpoint = proxyEndpoint
        self.proxyClientSecret = proxyClientSecret
    }

    func analyze(
        userNotes: String?,
        photoDataList: [Data],
        audioData: Data? = nil,
        audioMimeType: String? = nil,
        voiceTranscription: String? = nil,
        alternativeTranscriptions: [String] = []
    ) async throws -> AIMealAnalysisResult {
        guard !proxyEndpoint.isEmpty || !apiKey.isEmpty else {
            throw NSError(domain: "GeminiAIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Neither Gemini proxy endpoint nor API key is configured."])
        }

        // Measured against the live proxy: full Flash models burn 500-900 thinking tokens and
        // answer in 5-15s, or return 503 while Google sheds load, while Flash-Lite answers a
        // photo or a text meal in about 1.5s and never thinks at all. Lite is also the only
        // family that rejects thinkingConfig (HTTP 400), so this cascade stays Lite-only and
        // deliberately sends none. Pinned name first for consistent speed, `-latest` second so a
        // version bump cannot break logging, and nothing after that: each extra miss is a full
        // round trip the user waits through before the on-device engine takes over.
        let candidateModels = [
            "gemini-3.5-flash-lite",
            "gemini-flash-lite-latest",
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
        if !photoDataList.isEmpty {
            promptLines.append("The entry includes \(photoDataList.count) photo(s). Carefully examine visible food, portion sizes, brand packaging, can/bottle labels, and printed nutrition facts.")
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
        2. Macro Accuracy & Hidden Fats: Accurately estimate traditional portion sizes, cooking oils/ghee, and typical regional recipes (e.g. baladi bread, tahini, fava beans). For restaurant, Egyptian eatery, or takeout meals (e.g. pizzas, burgers, chicken ranch pizza, pasta, wraps, hawawshi, koshary with fried onions, shawarma fat cap, dressings), realistically account for typical restaurant cooking oils, ghee, and sauces. If homemade or diet is specified, adjust oils accordingly.
        3. Complete Plate Decomposition: For photos, break down the plate into every visible constituent component in "items" (main protein, starch, vegetables, sauces, dips, and bread). Never overlook calorie-dense condiments like tahini, garlic dip (toum), mayonnaise, or butter.
        4. Mathematical Macro Consistency: Total "calories" MUST be mathematically consistent with the macro breakdown: calories ≈ (proteinG * 4) + (carbsG * 4) + (fatG * 9). The total calories must equal the sum of calories across all "items" in the breakdown.
        5. Hydration: If the user is logging water (e.g. "مية", "ماء", "شربت مية", "water", "hydration"), include the water amount in ml in the title (e.g. "ماء ٢٥٠ مل" or "250ml Water") and set calories to 0.
        6. Speech & Dialect Slurring Tolerance: The input comes from speech-to-text dictation. Fast speakers, slurred pronunciation, and regional accents (especially Egyptian Arabic) often drop letters (e.g. dropping hamzas like "كوبايه" -> "كوباية" or "مايه" -> "ماء", dropping glottal stops like "أهوة" -> "قهوة", or blending connected words like "شايبلبن" or "سندوتشينحواوشي", or slurred English fast-food phrases). Intelligently reconstruct the user's intended food items, ingredients, and quantities dynamically from the acoustic phonetic context, regardless of slurring, typos, or omitted letters.
        7. Packaged Beverages, Cans & Nutrition Labels (OCR Priority):
           - When analyzing photos or descriptions of packaged drinks (such as sodas, sparkling water, energy drinks, juices), snack bags, or labeled containers:
           - ALWAYS inspect the packaging labels carefully for diet or low-calorie indicators: e.g. "Diet", "Zero Sugar", "Free", "Light", "No Added Sugar", "خالي من السكر", "زيرو", "دايت", "سفن أب موهيتو ليمون".
           - Read any printed nutrition panel, calorie stamp, or nutritional values (e.g. "2 kcal per 245ml", "1 kcal / 100ml").
           - YOU MUST USE THE PRINTED NUTRITION NUMBER. NEVER default to standard full-sugar soda values (100–150 kcal) if the can or bottle indicates a zero, diet, or low-calorie variant (e.g. 7up Lemon Mojito is ~2 kcal per 245ml can, Diet Pepsi is 1 kcal, Coca-Cola Zero is 1 kcal).
           - Identify container sizes: slim can (245ml–250ml), standard can (330ml), or bottle (500ml). If packaging prints calories per 100ml, scale to the full container depicted.
        8. Silence & Non-Food Guard: If the input (audio, text, or photo) contains NO food, NO drinks, is pure room silence, microphone static, ambient background noise, or unintelligible non-food sounds, you MUST return title "No Food Detected" with 0 calories and empty items. NEVER fabricate, invent, or hallucinate food when no food or beverage is present or mentioned.
        9. Return ONLY valid JSON matching this schema:
        {
          "title": "Short descriptive meal title (e.g. كشري مصري, 7up Lemon Mojito, or Grilled Salmon Bowl, or 'No Food Detected' if silent/no food)",
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
                "temperature": 0.1
            ]
        ]

        let requestData = try JSONSerialization.data(withJSONObject: requestBody)

        var lastError: Error? = nil
        for modelName in candidateModels {
            let endpoint: String
            if !proxyEndpoint.isEmpty {
                endpoint = "\(proxyEndpoint)?model=\(modelName)"
            } else {
                endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(apiKey)"
            }
            guard let url = URL(string: endpoint) else { continue }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if !proxyEndpoint.isEmpty && !proxyClientSecret.isEmpty {
                request.setValue(proxyClientSecret, forHTTPHeaderField: "X-Soma-Client-Key")
            }
            request.httpBody = requestData
            // Lite replies in about 1.5s, so a stalled attempt must not own the whole scan.
            request.timeoutInterval = 12

            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    let errorText = String(data: data, encoding: .utf8) ?? "Unknown server response"
                    #if DEBUG
                    print("[GeminiAIService] Model \(modelName) returned error: \(errorText)")
                    #else
                    // Status only in release: the body can echo prompt content back.
                    print("[GeminiAIService] Model \(modelName) returned HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                    #endif
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
