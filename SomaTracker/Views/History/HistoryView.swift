import SwiftUI
import SwiftData

enum HistoryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case food = "Food"
    case water = "Water"
    case steps = "Steps"

    var id: Self { self }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .food: return "fork.knife"
        case .water: return "drop.fill"
        case .steps: return "figure.walk"
        }
    }
}

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]
    @AppStorage(Units.storageKey) private var unitSystemRaw = UnitSystem.metric.rawValue

    @State private var searchText = ""
    @State private var selectedFilter: HistoryFilter = .all
    @State private var showExportSheet = false

    private var unitSystem: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    private var filteredLogs: [DailyLog] {
        let baseLogs: [DailyLog]
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if query.isEmpty {
            baseLogs = logs.filter { !$0.foodEntries.isEmpty || !$0.waterEntries.isEmpty || $0.steps > 0 }
        } else {
            baseLogs = logs.filter { log in
                matchesDate(log.date, query: query) ||
                matchesType(log: log, query: query) ||
                log.foodEntries.contains { entry in
                    entry.name.localizedCaseInsensitiveContains(query) ||
                    entry.mealType.localizedCaseInsensitiveContains(query)
                }
            }
        }

        // Apply category filter
        switch selectedFilter {
        case .all:
            return baseLogs
        case .food:
            return baseLogs.filter { !$0.foodEntries.isEmpty }
        case .water:
            return baseLogs.filter { !$0.waterEntries.isEmpty }
        case .steps:
            return baseLogs.filter { $0.steps > 0 }
        }
    }

    var body: some View {
        List {
            // Milestone Streak Banner
            if searchText.isEmpty && !logs.isEmpty && selectedFilter == .all {
                streakBannerSection
            }

            // Quick Category Filters
            if searchText.isEmpty {
                filterSection
            }

            if filteredLogs.isEmpty {
                emptyStateView
                    .listRowBackground(Color.clear)
            } else {
                ForEach(filteredLogs) { log in
                    Section {
                        // Habits Summary Row
                        if selectedFilter == .all {
                            dayHabitsStrip(for: log)
                        }

                        // Food Entries
                        if selectedFilter == .all || selectedFilter == .food {
                            ForEach(matchingFoodEntries(for: log)) { entry in
                                foodEntryRow(entry, in: log)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deleteFoodEntry(entry, from: log)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }

                        // Water Entries
                        if (selectedFilter == .all || selectedFilter == .water) && shouldShowWater(for: log) {
                            ForEach(log.waterEntries.sorted(by: { $0.timestamp > $1.timestamp })) { entry in
                                waterEntryRow(entry)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deleteWaterEntry(entry, from: log)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }

                        // Steps Entry
                        if selectedFilter == .steps && log.steps > 0 {
                            stepsEntryRow(for: log)
                        }
                    } header: {
                        daySectionHeader(for: log)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search dates, foods, calories, water, steps...")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showExportSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(SomaColors.navy)
                }
                .accessibilityLabel("Export Data")
            }
        }
        .sheet(isPresented: $showExportSheet) {
            ExportDatePickerSheet(logs: logs)
                .preferredColorScheme(.light)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        Section {
            Picker("Filter", selection: $selectedFilter) {
                ForEach(HistoryFilter.allCases) { filter in
                    Label(filter.rawValue, systemImage: filter.icon).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
        }
    }

    // MARK: - Streak Banner

    private var streakBannerSection: some View {
        let streak = StreakCalculator.calculate(from: logs)

        return Section {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: streak.currentStreak > 0
                                    ? [SomaColors.streakOrange, SomaColors.coral]
                                    : [Color(.systemGray4), Color(.systemGray5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: (streak.currentStreak > 0 ? SomaColors.streakOrange : Color.clear).opacity(0.35), radius: 6, x: 0, y: 3)

                    Image(systemName: "flame.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(streak.currentStreak > 0 ? "\(streak.currentStreak)-Day Streak!" : "Start Your Streak Today!")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(.label))

                    Text(streak.hasLoggedToday ? "Logged today • Keep the streak alive!" : "Log calories or water to keep it active.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(.secondaryLabel))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("RECORD")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(.tertiaryLabel))

                    Text("\(streak.bestStreak)d")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(SomaColors.navy)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(.vertical, 2)
        } header: {
            Text("STREAK & MILESTONES")
        }
    }

    // MARK: - Day Section Header

    private func daySectionHeader(for log: DailyLog) -> some View {
        HStack {
            Text(formatDate(log.date))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(.label))

            Spacer()

            if log.totalCalories > 0 {
                Text("\(log.totalCalories.formatted()) kcal")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(SomaColors.coral)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(SomaColors.coral.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Day Habits Strip

    private func dayHabitsStrip(for log: DailyLog) -> some View {
        HStack(spacing: 8) {
            if log.steps > 0 {
                habitChip(
                    icon: "figure.walk",
                    text: "\(log.steps.formatted())",
                    color: SomaColors.emerald
                )
            }

            if log.totalWater > 0 {
                let amount = Units.waterValue(ml: log.totalWater, system: unitSystem)
                habitChip(
                    icon: "drop.fill",
                    text: "\(amount) \(Units.waterUnit(unitSystem))",
                    color: SomaColors.aqua
                )
            }

            if log.totalProtein > 0 {
                habitChip(
                    icon: "leaf.fill",
                    text: "\(Int(log.totalProtein.rounded()))g",
                    color: SomaColors.iris
                )
            }

            if log.steps == 0 && log.totalWater == 0 && log.totalProtein == 0 {
                Text("No additional activity recorded")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(.tertiaryLabel))
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private func habitChip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Food Entry Row

    private func foodEntryRow(_ entry: FoodEntry, in log: DailyLog) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(SomaColors.coral.opacity(0.15))
                    .frame(width: 38, height: 38)

                Image(systemName: "fork.knife")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(SomaColors.coral)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(resolvedFoodTitle(entry))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(.label))

                Text(formatTime(entry.timestamp))
                    .font(.system(size: 12))
                    .foregroundStyle(Color(.secondaryLabel))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(entry.calories) kcal")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(SomaColors.coral)

                if entry.proteinG > 0 {
                    Text("\(Int(entry.proteinG.rounded()))g protein")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(SomaColors.iris)
                }
            }
        }
        .padding(.vertical, 3)
    }

    // MARK: - Water Entry Row

    private func waterEntryRow(_ entry: WaterEntry) -> some View {
        let displayAmount = Units.waterValue(ml: entry.amount, system: unitSystem)
        let unitString = Units.waterUnit(unitSystem)

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(SomaColors.aqua.opacity(0.15))
                    .frame(width: 38, height: 38)

                Image(systemName: "drop.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(SomaColors.aqua)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Water Intake")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(.label))

                Text(formatTime(entry.timestamp))
                    .font(.system(size: 12))
                    .foregroundStyle(Color(.secondaryLabel))
            }

            Spacer()

            Text("+\(displayAmount) \(unitString)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(SomaColors.aqua)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Steps Entry Row

    private func stepsEntryRow(for log: DailyLog) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(SomaColors.emerald.opacity(0.15))
                    .frame(width: 38, height: 38)

                Image(systemName: "figure.walk")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(SomaColors.emerald)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Daily Steps")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(.label))

                Text("Activity synced")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(.secondaryLabel))
            }

            Spacer()

            Text("\(log.steps.formatted()) steps")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(SomaColors.emerald)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(Color(.tertiaryLabel))
                .padding(.top, 40)

            Text(searchText.isEmpty ? "No Logs Yet" : "No Matching History")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(.label))

            Text(searchText.isEmpty
                ? "Start tracking your meals, water, and activity to build your timeline."
                : "Try searching for a different date, food item, or keyword.")
                .font(.system(size: 14))
                .foregroundStyle(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Search Filtering Helpers

    private func matchesDate(_ date: Date, query: String) -> Bool {
        let calendar = Calendar.current
        let lowerQuery = query.lowercased()

        if "today".starts(with: lowerQuery) && calendar.isDateInToday(date) { return true }
        if "yesterday".starts(with: lowerQuery) && calendar.isDateInYesterday(date) { return true }

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"
        let fullMonth = monthFormatter.string(from: date).lowercased()

        monthFormatter.dateFormat = "MMM"
        let shortMonth = monthFormatter.string(from: date).lowercased()

        if fullMonth.contains(lowerQuery) || shortMonth.contains(lowerQuery) { return true }

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEEE"
        let fullWeekday = weekdayFormatter.string(from: date).lowercased()

        weekdayFormatter.dateFormat = "EEE"
        let shortWeekday = weekdayFormatter.string(from: date).lowercased()

        if fullWeekday.contains(lowerQuery) || shortWeekday.contains(lowerQuery) { return true }

        let dayNumber = "\(calendar.component(.day, from: date))"
        if dayNumber == lowerQuery { return true }

        let yearNumber = "\(calendar.component(.year, from: date))"
        if yearNumber.contains(lowerQuery) { return true }

        return false
    }

    private func matchesType(log: DailyLog, query: String) -> Bool {
        let waterKeywords = ["water", "drink", "hydrat", "ml", "oz", "fluid"]
        let calorieKeywords = ["calorie", "cal", "kcal", "food", "eat", "meal"]
        let proteinKeywords = ["protein", "prot", "gram", "macro"]
        let stepKeywords = ["step", "walk", "activity", "move"]

        if waterKeywords.contains(where: { $0.contains(query) || query.contains($0) }) && log.totalWater > 0 {
            return true
        }
        if calorieKeywords.contains(where: { $0.contains(query) || query.contains($0) }) && log.totalCalories > 0 {
            return true
        }
        if proteinKeywords.contains(where: { $0.contains(query) || query.contains($0) }) && log.totalProtein > 0 {
            return true
        }
        if stepKeywords.contains(where: { $0.contains(query) || query.contains($0) }) && log.steps > 0 {
            return true
        }

        return false
    }

    private func matchingFoodEntries(for log: DailyLog) -> [FoodEntry] {
        let sorted = log.foodEntries.sorted(by: { $0.timestamp > $1.timestamp })
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return sorted }

        if matchesDate(log.date, query: query) || matchesType(log: log, query: query) {
            return sorted
        }

        return sorted.filter { entry in
            entry.name.localizedCaseInsensitiveContains(query) ||
            entry.mealType.localizedCaseInsensitiveContains(query)
        }
    }

    private func shouldShowWater(for log: DailyLog) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return !log.waterEntries.isEmpty }

        let waterKeywords = ["water", "drink", "hydrat", "ml", "oz", "fluid"]
        if waterKeywords.contains(where: { $0.contains(query) || query.contains($0) }) {
            return !log.waterEntries.isEmpty
        }

        return matchesDate(log.date, query: query) && !log.waterEntries.isEmpty
    }

    private func resolvedFoodTitle(_ entry: FoodEntry) -> String {
        let trimmed = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if !entry.mealType.isEmpty { return entry.mealType.capitalized }
        return "Calories Logged"
    }

    // MARK: - Mutation Helpers

    private func deleteFoodEntry(_ entry: FoodEntry, from log: DailyLog) {
        withAnimation(.snappy) {
            log.foodEntries.removeAll { $0.id == entry.id }
            modelContext.delete(entry)
            try? modelContext.save()
        }
    }

    private func deleteWaterEntry(_ entry: WaterEntry, from log: DailyLog) {
        withAnimation(.snappy) {
            log.waterEntries.removeAll { $0.id == entry.id }
            modelContext.delete(entry)
            try? modelContext.save()
        }
    }

    // MARK: - Date Formats

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMM yyyy"
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        HistoryView()
            .modelContainer(PreviewData.container)
    }
}
