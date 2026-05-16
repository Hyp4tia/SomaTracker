import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyLog.date) private var logs: [DailyLog]
    @Query private var profiles: [UserProfile]

    let healthKitManager: HealthKitManager

    @State private var selectedMode: SomaSegmentedToggleOption = .remaining
    @State private var didPrepareToday = false

    private var profile: UserProfile? {
        profiles.first
    }

    private var todayLog: DailyLog? {
        let today = Calendar.current.startOfDay(for: .now)
        return logs.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    private var dailyCalorieGoal: Int {
        profile?.dailyCalorieGoal ?? 2_000
    }

    private var consumedCalories: Int {
        todayLog?.totalCalories ?? 0
    }

    private var remainingCalories: Int {
        max(dailyCalorieGoal - consumedCalories, 0)
    }

    private var displayedCalories: Int {
        selectedMode == .remaining ? remainingCalories : consumedCalories
    }

    private var displayedCalorieLabel: String {
        selectedMode == .remaining ? "Remaining" : "Consumed"
    }

    private var heroSubtitle: String {
        "kcal · \(displayedCalorieLabel) Today"
    }

    private var dailyWaterGoal: Int {
        profile?.dailyWaterGoalML ?? 2_000
    }

    private var dailyProteinGoal: Int {
        profile?.dailyProteinGoalG ?? 120
    }

    private var consumedProtein: Double {
        todayLog?.totalProtein ?? 0
    }

    private var consumedWater: Int {
        todayLog?.totalWater ?? 0
    }

    private var displayedProtein: Double {
        selectedMode == .remaining ? Double(max(dailyProteinGoal - Int(consumedProtein.rounded()), 0)) : consumedProtein
    }

    private var displayedWater: Int {
        selectedMode == .remaining ? max(dailyWaterGoal - consumedWater, 0) : consumedWater
    }

    private var displayedSteps: Int {
        healthKitManager.todaySteps > 0 ? healthKitManager.todaySteps : (todayLog?.steps ?? 0)
    }

    var body: some View {
        GeometryReader { proxy in
            let panelHeight = max(464, proxy.size.height * 0.55)

            ZStack(alignment: .bottom) {
                SomaColors.navy
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    topChrome
                        .padding(.horizontal, 24)
                        .padding(.top, 48)

                    WeeklyBarChart(logs: logs)
                        .padding(.top, 44)
                        .padding(.horizontal, 6)

                    Spacer(minLength: panelHeight - 16)
                }

                statsPanel
                    .frame(height: panelHeight)
            }
            .task {
                guard !didPrepareToday else { return }
                didPrepareToday = true

                _ = DailyLog.fetchOrCreateToday(context: modelContext)
                try? modelContext.save()

                await healthKitManager.requestAuthorization()
                await healthKitManager.refreshTodaySteps(modelContext: modelContext)
                healthKitManager.startObserving(modelContext: modelContext)
            }
        }
    }

    private var topChrome: some View {
        HStack {
            HStack(spacing: 7) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 12, weight: .bold, design: .default))

                Text("69%")
                    .foregroundStyle(Color(red: 0.38, green: 0.82, blue: 1.0))

                Text("vs yesterday")
                    .foregroundStyle(SomaColors.white)
            }
            .font(.system(size: 14, weight: .bold, design: .default))
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(SomaColors.white.opacity(0.22))
            .clipShape(Capsule())

            Spacer()

            Button {} label: {
                Text(profileInitials)
                    .font(.system(size: 16, weight: .bold, design: .default))
                    .foregroundStyle(SomaColors.navy)
                    .frame(width: 48, height: 48)
                    .background(SomaColors.white.opacity(0.68))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Profile")
        }
    }

    private var statsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "flame.fill")
                .font(.system(size: 19, weight: .bold, design: .default))
                .foregroundStyle(SomaColors.white)
                .frame(width: 40, height: 40)
                .background(Color.orange)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .padding(.top, 24)

            Text(displayedCalories.formatted())
                .font(.system(size: 78, weight: .black, design: .default))
                .foregroundStyle(Color(.label))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 12)

            Text(heroSubtitle)
                .font(.system(size: 15, weight: .bold, design: .default))
                .foregroundStyle(Color(.secondaryLabel))
                .padding(.top, 0)

            SomaSegmentedToggle(selection: $selectedMode)
                .padding(.top, 18)

            StatsGridView(
                calorieValue: displayedCalories,
                calorieLabel: displayedCalorieLabel,
                proteinG: displayedProtein,
                waterML: displayedWater,
                steps: displayedSteps
            )
            .padding(.top, 10)

            Spacer(minLength: 86)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 80)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SomaColors.white)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 24,
                style: .continuous
            )
        )
        .ignoresSafeArea(edges: .bottom)
    }

    private var profileInitials: String {
        guard let name = profile?.name.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return "S"
        }

        let initials = name
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()

        return initials.isEmpty ? "S" : initials.uppercased()
    }
}

#Preview {
    HomeView(healthKitManager: HealthKitManager())
        .modelContainer(PreviewData.container)
}
