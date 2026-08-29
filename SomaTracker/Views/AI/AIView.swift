import SwiftUI
import SwiftData

struct AIView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \DailyLog.date) private var logs: [DailyLog]

    @State private var inputText = ""
    @State private var chatMessages: [AIChatMessage] = [
        AIChatMessage(
            text: "Hello! I'm your Soma AI nutrition & health assistant. Ask me anything about your meals, daily goals, or healthy recipes.",
            isUser: false
        )
    ]

    private var profile: UserProfile? { profiles.first }

    private let sampleSuggestions = [
        "How is my protein intake this week?",
        "Quick 400 kcal high-protein dinner ideas",
        "Am I drinking enough water today?",
        "Healthy snack with under 200 calories"
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // AI Header Banner
                        headerBanner
                            .padding(.top, 8)

                        // Chat Messages
                        ForEach(chatMessages) { message in
                            messageBubble(message)
                        }

                        // Suggestions (if only intro message)
                        if chatMessages.count == 1 {
                            suggestionsSection
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 120) // Clearance for floating tab bar & input
                }
                .scrollDismissesKeyboard(.interactively)
            }

            // Input Bar
            inputBar
                .padding(.bottom, 68) // Clearance above floating tab bar
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Soma AI")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Header Banner

    private var headerBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(SomaColors.navy)
                    .frame(width: 44, height: 44)

                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Intelligent Insights")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(.label))

                Text("Personalized coaching powered by your habits")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(.secondaryLabel))
            }

            Spacer()
        }
        .padding(14)
        .background(SomaColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Message Bubble

    private func messageBubble(_ message: AIChatMessage) -> some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 48)

                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(SomaColors.navy)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(SomaColors.navy)

                        Text("Soma AI")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(SomaColors.navy)
                    }

                    Text(message.text)
                        .font(.system(size: 15))
                        .foregroundStyle(Color(.label))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(SomaColors.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Spacer(minLength: 48)
            }
        }
    }

    // MARK: - Suggestions Section

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUGGESTED QUESTIONS")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(.secondaryLabel))
                .padding(.leading, 4)

            ForEach(sampleSuggestions, id: \.self) { suggestion in
                Button {
                    sendQuery(suggestion)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 13))
                            .foregroundStyle(SomaColors.navy)

                        Text(suggestion)
                            .font(.system(size: 14))
                            .foregroundStyle(Color(.label))
                            .multilineTextAlignment(.leading)

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(SomaColors.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask Soma AI...", text: $inputText)
                .font(.system(size: 15))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(SomaColors.white)
                .clipShape(Capsule())

            Button {
                let query = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !query.isEmpty else { return }
                sendQuery(query)
                inputText = ""
            } label: {
                ZStack {
                    Circle()
                        .fill(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? SomaColors.navy.opacity(0.3) : SomaColors.navy)
                        .frame(width: 38, height: 38)

                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Logic

    private func sendQuery(_ query: String) {
        chatMessages.append(AIChatMessage(text: query, isUser: true))

        // Simple intelligent local responses based on user context
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let reply = generateResponse(for: query)
            chatMessages.append(AIChatMessage(text: reply, isUser: false))
        }
    }

    private func generateResponse(for query: String) -> String {
        let lower = query.lowercased()
        let calGoal = profile?.dailyCalorieGoal ?? 2000
        let protGoal = profile?.dailyProteinGoalG ?? 120
        let waterGoal = profile?.dailyWaterGoalML ?? 2000

        if lower.contains("protein") {
            return "Your daily protein target is \(protGoal)g. Great high-protein options include chicken breast (31g per 100g), Greek yogurt (15g per cup), eggs (6g each), and protein shakes (25g per scoop)."
        } else if lower.contains("water") || lower.contains("drink") {
            return "Your daily hydration target is \(waterGoal) ml. Consistent sips throughout the day boost energy and metabolism. Logging after every glass helps you stay on track!"
        } else if lower.contains("dinner") || lower.contains("snack") || lower.contains("meal") || lower.contains("recipe") {
            return "Here's a 400 kcal idea: Grilled chicken breast (150g) with 1 cup steamed broccoli and half a cup of quinoa. It gives ~40g of protein and under 400 kcal."
        } else if lower.contains("calorie") {
            return "Your daily calorie goal is \(calGoal) kcal. Focus on nutrient-dense whole foods to stay satiated while meeting your daily targets."
        } else {
            return "Based on your profile, you're tracking towards \(calGoal) kcal, \(protGoal)g protein, and \(waterGoal) ml water daily. Consistency is key!"
        }
    }
}

struct AIChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

#Preview {
    NavigationStack {
        AIView()
    }
    .modelContainer(PreviewData.container)
}
