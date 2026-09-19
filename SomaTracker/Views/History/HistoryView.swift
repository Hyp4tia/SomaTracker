import SwiftUI
import SwiftData

enum HistoryCategoryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case food = "Food"
    case protein = "Protein"
    case water = "Water"
    case steps = "Steps"

    var id: Self { self }
}

struct HistoryView: View {
    var isModal: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]
    @Query private var profiles: [UserProfile]
    @AppStorage(Units.storageKey) private var unitSystemRaw = UnitSystem.metric.rawValue

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var selectedCategoryFilter: HistoryCategoryFilter = .all
    @State private var showExportSheet = false
    @State private var showCalendarPicker = false
    @State private var editingItem: HistoryEditItem? = nil

    private var unitSystem: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }
    private var calendar: Calendar { Calendar.current }

    private var profile: UserProfile? {
        profiles.first
    }

    private var calorieGoal: Int {
        profile?.dailyCalorieGoal ?? 2_000
    }

    private var proteinGoal: Int {
        profile?.dailyProteinGoalG ?? 120
    }

    private var waterGoal: Int {
        profile?.dailyWaterGoalML ?? 2_000
    }

    private var isViewingToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    private var currentLogs: [DailyLog] {
        logs.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var dayCalories: Int {
        currentLogs.reduce(0) { $0 + $1.totalCalories }
    }

    private var dayProtein: Int {
        Int(currentLogs.reduce(0.0) { $0 + $1.totalProtein }.rounded())
    }

    private var dayWater: Int {
        currentLogs.reduce(0) { $0 + $1.totalWater }
    }

    private var daySteps: Int {
        currentLogs.map(\.steps).max() ?? 0
    }

    var body: some View {
        List {
            Group {
                // 1. Date Navigator (< Date >)
                dateNavigatorHeader
                    .padding(.top, 12)

                // 2. Three Hero Stat Cards (CALORIES, PROTEIN, WATER)
                heroCardsRow

                // 3. Category Filter Pills (All, Food, Protein, Water, Steps)
                categoryFilterPills
                    .padding(.top, 4)
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            // 4. Grouped Content Sections (FOOD, PROTEIN, WATER, STEPS)
            if hasAnyEntries {
                entriesGroupedView
            } else {
                emptyDayView
                    .listRowInsets(EdgeInsets(top: 24, leading: 20, bottom: 24, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            Color.clear
                .frame(height: 36)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isModal {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(SomaColors.navy)
                    }
                    .accessibilityLabel("Close")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showExportSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(SomaColors.navy)
                }
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
        .sheet(isPresented: $showCalendarPicker) {
            calendarPickerSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(.systemGroupedBackground))
        }
        .sheet(item: $editingItem) { item in
            EditHistoryEntrySheet(item: item)
                .preferredColorScheme(.light)
        }
        .hideTabBarWithCoordinator(!isModal)
        .task {
            DailyLog.deduplicateAllLogs(context: modelContext)
        }
    }

    // MARK: - 1. Date Navigator Header

    private var dateNavigatorHeader: some View {
        HStack {
            // Previous Day Button (<)
            Button {
                stepDay(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(.label))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            // Date Label (Tappable to pick any date)
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showCalendarPicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(dateHeadingString)
                        .font(.system(size: 26, weight: .heavy, design: .default))
                        .foregroundStyle(Color(.label))

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Next Day Button (>) - disabled if already viewing today
            Button {
                stepDay(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isViewingToday ? Color(.quaternaryLabel) : Color(.label))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isViewingToday)
        }
    }

    private var dateHeadingString: String {
        if isViewingToday {
            return "Today, \(selectedDate.formatted(.dateTime.month(.abbreviated).day()))"
        }
        if calendar.isDateInYesterday(selectedDate) {
            return "Yesterday, \(selectedDate.formatted(.dateTime.month(.abbreviated).day()))"
        }
        return "\(selectedDate.formatted(.dateTime.weekday(.wide))), \(selectedDate.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private func stepDay(by value: Int) {
        guard let next = calendar.date(byAdding: .day, value: value, to: selectedDate) else { return }
        if value > 0 && next > Date.now { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.snappy(duration: 0.22)) {
            selectedDate = calendar.startOfDay(for: next)
        }
    }

    // MARK: - 2. Hero Macro Cards Row

    private var heroCardsRow: some View {
        HStack(spacing: 12) {
            // Calories Card
            statCard(
                title: "CALORIES",
                value: dayCalories.formatted(),
                target: "/ \(calorieGoal.formatted())",
                targetColor: Color.orange
            )

            // Protein Card
            statCard(
                title: "PROTEIN",
                value: "\(dayProtein)g",
                target: "/ \(proteinGoal)g",
                targetColor: Color.orange
            )

            // Water Card
            let waterDisplay = Units.waterValue(ml: dayWater, system: unitSystem)
            let waterGoalDisplay = Units.waterValue(ml: waterGoal, system: unitSystem)
            let unitStr = Units.waterUnit(unitSystem)
            statCard(
                title: "WATER",
                value: "\(waterDisplay)",
                target: "/ \(waterGoalDisplay) \(unitStr)",
                targetColor: Color.blue
            )
        }
    }

    private func statCard(
        title: String,
        value: String,
        target: String,
        targetColor: Color
    ) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(Color(.secondaryLabel))

            Text(value)
                .font(.system(size: 21, weight: .bold, design: .default))
                .monospacedDigit()
                .foregroundStyle(Color(.label))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.22), value: value)

            Text(target)
                .font(.system(size: 12, weight: .semibold, design: .default))
                .foregroundStyle(targetColor)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .background(Color(.systemGray6).opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - 3. Category Filter Selector (Liquid Glass Segmented Control)

    private var categoryFilterPills: some View {
        Picker("Category Filter", selection: $selectedCategoryFilter) {
            ForEach(HistoryCategoryFilter.allCases) { filter in
                Text(filter.rawValue)
                    .tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedCategoryFilter) { _, _ in
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    // MARK: - 4. Grouped Content Sections (Food, Protein, Water, Steps)

    private var hasAnyEntries: Bool {
        dayCalories > 0 || dayWater > 0 || daySteps > 0 || currentLogs.contains { !$0.foodEntries.isEmpty || !$0.waterEntries.isEmpty }
    }

    @ViewBuilder
    private var entriesGroupedView: some View {
        let allFoods = currentLogs.flatMap(\.foodEntries).sorted(by: { $0.timestamp < $1.timestamp })
        let foodEntries = allFoods.filter { !Self.isProteinEntry($0) }
        let proteinEntries = allFoods.filter { Self.isProteinEntry($0) }

        // The Protein filter is a lens on everything that contributed protein, not only the
        // protein-type logs the All view separates out. A meal that carried protein belongs in it:
        // the filter used to report "no protein logs" for a logged Big Mac while its 25g showed
        // under Food and counted towards the daily total.
        let proteinContributors = selectedCategoryFilter == .protein
            ? allFoods.filter { $0.proteinG > 0 }
            : proteinEntries
        let waterEntries = currentLogs.flatMap(\.waterEntries).sorted(by: { $0.timestamp < $1.timestamp })
        let stepsCount = daySteps

        // 1. Food Section
        if (selectedCategoryFilter == .all || selectedCategoryFilter == .food) && !foodEntries.isEmpty {
            Section {
                ForEach(foodEntries) { entry in
                    foodRow(entry)
                        .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 20))
                        .listRowSeparator(.visible, edges: .bottom)
                        .listRowBackground(Color(.systemBackground))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteFoodEntry(entry, from: entry.dailyLog)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                editingItem = .food(entry)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(SomaColors.navy)
                        }
                        .contextMenu {
                            Button {
                                editingItem = .food(entry)
                            } label: {
                                Label("Edit Entry", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                deleteFoodEntry(entry, from: entry.dailyLog)
                            } label: {
                                Label("Delete Entry", systemImage: "trash")
                            }
                        }
                }
            } header: {
                sectionHeader("Food")
            }
        } else if selectedCategoryFilter == .food && foodEntries.isEmpty {
            Section {
                emptyCategoryView("No food logs for this day")
                    .listRowInsets(EdgeInsets(top: 24, leading: 20, bottom: 24, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }

        // 2. Protein Section
        if (selectedCategoryFilter == .all || selectedCategoryFilter == .protein) && !proteinContributors.isEmpty {
            Section {
                ForEach(proteinContributors) { entry in
                    proteinRow(entry)
                        .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 20))
                        .listRowSeparator(.visible, edges: .bottom)
                        .listRowBackground(Color(.systemBackground))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteFoodEntry(entry, from: entry.dailyLog)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                editingItem = .food(entry)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(SomaColors.navy)
                        }
                        .contextMenu {
                            Button {
                                editingItem = .food(entry)
                            } label: {
                                Label("Edit Entry", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                deleteFoodEntry(entry, from: entry.dailyLog)
                            } label: {
                                Label("Delete Entry", systemImage: "trash")
                            }
                        }
                }
            } header: {
                // No total here: the PROTEIN card above already carries it, and repeating it was noise.
                sectionHeader("Protein")
            }
        } else if selectedCategoryFilter == .protein && proteinContributors.isEmpty {
            Section {
                emptyCategoryView("No protein logs for this day")
                    .listRowInsets(EdgeInsets(top: 24, leading: 20, bottom: 24, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }

        // 3. Water Section
        if (selectedCategoryFilter == .all || selectedCategoryFilter == .water) && !waterEntries.isEmpty {
            Section {
                ForEach(waterEntries) { entry in
                    waterRow(entry)
                        .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 20))
                        .listRowSeparator(.visible, edges: .bottom)
                        .listRowBackground(Color(.systemBackground))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteWaterEntry(entry, from: entry.dailyLog)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                editingItem = .water(entry)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(SomaColors.navy)
                        }
                        .contextMenu {
                            Button {
                                editingItem = .water(entry)
                            } label: {
                                Label("Edit Entry", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                deleteWaterEntry(entry, from: entry.dailyLog)
                            } label: {
                                Label("Delete Entry", systemImage: "trash")
                            }
                        }
                }
            } header: {
                sectionHeader("Water")
            }
        } else if selectedCategoryFilter == .water && waterEntries.isEmpty {
            Section {
                emptyCategoryView("No water logs for this day")
                    .listRowInsets(EdgeInsets(top: 24, leading: 20, bottom: 24, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }

        // 4. Steps Section
        if (selectedCategoryFilter == .all || selectedCategoryFilter == .steps) && stepsCount > 0 {
            Section {
                stepsRow(steps: stepsCount)
                    .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color(.systemBackground))
            } header: {
                sectionHeader("Steps")
            }
        } else if selectedCategoryFilter == .steps && stepsCount == 0 {
            Section {
                emptyCategoryView("No steps recorded for this day")
                    .listRowInsets(EdgeInsets(top: 24, leading: 20, bottom: 24, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 18, weight: .bold, design: .default))
            .foregroundStyle(Color(.label))
            .textCase(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 14)
            .padding(.bottom, 4)
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color(.systemBackground))
    }

    private func emptyCategoryView(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 14))
            .foregroundStyle(Color(.secondaryLabel))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }

    // MARK: - Rows

    private func foodRow(_ entry: FoodEntry) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(resolvedFoodTitle(entry))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color(.label))
                    .lineLimit(2)

                Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(entry.effectiveCalories.formatted()) kcal")
                    .font(.system(size: 15, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Color(.label))

                if entry.proteinG > 0 {
                    Text("\(Int(entry.proteinG.rounded()))g Protein")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color.orange)
                }
            }
        }
        .padding(.vertical, 10)
    }

    private func proteinRow(_ entry: FoodEntry) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(resolvedProteinTitle(entry))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color(.label))
                    .lineLimit(2)

                Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(Int(entry.proteinG.rounded()))g Protein")
                    .font(.system(size: 15, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Color.orange)

                Text("\(entry.effectiveCalories.formatted()) kcal")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
        .padding(.vertical, 10)
    }

    private func waterRow(_ entry: WaterEntry) -> some View {
        let displayAmount = Units.waterValue(ml: entry.amount, system: unitSystem)
        let unitString = Units.waterUnit(unitSystem)
        let hasCustomLabel = entry.label != nil && !entry.label!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(hasCustomLabel ? entry.label! : "\(displayAmount) \(unitString)")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color(.label))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if hasCustomLabel {
                        Text("\(displayAmount) \(unitString)")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color(.secondaryLabel))
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }

                    Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Text("\(displayAmount) \(unitString)")
                    .font(.system(size: 15, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Color.blue)

                Image(systemName: "drop.fill")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.blue)
            }
        }
        .padding(.vertical, 10)
    }

    private func stepsRow(steps: Int) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Daily Steps")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color(.label))

                Text("Activity synced")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(SomaColors.navy)

                Text(steps.formatted())
                    .font(.system(size: 15, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Color(.label))
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Empty Day View

    private var emptyDayView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(Color(.tertiaryLabel))
                .padding(.top, 24)

            Text("No Logs for This Day")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color(.label))

            Text(isViewingToday
                ? "Start tracking your calories, water, and macros for today."
                : "No food or hydration entries were logged on \(selectedDate.formatted(.dateTime.month(.wide).day())).")
                .font(.system(size: 14))
                .foregroundStyle(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color(.systemGray6).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - Calendar Picker Sheet

    private var calendarPickerSheet: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    in: ...Date.now,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()

                Spacer()
            }
            .navigationTitle("Go to Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showCalendarPicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Category & Title Helpers

    static func isProteinEntry(_ entry: FoodEntry) -> Bool {
        let lower = entry.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower == "protein" || lower.contains("protein") || lower.contains("whey") || lower.contains("shake") || lower.contains("isolate") {
            return true
        }
        if entry.mealType.localizedCaseInsensitiveContains("protein") {
            return true
        }
        if entry.proteinG > 0 && entry.effectiveCalories <= Int(round(entry.proteinG * 4.5)) {
            return true
        }
        return false
    }

    private func resolvedFoodTitle(_ entry: FoodEntry) -> String {
        let name = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name.lowercased() == "food" {
            return "Quick Meal"
        }
        return name
    }

    private func resolvedProteinTitle(_ entry: FoodEntry) -> String {
        let name = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name.lowercased() == "protein" {
            return "Protein Intake"
        }
        return name
    }

    // MARK: - Deletion Mutations

    private func deleteFoodEntry(_ entry: FoodEntry, from log: DailyLog?) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let dayLog = entry.dailyLog ?? log
        withAnimation(.snappy) {
            entry.deleteWithSyncedAIEntry(from: log, in: modelContext)
        }
        // Health keeps its own copy, so a removal has to be mirrored too.
        Task { await HealthSyncService.shared.syncDay(dayLog) }
    }

    private func deleteWaterEntry(_ entry: WaterEntry, from log: DailyLog?) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let dayLog = entry.dailyLog ?? log
        withAnimation(.snappy) {
            entry.deleteWithSyncedAIEntry(from: log, in: modelContext)
        }
        // Health keeps its own copy, so a removal has to be mirrored too.
        Task { await HealthSyncService.shared.syncDay(dayLog) }
    }
}

