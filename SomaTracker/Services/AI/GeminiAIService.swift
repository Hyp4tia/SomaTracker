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

        var parts: [[String: Any]] = []

        // 1. Text description & user query, built by the shared prompt source so the cloud and the
        // on-device engine are handed identical wording.
        let combinedPrompt = SomaAIPrompts.mealPrompt(
            notes: userNotes,
            voiceTranscription: voiceTranscription,
            alternativeTranscriptions: alternativeTranscriptions,
            photoCount: photoDataList.count
        )
        // The answer's language is the user's choice, never a guess from the input.
        let outputLanguage = SpeechLanguage.resolved()
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

        // Shared with the on-device engine so the two cannot describe different nutritionists.
        let systemInstruction = SomaAIPrompts.cloudSystemInstruction(outputLanguage: outputLanguage)

        guard let payloadData = try? await generateJSON(systemInstruction: systemInstruction, parts: parts) else {
            throw NSError(domain: "GeminiAIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "All Gemini AI model endpoints failed."])
        }
        return try JSONDecoder().decode(AIMealAnalysisResult.self, from: payloadData)
    }

    // MARK: - Transport

    /// The model cascade: returns the response's JSON payload as data. Shared by the analysis prompt
    /// and the review prompt so both get the same endpoints, headers, timeout and retry behaviour,
    /// and so a change to the routing or the timeout can never apply to only one of them.
    private func generateJSON(systemInstruction: String, parts: [[String: Any]], jsonMode: Bool = true) async throws -> Data {
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

        // Built separately: a ternary of two dictionary literals defeats type inference here.
        var generationConfig: [String: Any] = ["temperature": jsonMode ? 0.1 : 0.2]
        if jsonMode {
            generationConfig["response_mime_type"] = "application/json"
        }

        let requestBody: [String: Any] = [
            "system_instruction": [
                "parts": [["text": systemInstruction]]
            ],
            "contents": [
                ["parts": parts]
            ],
            "generationConfig": generationConfig
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

                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let candidates = json["candidates"] as? [[String: Any]],
                      let firstCandidate = candidates.first,
                      let content = firstCandidate["content"] as? [String: Any],
                      let responseParts = content["parts"] as? [[String: Any]],
                      let textPayload = responseParts.first?["text"] as? String else {
                    continue
                }

                // A question gets prose back; a log gets the JSON contract sliced out of the reply.
                if !jsonMode {
                    return Data(textPayload.utf8)
                }

                guard let payloadData = GeminiAIService.jsonPayload(from: textPayload) else { continue }
                return payloadData
            } catch {
                print("[GeminiAIService] Failed with model \(modelName): \(error.localizedDescription)")
                lastError = error
                continue
            }
        }

        throw lastError ?? NSError(domain: "GeminiAIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "All Gemini AI model endpoints failed."])
    }

    /// Strips code fences and any prose around the JSON object, then returns it as data.
    private static func jsonPayload(from text: String) -> Data? {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        if let firstOpen = cleaned.firstIndex(of: "{") {
            var depth = 0
            var lastClose: String.Index? = nil
            for index in cleaned[firstOpen...].indices {
                let ch = cleaned[index]
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
            if let lastClose {
                cleaned = String(cleaned[firstOpen...lastClose])
            }
        }

        return cleaned.data(using: .utf8)
    }

    // MARK: - Review

    /// Free-text answer for the chat's advice questions. No JSON contract: the reply is the answer.
    ///
    /// Grounding with Google Search is a paid-tier feature on the Gemini 3 family, so a project without
    /// billing answers 429 for it. That is reported as `usedSearch: false` instead of failing the
    /// question, and the caller stops asking for search until it might work again.
    func answer(systemInstruction: String, question: String, searchGrounding: Bool = false) async throws -> SomaAIAnswer {
        if searchGrounding {
            do {
                let grounded = try await groundedAnswer(systemInstruction: systemInstruction, question: question)
                return grounded
            } catch {
                #if DEBUG
                print("[GeminiAIService] Search grounding unavailable: \(error.localizedDescription)")
                #endif
            }
        }

        let parts: [[String: Any]] = [["text": question]]
        let data = try await generateJSON(systemInstruction: systemInstruction, parts: parts, jsonMode: false)
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return SomaAIAnswer(text: text, sources: [], usedSearch: false)
    }

    private func groundedAnswer(systemInstruction: String, question: String) async throws -> SomaAIAnswer {
        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": systemInstruction]]],
            "contents": [["parts": [["text": question]]]],
            "tools": [["google_search": [:]]],
            "generationConfig": ["temperature": 0.2]
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        let model = "gemini-3.5-flash-lite"

        let endpoint = !proxyEndpoint.isEmpty
            ? "\(proxyEndpoint)?model=\(model)"
            : "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "GeminiAIService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Bad endpoint"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !proxyEndpoint.isEmpty && !proxyClientSecret.isEmpty {
            request.setValue(proxyClientSecret, forHTTPHeaderField: "X-Soma-Client-Key")
        }
        request.httpBody = data
        request.timeoutInterval = 20

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let body = String(data: responseData, encoding: .utf8) ?? ""
            throw NSError(
                domain: "GeminiAIService",
                code: (response as? HTTPURLResponse)?.statusCode ?? 500,
                userInfo: [NSLocalizedDescriptionKey: body]
            )
        }

        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let candidate = candidates.first,
              let content = candidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw NSError(domain: "GeminiAIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unreadable grounded reply"])
        }

        var sources: [SomaWebSource] = []
        if let metadata = candidate["groundingMetadata"] as? [String: Any],
           let chunks = metadata["groundingChunks"] as? [[String: Any]] {
            for chunk in chunks {
                guard let web = chunk["web"] as? [String: Any],
                      let urlString = web["uri"] as? String,
                      let url = URL(string: urlString) else { continue }
                sources.append(SomaWebSource(title: web["title"] as? String ?? url.host ?? urlString, url: url))
            }
        }

        return SomaAIAnswer(
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            sources: sources,
            usedSearch: true
        )
    }

    /// Fact-checks an estimate that another engine produced. The cloud is the second opinion for
    /// everything Siri answers, so a wrong on-device estimate gets corrected rather than shipped.
    func review(description: String, estimate: AIMealAnalysisResult) async throws -> AIMealReview {
        guard !proxyEndpoint.isEmpty || !apiKey.isEmpty else {
            throw NSError(domain: "GeminiAIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Neither Gemini proxy endpoint nor API key is configured."])
        }

        let payload = try await generateJSON(
            systemInstruction: SomaAIPrompts.reviewInstruction(outputLanguage: SpeechLanguage.resolved()),
            parts: [["text": SomaAIPrompts.reviewPrompt(description: description, estimate: estimate)]]
        )
        return try JSONDecoder().decode(AIMealReview.self, from: payload)
    }
}
