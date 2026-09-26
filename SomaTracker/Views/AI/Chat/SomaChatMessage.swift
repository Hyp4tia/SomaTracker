import Foundation

struct SomaChatMessage: Identifiable {
    enum Author {
        case user
        case soma
    }

    enum Kind {
        case text
        case nutrition
        case receipt
        case notice
    }

    let id = UUID()
    let author: Author
    let kind: Kind
    var text: String
    var title: String = ""
    var calories: Int = 0
    var proteinG: Double = 0
    var carbsG: Double = 0
    var fatG: Double = 0
    var waterML: Int = 0
    var photos: [Data] = []

    static func user(_ text: String, photos: [Data] = []) -> SomaChatMessage {
        SomaChatMessage(author: .user, kind: .text, text: text, photos: photos)
    }

    static func answer(_ text: String) -> SomaChatMessage {
        SomaChatMessage(author: .soma, kind: .text, text: text)
    }

    static func nutrition(_ result: AIMealAnalysisResult) -> SomaChatMessage {
        SomaChatMessage(
            author: .soma,
            kind: .nutrition,
            text: result.storyNarrative,
            title: result.title,
            calories: result.calories,
            proteinG: result.proteinG,
            carbsG: result.carbsG,
            fatG: result.fatG,
            waterML: result.waterML
        )
    }

    static func receipt(_ result: AIMealAnalysisResult) -> SomaChatMessage {
        SomaChatMessage(
            author: .soma,
            kind: .receipt,
            text: result.storyNarrative,
            title: result.title,
            calories: result.calories,
            proteinG: result.proteinG,
            carbsG: result.carbsG,
            fatG: result.fatG,
            waterML: result.waterML
        )
    }

    static func hydration(amountML: Int) -> SomaChatMessage {
        SomaChatMessage(
            author: .soma,
            kind: .receipt,
            text: "",
            title: "Hydration",
            waterML: amountML
        )
    }

    static func notice(_ text: String) -> SomaChatMessage {
        SomaChatMessage(author: .soma, kind: .notice, text: text)
    }
}