// MARK: - History Edit Item

enum HistoryEditItem: Identifiable {
    case food(FoodEntry)
    case water(WaterEntry)

    var id: String {
        switch self {
        case .food(let entry):
            return "food_\(entry.id)"
        case .water(let entry):
            return "water_\(entry.id)"
        }
    }
}

// MARK: - Edit History Entry Sheet

struct EditHistoryEntrySheet: View {
    let item: HistoryEditItem

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(Units.storageKey) private var unitSystemRaw = UnitSystem.metric.rawValue

    @State private var displayValue = "0"
    @State private var descriptionText = ""
    @State private var saveErrorMessage: String?
    @FocusState private var isDescriptionFocused: Bool

    private var unitSystem: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    private var isProtein: Bool {
        if case .food(let entry) = item {
            return HistoryView.isProteinEntry(entry)
        }
        return false
    }

    private var categoryTitle: String {
        switch item {
        case .food:
            return isProtein ? "Edit Protein" : "Edit Food"
        case .water:
            return "Edit Water"
        }
    }

    private var unit: String {
        switch item {
        case .food:
            return isProtein ? "g" : "kcal"
        case .water:
            return Units.waterUnit(unitSystem)
        }
    }

    private var accentColor: Color {
        switch item {
        case .food:
            return isProtein ? Color.purple : Color.orange
        case .water:
            return Color.blue
        }
    }

