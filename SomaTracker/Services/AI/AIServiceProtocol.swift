//
//  AIServiceProtocol.swift
//  SomaTracker
//
//  Standard contract and data structures for multimodal AI nutritional analysis.
//

import Foundation

struct AIFoodItemBreakdown: Codable, Identifiable {
    var id: String { name }
    let name: String
    let portion: String
    let calories: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double

    enum CodingKeys: String, CodingKey {
        case name, portion, calories, proteinG, carbsG, fatG
        case protein_g, carbs_g, fat_g
    }

    init(name: String, portion: String, calories: Int, proteinG: Double, carbsG: Double, fatG: Double) {
        self.name = name
        self.portion = portion
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = (try? container.decode(String.self, forKey: .name)) ?? "Food Item"
        self.portion = (try? container.decode(String.self, forKey: .portion)) ?? "1 serving"
        
        if let cal = try? container.decode(Int.self, forKey: .calories) {
            self.calories = cal
        } else if let calD = try? container.decode(Double.self, forKey: .calories) {
            self.calories = Int(calD)
        } else {
            self.calories = 0
        }

        self.proteinG = Self.extractDouble(from: container, primary: .proteinG, secondary: .protein_g)
        self.carbsG = Self.extractDouble(from: container, primary: .carbsG, secondary: .carbs_g)
        self.fatG = Self.extractDouble(from: container, primary: .fatG, secondary: .fat_g)
    }

    private static func extractDouble(from container: KeyedDecodingContainer<CodingKeys>, primary: CodingKeys, secondary: CodingKeys) -> Double {
        if let d = try? container.decode(Double.self, forKey: primary) { return d }
        if let d = try? container.decode(Double.self, forKey: secondary) { return d }
        if let i = try? container.decode(Int.self, forKey: primary) { return Double(i) }
        if let i = try? container.decode(Int.self, forKey: secondary) { return Double(i) }
        return 0.0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(portion, forKey: .portion)
        try container.encode(calories, forKey: .calories)
        try container.encode(proteinG, forKey: .proteinG)
        try container.encode(carbsG, forKey: .carbsG)
        try container.encode(fatG, forKey: .fatG)
    }
}

struct AIMealAnalysisResult: Codable {
    /// Which engine produced this analysis. Not part of the wire format: it is set locally so the
    /// UI can tell "Soma AI could not be reached" apart from "the AI found no food here".
    enum Engine {
        case cloud
        /// Cloud is configured but the call failed, so this is the on-device fallback.
        case onDeviceFallback
        /// Cloud is not configured at all, so the on-device engine handled it.
        case onDevice
    }

    var engine: Engine = .cloud

    let title: String
    let location: String
    let storyNarrative: String
    let calories: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let confidence: Double
    let items: [AIFoodItemBreakdown]

    var isNoFood: Bool {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if t == "no food detected" || t == "no food" || t.contains("no food") || t == "لا يوجد طعام" || t.contains("لم يتم التعرف") {
            return true
        }
        if calories == 0 && (items.isEmpty || t.isEmpty) {
            return true
        }
        return false
    }

    /// Same result, attributed to a different engine.
    func attributed(to engine: Engine) -> AIMealAnalysisResult {
        var copy = self
        copy.engine = engine
        return copy
    }

    static let noFoodDetected = AIMealAnalysisResult(
        title: "No Food Detected",
        location: "",
        storyNarrative: "",
        calories: 0,
        proteinG: 0,
        carbsG: 0,
        fatG: 0,
        confidence: 0.0,
        items: []
    )

    enum CodingKeys: String, CodingKey {
        case title, location, storyNarrative, calories, proteinG, carbsG, fatG, confidence, items
        case story_narrative, protein_g, carbs_g, fat_g
    }

    init(
        title: String,
        location: String,
        storyNarrative: String,
        calories: Int,
        proteinG: Double,
        carbsG: Double,
        fatG: Double,
        confidence: Double,
        items: [AIFoodItemBreakdown],
        engine: Engine = .cloud
    ) {
        self.title = title
        self.location = location
        self.storyNarrative = storyNarrative
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.confidence = confidence
        self.items = items
        self.engine = engine
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.title = (try? container.decode(String.self, forKey: .title)) ?? "AI Meal Log"
        self.location = (try? container.decode(String.self, forKey: .location)) ?? ""
        self.storyNarrative = (try? container.decode(String.self, forKey: .storyNarrative))
            ?? (try? container.decode(String.self, forKey: .story_narrative))
            ?? ""

        if let cal = try? container.decode(Int.self, forKey: .calories) {
            self.calories = cal
        } else if let calD = try? container.decode(Double.self, forKey: .calories) {
            self.calories = Int(calD)
        } else {
            self.calories = 0
        }

        self.proteinG = Self.extractDouble(from: container, primary: .proteinG, secondary: .protein_g)
        self.carbsG = Self.extractDouble(from: container, primary: .carbsG, secondary: .carbs_g)
        self.fatG = Self.extractDouble(from: container, primary: .fatG, secondary: .fat_g)
        self.confidence = (try? container.decode(Double.self, forKey: .confidence)) ?? 0.90

        if let directItems = try? container.decode([AIFoodItemBreakdown].self, forKey: .items) {
            self.items = directItems
        } else if let stringItems = try? container.decode([String].self, forKey: .items) {
            self.items = stringItems.map {
                AIFoodItemBreakdown(name: $0, portion: "1 serving", calories: 0, proteinG: 0, carbsG: 0, fatG: 0)
            }
        } else {
            self.items = []
        }
    }

    private static func extractDouble(from container: KeyedDecodingContainer<CodingKeys>, primary: CodingKeys, secondary: CodingKeys) -> Double {
        if let d = try? container.decode(Double.self, forKey: primary) { return d }
        if let d = try? container.decode(Double.self, forKey: secondary) { return d }
        if let i = try? container.decode(Int.self, forKey: primary) { return Double(i) }
        if let i = try? container.decode(Int.self, forKey: secondary) { return Double(i) }
        return 0.0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(location, forKey: .location)
        try container.encode(storyNarrative, forKey: .storyNarrative)
        try container.encode(calories, forKey: .calories)
        try container.encode(proteinG, forKey: .proteinG)
        try container.encode(carbsG, forKey: .carbsG)
        try container.encode(fatG, forKey: .fatG)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(items, forKey: .items)
    }

    static let placeholder = AIMealAnalysisResult(
        title: "Balanced Meal",
        location: "Current Location",
        storyNarrative: "A wholesome meal tracked with Soma AI.",
        calories: 500,
        proteinG: 35.0,
        carbsG: 45.0,
        fatG: 18.0,
        confidence: 0.90,
        items: []
    )
}

protocol AIServiceProtocol {
    func analyze(
        userNotes: String?,
        photoDataList: [Data],
        audioData: Data?,
        audioMimeType: String?,
        voiceTranscription: String?,
        alternativeTranscriptions: [String]
    ) async throws -> AIMealAnalysisResult
}

extension AIServiceProtocol {
    func analyze(
        userNotes: String?,
        photoDataList: [Data],
        audioData: Data? = nil,
        audioMimeType: String? = nil,
        voiceTranscription: String? = nil,
        alternativeTranscriptions: [String] = []
    ) async throws -> AIMealAnalysisResult {
        try await analyze(
            userNotes: userNotes,
            photoDataList: photoDataList,
            audioData: audioData,
            audioMimeType: audioMimeType,
            voiceTranscription: voiceTranscription,
            alternativeTranscriptions: alternativeTranscriptions
        )
    }
}
