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

    /// Cloudflare Worker proxy endpoint protecting the Gemini API key
    let proxyEndpointURL: String = "https://soma-ai-proxy.ziadm4772.workers.dev"

    /// Shared client authorization secret matching Cloudflare Worker SOMA_APP_SECRET
    let proxyClientSecret: String = "soma67app67health"

    /// App Privacy Policy URL
    let privacyPolicyURL: String = "https://soma-tracker.app/privacy"

    private init() {}

    // Internal bundled API credentials loaded safely from build configuration (if used without proxy)
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
        isProEnabled && (!proxyEndpointURL.isEmpty || !bundledGeminiApiKey.isEmpty)
    }
}