    private var numericValue: Int {
        Int(displayValue) ?? 0
    }

    private var canSave: Bool {
        numericValue > 0
    }

    /// The day this entry belongs to, so an edit can be mirrored into Health after saving.
    private var entryDayLog: DailyLog? {
        switch item {
        case .food(let entry): return entry.dailyLog
        case .water(let entry): return entry.dailyLog
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Hero Display Section
                displaySection
                    .padding(.top, isDescriptionFocused ? 8 : 16)

                if !isDescriptionFocused {
                    Spacer(minLength: 8)

                    // Custom Keypad
                    numberPad
                        .padding(.horizontal, 20)

                    // Save Button
                    Button {
                        save()
                    } label: {
                        Text("Save Changes")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(canSave ? Color.white : Color(.tertiaryLabel))
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(canSave ? accentColor : Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(!canSave)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 8)
                } else {
                    Spacer()
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .animation(.snappy(duration: 0.25), value: isDescriptionFocused)
            .navigationTitle(isDescriptionFocused ? "" : categoryTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(SomaColors.navy)
                    }
                    .accessibilityLabel("Close")
                }
            }
            .onAppear {
                loadInitialData()
            }
        }
        .presentationDetents([.fraction(0.78)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemBackground))
        .alert("Couldn't Save Change", isPresented: .init(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "")
        }
    }

