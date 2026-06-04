import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyLog.date) private var logs: [DailyLog]
    @Query private var profiles: [UserProfile]

    let healthKitManager: HealthKitManager

    @State private var selectedMode: SomaSegmentedToggleOption = .remaining
    @State private var didPrepareToday = false
    @State private var showWaterDetail = false

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

    private var yesterdayCalories: Int {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: .now)) else {
            return 0
        }
        return logs.first { calendar.isDate($0.date, inSameDayAs: yesterday) }?.totalCalories ?? 0
    }

    private var dailyStepGoal: Int { 10_000 }

    // Steps remaining to goal, or steps beyond goal once reached.
    private var stepProgress: (number: Int, label: String, icon: String, reached: Bool) {
        let steps = displayedSteps
        let goal = dailyStepGoal

        if steps >= goal {
            return (steps - goal, "Steps ahead", "arrow.up", true)
        } else {
            return (goal - steps, "Steps to go", "figure.walk", false)
        }
    }

    // Compares today's consumed calories against yesterday's.
    private var calorieTrend: (text: String, isUp: Bool, hasData: Bool) {
        let today = consumedCalories
        let yesterday = yesterdayCalories

        guard yesterday > 0 else {
            // No baseline to compare against yet.
            return ("—", true, false)
        }

        let change = (Double(today - yesterday) / Double(yesterday)) * 100
        let rounded = Int(change.rounded())
        return ("\(abs(rounded))%", rounded >= 0, true)
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
            .sheet(isPresented: $showWaterDetail) {
                WaterLogSheetView()
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
        let trend = calorieTrend
        let steps = stepProgress
        let trendColor: Color = !trend.hasData
            ? SomaColors.white.opacity(0.7)
            : (trend.isUp
                ? Color(red: 0.36, green: 0.92, blue: 0.55)
                : Color(red: 1.0, green: 0.56, blue: 0.46))

        return HStack(alignment: .center, spacing: 14) {
            // Steps column
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: steps.icon)
                        .font(.system(size: 15, weight: .bold, design: .default))
                        .foregroundStyle(SomaColors.white)

                    Text(steps.number.formatted())
                        .font(.system(size: 22, weight: .bold, design: .default))
                        .foregroundStyle(SomaColors.white)
                }

                Text(steps.label)
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundStyle(SomaColors.white.opacity(0.6))
            }

            // Divider
            Rectangle()
                .fill(SomaColors.white.opacity(0.2))
                .frame(width: 1, height: 38)

            // Trend column — today's intake vs yesterday
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: trend.isUp ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis")
                        .font(.system(size: 14, weight: .bold, design: .default))
                        .foregroundStyle(trendColor)

                    Text(trend.text)
                        .font(.system(size: 22, weight: .bold, design: .default))
                        .foregroundStyle(trendColor)
                }

                Text(!trend.hasData
                    ? "vs yesterday"
                    : (trend.isUp ? "Higher than yesterday" : "Lower than yesterday"))
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundStyle(SomaColors.white.opacity(0.6))
            }

            Spacer(minLength: 8)

            // Water intake button — Liquid Glass circle
            ZStack {
                Color.clear
                    .frame(width: 56, height: 56)
                    .glassEffect(.regular, in: .circle)

                Image(systemName: "waterbottle.fill")
                    .font(.system(size: 23, weight: .bold, design: .default))
                    .foregroundStyle(SomaColors.white)
            }
            .frame(width: 56, height: 56)
            .contentShape(Circle())
            .onTapGesture {
                showWaterDetail = true
            }
            .accessibilityLabel("Water intake")
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

}

#Preview {
    HomeView(healthKitManager: HealthKitManager())
        .modelContainer(PreviewData.container)
}
