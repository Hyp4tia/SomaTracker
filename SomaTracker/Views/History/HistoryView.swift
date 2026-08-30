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
    var isModal: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]
    @AppStorage(Units.storageKey) private var unitSystemRaw = UnitSystem.metric.rawValue

    @State private var searchText = ""
    @State private var selectedFilter: HistoryFilter = .all
    @State private var showExportSheet = false

    private var unitSystem: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    private var filteredLogs: [DailyLog] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let baseLogs: [DailyLog]
        if query.isEmpty {
            baseLogs = logs.filter { !$0.foodEntries.isEmpty || !$0.waterEntries.isEmpty || $0.steps > 0 }
        } else {
            baseLogs = logs.filter { log in
                matchesDate(log.date, query: query) ||
                !matchingFoodEntries(for: log).isEmpty ||
                !matchingWaterEntries(for: log).isEmpty ||
                (isStepsQuery(query) && shouldShowSteps(for: log))
            }
        }

        // Apply category filter
        switch selectedFilter {
        case .all:
            return baseLogs
        case .food:
            return baseLogs.filter { !matchingFoodEntries(for: $0).isEmpty }
        case .water:
            return baseLogs.filter { !matchingWaterEntries(for: $0).isEmpty }
        case .steps:
            return baseLogs.filter { shouldShowSteps(for: $0) }
        }
    }

    var body: some View {
        List {
            // Milestone Streak Banner
            if searchText.isEmpty && !logs.isEmpty && selectedFilter == .all {
                streakBannerSection
            }

            // Quick Category Filters (Native Segmented Picker)
            if searchText.isEmpty {
                filterSection
            }

            if filteredLogs.isEmpty {
                emptyStateView
                    .listRowBackground(Color.clear)
            } else {
                ForEach(filteredLogs) { log in
                    Section {
                        // Food Entries
                        if selectedFilter == .all || selectedFilter == .food {
                            let foods = matchingFoodEntries(for: log)
                            ForEach(foods) { entry in
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
                        if selectedFilter == .all || selectedFilter == .water {
                            let waters = matchingWaterEntries(for: log)
                            ForEach(waters) { entry in
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
                        if (selectedFilter == .steps || (selectedFilter == .all && isStepsQuery(searchText))) && shouldShowSteps(for: log) {
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
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .automatic,
            prompt: "Search dates, foods, macros, water, steps..."
        )
        .scrollContentBackground(.visible)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 24)
        }
        .toolbar {
            if isModal {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    } label: {
                        ZStack {
                            Color.clear
                                .frame(width: 32, height: 32)
                                .glassEffect(.regular, in: .circle)

                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(SomaColors.navy)
                        }
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                    }
                    .buttonStyle(LiquidGlassButtonStyle())
                    .accessibilityLabel("Done")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showExportSheet = true
                } label: {
                    ZStack {
                        Color.clear
                            .frame(width: 32, height: 32)
                            .glassEffect(.regular, in: .circle)

                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(SomaColors.navy)
                    }
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
                }
                .buttonStyle(LiquidGlassButtonStyle())
                .accessibilityLabel("Export Data")
            }
        }
        .sheet(isPresented: $showExportSheet) {
            ExportDatePickerSheet(logs: logs)
                .preferredColorScheme(.light)
                .presentationDetents([.fraction(0.70), .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(.systemGroupedBackground))
        }
        .onChange(of: selectedFilter) { _, _ in
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    // MARK: - Filter Section (Native iOS Segmented Control)

    private var filterSection: some View {
        Section {
            Picker("Category Filter", selection: $selectedFilter) {
                ForEach(HistoryFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Streak Banner

    private var streakBannerSection: some View {
        let streak = StreakCalculator.calculate(from: logs)

        return Section {
            HStack(spacing: 14) {
                // Solid orange flame icon matching HomeView design
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(streak.currentStreak > 0 ? Color.orange : Color(.systemGray4))
                        .frame(width: 42, height: 42)

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
                        .foregroundStyle(Color(.secondaryLabel))

                    Text("\(streak.bestStreak)d")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(SomaColors.navy)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(.vertical, 3)
        } header: {
            Text("STREAK & MILESTONES")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(.secondaryLabel))
        }
    }

    // MARK: - Unified Day Section Header (Right-Aligned Metric Cluster)

    private func daySectionHeader(for log: DailyLog) -> some View {
        HStack(spacing: 8) {
            Text(formatDate(log.date))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color(.label))

            Spacer()

            HStack(spacing: 6) {
                // Hydration Summary Pill
                if log.totalWater > 0 {
                    let amount = Units.waterValue(ml: log.totalWater, system: unitSystem)
                    let unitString = Units.waterUnit(unitSystem)
                    HStack(spacing: 3) {
                        Image(systemName: "drop.fill")
                            .font(.caption.weight(.semibold))
                        Text("+\(amount) \(unitString)")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(Color.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.10))
                    .clipShape(Capsule())
                }

                // Calories Summary Pill
                if log.totalCalories > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.caption.weight(.semibold))
                        Text("+\(log.totalCalories.formatted()) kcal")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(SomaColors.coral)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(SomaColors.coral.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
        }
        .textCase(nil)
    }

    // MARK: - Food Entry Row

    private func foodEntryRow(_ entry: FoodEntry, in log: DailyLog) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "fork.knife")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(SomaColors.coral)
                .frame(width: 28, height: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 3) {
                Text(resolvedFoodTitle(entry))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.label))
                    .lineLimit(1)

                Text(formatTime(entry.timestamp))
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))

                // Macro breakdown chips nested beneath item
                if entry.proteinG > 0 || entry.carbsG > 0 || entry.fatG > 0 {
                    HStack(spacing: 5) {
                        if entry.proteinG > 0 {
                            macroTag(
                                label: "P",
                                value: "\(Int(entry.proteinG.rounded()))g",
                                color: SomaColors.iris
                            )
                        }
                        if entry.carbsG > 0 {
                            macroTag(
                                label: "C",
                                value: "\(Int(entry.carbsG.rounded()))g",
                                color: SomaColors.amber
                            )
                        }
                        if entry.fatG > 0 {
                            macroTag(
                                label: "F",
                                value: "\(Int(entry.fatG.rounded()))g",
                                color: SomaColors.teal
                            )
                        }
                    }
                    .padding(.top, 1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(entry.effectiveCalories) kcal")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(SomaColors.coral)
            }
        }
        .padding(.vertical, 3)
    }

    private func macroTag(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(color)
            Text(value)
                .font(.caption2.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(Color(.label))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    // MARK: - Water Entry Row

    private func waterEntryRow(_ entry: WaterEntry) -> some View {
        let displayAmount = Units.waterValue(ml: entry.amount, system: unitSystem)
        let unitString = Units.waterUnit(unitSystem)

        return HStack(spacing: 14) {
            Image(systemName: "drop.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.blue)
                .frame(width: 28, height: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.resolvedTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.label))

                Text(formatTime(entry.timestamp))
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
            }

            Spacer()

            Text("+\(displayAmount) \(unitString)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.blue)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Steps Entry Row

    private func stepsEntryRow(for log: DailyLog) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "figure.walk")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.green)
                .frame(width: 28, height: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 3) {
                Text("Daily Steps")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.label))

                Text("Activity synced")
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
            }

            Spacer()

            Text("\(log.steps.formatted()) steps")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.green)
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

    // MARK: - Search & Filtering Helpers

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

    private func isFoodQuery(_ query: String) -> Bool {
        let keywords = ["food", "eat", "meal", "calorie", "calories", "kcal", "snack", "breakfast", "lunch", "dinner"]
        return keywords.contains(where: { $0.contains(query) || query.contains($0) })
    }

    private func isWaterQuery(_ query: String) -> Bool {
        let keywords = ["water", "wa", "drink", "hydrat", "hydration", "ml", "oz", "fluid", "bottle", "glass", "cup"]
        return keywords.contains(where: { $0.contains(query) || query.contains($0) })
    }

    private func isStepsQuery(_ query: String) -> Bool {
        let keywords = ["step", "steps", "walk", "activity", "move", "walking"]
        return keywords.contains(where: { $0.contains(query) || query.contains($0) })
    }

    private func matchingFoodEntries(for log: DailyLog) -> [FoodEntry] {
        let sorted = log.foodEntries.sorted(by: { $0.timestamp > $1.timestamp })
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return sorted }

        // If the query matches the whole day's date, show all food items for that day
        if matchesDate(log.date, query: query) {
            return sorted
        }

        // If searching specifically for water or steps, do not match food
        if isWaterQuery(query) && !entryMatchesQueryDirectly(names: sorted.map(\.name), query: query) {
            return []
        }
        if isStepsQuery(query) && !entryMatchesQueryDirectly(names: sorted.map(\.name), query: query) {
            return []
        }

        // Match against food name, meal type, calories, or protein
        return sorted.filter { entry in
            entry.name.localizedCaseInsensitiveContains(query) ||
            entry.mealType.localizedCaseInsensitiveContains(query) ||
            (isFoodQuery(query) && true) ||
            "\(entry.effectiveCalories)".contains(query) ||
            "\(Int(entry.proteinG))".contains(query)
        }
    }

    private func entryMatchesQueryDirectly(names: [String], query: String) -> Bool {
        names.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    private func matchingWaterEntries(for log: DailyLog) -> [WaterEntry] {
        let sorted = log.waterEntries.sorted(by: { $0.timestamp > $1.timestamp })
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return sorted }

        // If query matches the whole day's date, show all water items for that day
        if matchesDate(log.date, query: query) {
            return sorted
        }

        // If searching specifically for food or steps, do not match water
        if isFoodQuery(query) && !isWaterQuery(query) {
            return []
        }
        if isStepsQuery(query) && !isWaterQuery(query) {
            return []
        }

        // If query is a water keyword, show all water entries
        if isWaterQuery(query) {
            return sorted
        }

        // Match against title or amount
        return sorted.filter { entry in
            entry.resolvedTitle.localizedCaseInsensitiveContains(query) ||
            "\(entry.amount)".contains(query)
        }
    }

    private func shouldShowSteps(for log: DailyLog) -> Bool {
        guard log.steps > 0 else { return false }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return true }

        if matchesDate(log.date, query: query) {
            return true
        }

        if isFoodQuery(query) || isWaterQuery(query) {
            return false
        }

        return isStepsQuery(query) || "\(log.steps)".contains(query)
    }

    private func resolvedFoodTitle(_ entry: FoodEntry) -> String {
        let trimmed = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if !entry.mealType.isEmpty { return entry.mealType.capitalized }
        return "Calories Logged"
    }

    // MARK: - Mutation Helpers

    private func deleteFoodEntry(_ entry: FoodEntry, from log: DailyLog) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.snappy) {
            log.foodEntries.removeAll { $0.id == entry.id }
            modelContext.delete(entry)
            try? modelContext.save()
        }
    }

    private func deleteWaterEntry(_ entry: WaterEntry, from log: DailyLog) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