    private func loadInitialData() {
        switch item {
        case .food(let entry):
            if HistoryView.isProteinEntry(entry) {
                displayValue = "\(Int(entry.proteinG.rounded()))"
                descriptionText = entry.name
            } else {
                displayValue = "\(entry.calories)"
                descriptionText = entry.name
            }
        case .water(let entry):
            let val = Units.waterValue(ml: entry.amount, system: unitSystem)
            displayValue = "\(val)"
            descriptionText = entry.label ?? ""
        }
    }

    private var displaySection: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(displayValue)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(.label))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text(unit)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color(.secondaryLabel))
            }
            .contentTransition(.numericText())
            .animation(.snappy(duration: 0.15), value: displayValue)

            TextField(
                "",
                text: $descriptionText,
                prompt: Text("Description (optional)").foregroundStyle(Color(.tertiaryLabel))
            )
            .font(.subheadline)
            .foregroundStyle(Color(.label))
            .multilineTextAlignment(.center)
            .tint(.primary)
            .submitLabel(.done)
            .onSubmit {
                isDescriptionFocused = false
            }
            .focused($isDescriptionFocused)
            .padding(.top, 6)
            .padding(.horizontal, 32)
        }
    }

    private var numberPad: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(1...9, id: \.self) { digit in
                numberButton("\(digit)")
            }
            numberButton("00")
            numberButton("0")
            deleteButton
        }
    }

    private func numberButton(_ label: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            appendDigit(label)
        } label: {
            Text(label)
                .font(.title2.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(Color(.label))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var deleteButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            deleteLastDigit()
        } label: {
            Image(systemName: "delete.left.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color(.secondaryLabel))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.snappy) {
                        displayValue = "0"
                    }
                }
        )
    }

    private func appendDigit(_ digit: String) {
        if displayValue == "0" {
            if digit == "0" || digit == "00" { return }
            displayValue = digit
        } else {
            guard displayValue.count < 6 else { return }
            displayValue += digit
        }
    }

    private func deleteLastDigit() {
        displayValue = String(displayValue.dropLast())
        if displayValue.isEmpty { displayValue = "0" }
    }

    private func save() {
        guard canSave else { return }
        let label = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch item {
        case .food(let entry):
            let updatedName = label.isEmpty ? entry.name : label
            if isProtein {
                let proteinVal = Double(numericValue)
                entry.proteinG = proteinVal
                entry.calories = Int(round(proteinVal * 4.0))
                entry.name = updatedName

                syncLinkedAIMeal(for: entry, name: updatedName, calories: entry.calories, proteinG: proteinVal, carbsG: entry.carbsG, fatG: entry.fatG)
            } else {
                let newCalories = numericValue
                let oldCalories = max(entry.calories, 1)

                // Scale macros proportionally so effectiveCalories matches the edited calories
                if entry.proteinG > 0 || entry.carbsG > 0 || entry.fatG > 0 {
                    let ratio = Double(newCalories) / Double(oldCalories)
                    entry.proteinG = max(0, round(entry.proteinG * ratio * 10) / 10)
                    entry.carbsG = max(0, round(entry.carbsG * ratio * 10) / 10)
                    entry.fatG = max(0, round(entry.fatG * ratio * 10) / 10)
                }

                entry.calories = newCalories
                entry.name = updatedName

                syncLinkedAIMeal(for: entry, name: updatedName, calories: newCalories, proteinG: entry.proteinG, carbsG: entry.carbsG, fatG: entry.fatG)
            }
        case .water(let entry):
            let ml = Units.waterToML(numericValue, system: unitSystem)
            entry.amount = ml
            if !label.isEmpty {
                entry.label = label
            }

            if let aiId = entry.aiMealEntryId {
                let descriptor = FetchDescriptor<AIMealEntry>()
                if let aiEntries = try? modelContext.fetch(descriptor),
                   let match = aiEntries.first(where: { $0.id == aiId }) {
                    match.title = "Hydration (\(ml) ml)"
                    match.storyText = label.isEmpty ? "Logged \(ml) ml water." : label
                    if match.dailyLog == nil, let log = entry.dailyLog {
                        match.dailyLog = log
                    }
                }
            }
        }

        do {
            try modelContext.save()
        } catch {
            // Keep the sheet open with the edited values still in the fields so saving can be
            // retried: the previous `try?` dismissed as if the change had landed.
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            saveErrorMessage = "Your change couldn't be saved. Please try again."
            return
        }

        // Health holds its own copy of the entry, so the edit is mirrored once it is saved.
        Task { await HealthSyncService.shared.syncDay(entryDayLog) }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private func syncLinkedAIMeal(
        for entry: FoodEntry,
        name: String,
        calories: Int,
        proteinG: Double,
        carbsG: Double,
        fatG: Double
    ) {
        let descriptor = FetchDescriptor<AIMealEntry>()
        guard let aiEntries = try? modelContext.fetch(descriptor) else { return }

        for aiMeal in aiEntries {
            let isIdMatch = (entry.aiMealEntryId != nil && aiMeal.id == entry.aiMealEntryId)
            let isHeuristicMatch = entry.aiMealEntryId == nil &&
                abs(aiMeal.timestamp.timeIntervalSince(entry.timestamp)) < 120 &&
                (aiMeal.title == entry.name || entry.name.contains(aiMeal.title))

            if isIdMatch || isHeuristicMatch {
                aiMeal.title = name
                aiMeal.calories = calories
                aiMeal.proteinG = proteinG
                aiMeal.carbsG = carbsG
                aiMeal.fatG = fatG
                aiMeal.breakdownNotes = "Updated: \(name) (\(calories) kcal, \(Int(proteinG))g protein, \(Int(carbsG))g carbs, \(Int(fatG))g fat)."
                if aiMeal.dailyLog == nil, let log = entry.dailyLog {
                    aiMeal.dailyLog = log
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
            .modelContainer(PreviewData.container)
    }
}
