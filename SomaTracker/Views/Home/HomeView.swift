import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var appRouter
    @Query(sort: \DailyLog.date) private var logs: [DailyLog]
    @Query private var profiles: [UserProfile]

    let healthKitManager: HealthKitManager

    @AppStorage(Units.storageKey) private var unitSystemRaw = UnitSystem.metric.rawValue
    private var unitSystem: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    @State private var selectedMode: SomaSegmentedToggleOption = .remaining
    @State private var didPrepareToday = false
    @State private var showHistorySheet = false
    @State private var dragOffset: CGFloat = 0
    @State private var isDraggingSheet = false

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

    private var totalStepsTaken: Int {
        healthKitManager.todaySteps > 0 ? healthKitManager.todaySteps : (todayLog?.steps ?? 0)
    }

    private var displayedSteps: Int {
        selectedMode == .remaining ? max(dailyStepGoal - totalStepsTaken, 0) : totalStepsTaken
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
        let steps = totalStepsTaken
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
            // Panel scales with the screen; content scales to fit so the stats
            // never clip behind the floating tab bar on shorter phones.
            let panelHeight = max(430, proxy.size.height * 0.56)
            let bottomClearance: CGFloat = 100          // white space that clears the floating tab bar
            let referenceContentHeight: CGFloat = 413   // measured stats content height at scale 1.0
            let safetyMargin: CGFloat = 16
            let contentScale = min(1.0, max(0.78, (panelHeight - bottomClearance - safetyMargin) / referenceContentHeight))

            ZStack(alignment: .bottom) {
                SomaColors.navy
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    topChrome
                        .padding(.horizontal, 24)
                        .padding(.top, 48)

                    WeeklyBarChart(logs: logs)
                        .padding(.top, 36)
                        .padding(.horizontal, 16)

                    Spacer(minLength: panelHeight - 16)
                }

                statsPanel(scale: contentScale, bottomClearance: bottomClearance)
                    .frame(height: panelHeight, alignment: .top)
            }
            .sheet(isPresented: $showHistorySheet) {
                NavigationStack {
                    HistoryView(isModal: true)
                }
                .preferredColorScheme(.light)
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
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.35), value: steps.number)
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
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.35), value: trend.text)
                }

                Text(!trend.hasData
                    ? "vs yesterday"
                    : (trend.isUp ? "Higher than yesterday" : "Lower than yesterday"))
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundStyle(SomaColors.white.opacity(0.6))
            }

            Spacer(minLength: 8)

            // Native Liquid Glass History Button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showHistorySheet = true
            } label: {
                ZStack {
                    Color.clear
                        .frame(width: 56, height: 56)
                        .glassEffect(.regular, in: .circle)

                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 22, weight: .bold, design: .default))
                        .foregroundStyle(SomaColors.white)
                }
                .frame(width: 56, height: 56)
                .contentShape(Circle())
            }
            .buttonStyle(LiquidGlassButtonStyle())
            .accessibilityLabel("Log History")
        }
    }

    private var visualPullOffset: CGFloat {
        if dragOffset < 0 {
            // Smooth rubber-band spring dampening up to -65pt
            return min(0, max(-65, dragOffset * 0.45))
        }
        return 0
    }

    private func statsPanel(scale: CGFloat, bottomClearance: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Interactive grabber handle
            Capsule()
                .fill(isDraggingSheet ? SomaColors.navy.opacity(0.5) : Color(.systemGray4))
                .frame(width: isDraggingSheet ? 48 : 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 8 * scale)
                .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8), value: isDraggingSheet)
                .contentShape(Rectangle())
                .onTapGesture {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    appRouter.showLogSheet = true
                }

            Image(systemName: "flame.fill")
                .font(.system(size: 19 * scale, weight: .bold, design: .default))
                .foregroundStyle(SomaColors.white)
                .frame(width: 40 * scale, height: 40 * scale)
                .background(Color.orange)
                .clipShape(RoundedRectangle(cornerRadius: 11 * scale, style: .continuous))
                .padding(.top, 14 * scale)

            Text(displayedCalories.formatted())
                .font(.system(size: 78 * scale, weight: .black, design: .default))
                .foregroundStyle(Color(.label))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.35, extraBounce: 0.05), value: displayedCalories)
                .padding(.top, 12 * scale)

            Text(heroSubtitle)
                .font(.system(size: 15, weight: .bold, design: .default))
                .foregroundStyle(Color(.secondaryLabel))
                .animation(.snappy(duration: 0.3), value: heroSubtitle)

            SomaSegmentedToggle(selection: $selectedMode.animation(.snappy(duration: 0.28)))
                .padding(.top, 18 * scale)

            StatsGridView(
                calorieValue: displayedCalories,
                calorieLabel: displayedCalorieLabel,
                proteinG: displayedProtein,
                waterValue: Units.waterValue(ml: displayedWater, system: unitSystem),
                waterUnit: Units.waterUnit(unitSystem),
                steps: displayedSteps,
                scale: scale
            )
            .padding(.top, 10 * scale)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
        .padding(.bottom, bottomClearance)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 24,
                style: .continuous
            )
            .fill(SomaColors.white)
            .padding(.bottom, -250)
        )
        .offset(y: visualPullOffset)
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.85), value: visualPullOffset)
        .contentShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 24,
                style: .continuous
            )
        )
        .gesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .local)
                .onChanged { value in
                    if value.translation.height < 0 {
                        isDraggingSheet = true
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    let shouldOpen = value.translation.height < -25 || value.predictedEndTranslation.height < -40
                    if shouldOpen {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        appRouter.showLogSheet = true
                    }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                        dragOffset = 0
                        isDraggingSheet = false
                    }
                }
        )
        .ignoresSafeArea(edges: .bottom)
    }

}

#Preview {
    HomeView(healthKitManager: HealthKitManager())
        .modelContainer(PreviewData.container)
}
