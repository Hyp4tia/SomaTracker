//
//  APIConfiguration.swift
//  SomaTracker
//
//  Bundled internal AI configuration and Pro version features.
//  No manual key input required from users.
//

import Foundation
import Observation

@Observable
final class APIConfiguration {
    static let shared = APIConfiguration()

    var isProEnabled: Bool = true

    private init() {}

    // Internal bundled API credentials loaded safely from build configuration or backend proxy
    var bundledGeminiApiKey: String {
        if !APISecrets.geminiApiKey.isEmpty {
            return APISecrets.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let bundleKey = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String,
           !bundleKey.isEmpty, !bundleKey.contains("YOUR_") {
            return bundleKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    var hasCloudVisionReady: Bool {
        isProEnabled && !bundledGeminiApiKey.isEmpty
    }
}
