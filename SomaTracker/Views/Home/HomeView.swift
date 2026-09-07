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
    @State private var selectedDate: Date? = nil
    @State private var didPrepareToday = false
    @State private var showHistorySheet = false
    @State private var dragOffset: CGFloat = 0
    @State private var isDraggingSheet = false
    @State private var hasInitializedGoalStatus = false

    private var profile: UserProfile? {
        profiles.first
    }

    private var targetDate: Date {
        selectedDate ?? Calendar.current.startOfDay(for: .now)
    }

    private var isViewingToday: Bool {
        Calendar.current.isDateInToday(targetDate)
    }

    private var activeLogs: [DailyLog] {
        let calendar = Calendar.current
        return logs.filter { calendar.isDate($0.date, inSameDayAs: targetDate) }
    }

    private var activeLog: DailyLog? {
        activeLogs.first
    }

    private var todayLog: DailyLog? {
        let today = Calendar.current.startOfDay(for: .now)
        return logs.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    private var dailyCalorieGoal: Int {
        profile?.dailyCalorieGoal ?? 2_000
    }

    private var consumedCalories: Int {
        activeLogs.reduce(0) { $0 + $1.totalCalories }
    }

    private var isGoalReached: Bool {
        consumedCalories >= dailyCalorieGoal && dailyCalorieGoal > 0
    }

    private var isOverGoal: Bool {
        consumedCalories > dailyCalorieGoal && dailyCalorieGoal > 0
    }

    private var overCaloriesAmount: Int {
        max(consumedCalories - dailyCalorieGoal, 0)
    }

    private var remainingCalories: Int {
        max(dailyCalorieGoal - consumedCalories, 0)
    }

    private var displayedCalories: Int {
        if selectedMode == .remaining {
            return isOverGoal ? overCaloriesAmount : remainingCalories
        } else {
            return consumedCalories
        }
    }

    private var displayedCalorieLabel: String {
        if selectedMode == .remaining {
            if isOverGoal {
                return "Over Target"
            } else if isGoalReached {
                return "Goal Met"
            } else {
                return "Remaining"
            }
        } else {
            return "Consumed"
        }
    }

    private var heroSubtitle: String {
        if isViewingToday {
            if selectedMode == .remaining {
                if isOverGoal {
                    return "kcal · Over Target Today"
                } else if isGoalReached {
                    return "Daily target reached · Great job!"
                } else {
                    return "kcal · Remaining Today"
                }
            } else {
                return "kcal · Consumed Today"
            }
        } else {
            let dayString = targetDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            if selectedMode == .remaining {
                if isOverGoal {
                    return "kcal · Over Target · \(dayString)"
                } else if isGoalReached {
                    return "Daily target reached · \(dayString)"
                } else {
                    return "kcal · Remaining · \(dayString)"
                }
            } else {
                return "kcal · Consumed · \(dayString)"
            }
        }
    }

    private var dailyWaterGoal: Int {
        profile?.dailyWaterGoalML ?? 2_000
    }

    private var dailyProteinGoal: Int {
        profile?.dailyProteinGoalG ?? 120
    }

    private var consumedProtein: Double {
        activeLogs.reduce(0.0) { $0 + $1.totalProtein }
    }

    private var consumedWater: Int {
        activeLogs.reduce(0) { $0 + $1.totalWater }
    }

    private var displayedProtein: Double {
        selectedMode == .remaining ? Double(max(dailyProteinGoal - Int(consumedProtein.rounded()), 0)) : consumedProtein
    }

    private var displayedWater: Int {
        selectedMode == .remaining ? max(dailyWaterGoal - consumedWater, 0) : consumedWater
    }

    private var totalStepsTaken: Int {
        let maxLogSteps = activeLogs.map(\.steps).max() ?? 0
        if isViewingToday {
            return healthKitManager.todaySteps > 0 ? healthKitManager.todaySteps : maxLogSteps
        } else {
            return maxLogSteps
        }
    }

    private var displayedSteps: Int {
        selectedMode == .remaining ? max(dailyStepGoal - totalStepsTaken, 0) : totalStepsTaken
    }

    private var dailyStepGoal: Int { profile?.dailyStepGoal ?? 10_000 }

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

    // Compares active day's overall health metrics (calories, protein, water, steps) against the previous day.
    private var compositeTrend: (text: String, isUp: Bool, hasData: Bool, label: String) {
        let calendar = Calendar.current
        let currentDay = targetDate
        guard let prevDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else {
            return ("—", true, false, "vs yesterday")
        }

        let prevLogs = logs.filter { calendar.isDate($0.date, inSameDayAs: prevDay) }

        let calGoal = Double(max(dailyCalorieGoal, 1))
        let proteinGoal = Double(max(dailyProteinGoal, 1))
        let waterGoal = Double(max(dailyWaterGoal, 1))
        let stepGoal = Double(max(dailyStepGoal, 1))

        // Previous day metrics
        let prevCal = Double(prevLogs.reduce(0) { $0 + $1.totalCalories })
        let prevProtein = prevLogs.reduce(0.0) { $0 + $1.totalProtein }
        let prevWater = Double(prevLogs.reduce(0) { $0 + $1.totalWater })
        let prevSteps = Double(prevLogs.map(\.steps).max() ?? 0)

        // Current day metrics
        let currCal = Double(consumedCalories)
        let currProtein = consumedProtein
        let currWater = Double(consumedWater)
        let currSteps = Double(totalStepsTaken)

        // Composite fulfillment scores across all 4 pillars
        let prevScore = (min(prevCal / calGoal, 1.5)
                       + min(prevProtein / proteinGoal, 1.5)
                       + min(prevWater / waterGoal, 1.5)
                       + min(prevSteps / stepGoal, 1.5)) / 4.0

        let currScore = (min(currCal / calGoal, 1.5)
                       + min(currProtein / proteinGoal, 1.5)
                       + min(currWater / waterGoal, 1.5)
                       + min(currSteps / stepGoal, 1.5)) / 4.0

        let dayComparisonName = isViewingToday ? "yesterday" : prevDay.formatted(.dateTime.weekday(.abbreviated))

        guard prevScore > 0.01 else {
            return ("—", true, false, "vs \(dayComparisonName)")
        }

        let change = ((currScore - prevScore) / prevScore) * 100.0
        let rounded = Int(change.rounded())

        let displayText: String
        if abs(rounded) > 999 {
            displayText = "\(rounded >= 0 ? "+" : "-")999%"
        } else {
            displayText = "\(abs(rounded))%"
        }

        let isUp = rounded >= 0
        let labelText: String
        if rounded == 0 {
            labelText = "Same as \(dayComparisonName)"
        } else if isUp {
            labelText = "Higher than \(dayComparisonName)"
        } else {
            labelText = "Lower than \(dayComparisonName)"
        }

        return (displayText, isUp, true, labelText)
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

                    WeeklyBarChart(logs: logs, selectedDate: $selectedDate, calorieGoal: dailyCalorieGoal)
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
                DailyLog.deduplicateAllLogs(context: modelContext)

                guard !didPrepareToday else { return }
                didPrepareToday = true

                _ = DailyLog.fetchOrCreateToday(context: modelContext)
                try? modelContext.save()

                await healthKitManager.requestAuthorization()
                await healthKitManager.refreshTodaySteps(modelContext: modelContext)
                healthKitManager.startObserving(modelContext: modelContext)

                hasInitializedGoalStatus = true
            }
            .onChange(of: isGoalReached) { wasReached, isReached in
                guard hasInitializedGoalStatus, isViewingToday else { return }
                if !wasReached && isReached {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        }
    }

    private var topChrome: some View {
        let trend = compositeTrend
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

            // Trend column — today's intake vs yesterday across all pillars
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

                Text(trend.label)
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
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.35),
                                            Color.white.opacity(0.10)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 3)

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
                .background(SomaColors.coral)
                .clipShape(RoundedRectangle(cornerRadius: 11 * scale, style: .continuous))
                .padding(.top, 14 * scale)

            Text(isOverGoal && selectedMode == .remaining ? "+\(displayedCalories.formatted())" : displayedCalories.formatted())
                .font(.system(size: 78 * scale, weight: .black, design: .default))
                .foregroundStyle(Color(.label))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.22), value: displayedCalories)
                .padding(.top, 12 * scale)

            HStack(spacing: 8) {
                Text(heroSubtitle)
                    .font(.system(size: 15 * scale, weight: .bold, design: .default))
                    .foregroundStyle(Color(.secondaryLabel))
                    .animation(.snappy(duration: 0.22), value: heroSubtitle)

                if !isViewingToday {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.snappy(duration: 0.22)) {
                            selectedDate = nil
                        }
                    } label: {
                        Text("Today")
                            .font(.system(size: 11 * scale, weight: .bold))
                            .foregroundStyle(Color.orange)
                            .padding(.horizontal, 8 * scale)
                            .padding(.vertical, 3 * scale)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }

            SomaSegmentedToggle(selection: $selectedMode)
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
