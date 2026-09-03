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

    private var currentLog: DailyLog? {
        logs.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var dayCalories: Int {
        currentLog?.totalCalories ?? 0
    }

    private var dayProtein: Int {
        Int((currentLog?.totalProtein ?? 0).rounded())
    }

    private var dayWater: Int {
        currentLog?.totalWater ?? 0
    }

    private var daySteps: Int {
        currentLog?.steps ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 1. Date Navigator (< Date >)
                dateNavigatorHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                // 2. Three Hero Stat Cards (CALORIES, PROTEIN, WATER)
                heroCardsRow
                    .padding(.horizontal, 20)

                // 3. Category Filter Pills (All, Food, Protein, Water, Steps)
                categoryFilterPills
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                // 4. Grouped Content Sections (FOOD, PROTEIN, WATER, STEPS)
                if hasAnyEntries {
                    entriesGroupedView
                        .padding(.horizontal, 20)
                } else {
                    emptyDayView
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                }
            }
            .padding(.bottom, 36)
        }
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
                    .accessibilityLabel("Close")
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
        .sheet(isPresented: $showCalendarPicker) {
            calendarPickerSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(.systemGroupedBackground))
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
        guard let log = currentLog else { return false }
        return !log.foodEntries.isEmpty || !log.waterEntries.isEmpty || log.steps > 0
    }

    private var entriesGroupedView: some View {
        VStack(spacing: 24) {
            let log = currentLog!

            let allFoods = log.foodEntries.sorted(by: { $0.timestamp < $1.timestamp })
            let foodEntries = allFoods.filter { !isProteinEntry($0) }
            let proteinEntries = allFoods.filter { isProteinEntry($0) }
            let waterEntries = log.waterEntries.sorted(by: { $0.timestamp < $1.timestamp })
            let stepsCount = log.steps

            // 1. Food Section
            if (selectedCategoryFilter == .all || selectedCategoryFilter == .food) && !foodEntries.isEmpty {
                sectionGroup(title: "Food") {
                    VStack(spacing: 0) {
                        ForEach(Array(foodEntries.enumerated()), id: \.element.id) { index, entry in
                            foodRow(entry, in: log)

                            if index < foodEntries.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            } else if selectedCategoryFilter == .food && foodEntries.isEmpty {
                emptyCategoryView("No food logs for this day")
            }

            // 2. Protein Section
            if (selectedCategoryFilter == .all || selectedCategoryFilter == .protein) && !proteinEntries.isEmpty {
                sectionGroup(title: "Protein") {
                    VStack(spacing: 0) {
                        ForEach(Array(proteinEntries.enumerated()), id: \.element.id) { index, entry in
                            proteinRow(entry, in: log)

                            if index < proteinEntries.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            } else if selectedCategoryFilter == .protein && proteinEntries.isEmpty {
                emptyCategoryView("No protein logs for this day")
            }

            // 3. Water Section
            if (selectedCategoryFilter == .all || selectedCategoryFilter == .water) && !waterEntries.isEmpty {
                sectionGroup(title: "Water") {
                    VStack(spacing: 0) {
                        ForEach(Array(waterEntries.enumerated()), id: \.element.id) { index, entry in
                            waterRow(entry, in: log)

                            if index < waterEntries.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            } else if selectedCategoryFilter == .water && waterEntries.isEmpty {
                emptyCategoryView("No water logs for this day")
            }

            // 4. Steps Section
            if (selectedCategoryFilter == .all || selectedCategoryFilter == .steps) && stepsCount > 0 {
                sectionGroup(title: "Steps") {
                    stepsRow(for: log)
                }
            } else if selectedCategoryFilter == .steps && stepsCount == 0 {
                emptyCategoryView("No steps recorded for this day")
            }
        }
    }

    private func sectionGroup<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .default))
                .foregroundStyle(Color(.label))

            VStack(spacing: 0) {
                content()
            }
        }
    }

    private func emptyCategoryView(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 14))
            .foregroundStyle(Color(.secondaryLabel))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }

    // MARK: - Rows

    private func foodRow(_ entry: FoodEntry, in log: DailyLog) -> some View {
        SwipeToDeleteRow {
            deleteFoodEntry(entry, from: log)
        } content: {
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
    }

    private func proteinRow(_ entry: FoodEntry, in log: DailyLog) -> some View {
        SwipeToDeleteRow {
            deleteFoodEntry(entry, from: log)
        } content: {
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
    }

    private func waterRow(_ entry: WaterEntry, in log: DailyLog) -> some View {
        let displayAmount = Units.waterValue(ml: entry.amount, system: unitSystem)
        let unitString = Units.waterUnit(unitSystem)
        let hasCustomLabel = entry.label != nil && !entry.label!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return SwipeToDeleteRow {
            deleteWaterEntry(entry, from: log)
        } content: {
            HStack(alignment: .center, spacing: 12) {
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
    }

    private func stepsRow(for log: DailyLog) -> some View {
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

                Text(log.steps.formatted())
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

    private func isProteinEntry(_ entry: FoodEntry) -> Bool {
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
}

// MARK: - Swipe To Delete Container

private struct SwipeToDeleteRow<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var isSwiped = false

    var body: some View {
        ZStack(alignment: .trailing) {
            if offset < -10 {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 38)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }

            content()
                .background(Color(.systemBackground))
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onChanged { gesture in
                            if gesture.translation.width < 0 {
                                offset = max(gesture.translation.width, -60)
                            } else if isSwiped && gesture.translation.width > 0 {
                                offset = min(-60 + gesture.translation.width, 0)
                            }
                        }
                        .onEnded { gesture in
                            withAnimation(.snappy(duration: 0.22)) {
                                if gesture.translation.width < -30 {
                                    offset = -60
                                    isSwiped = true
                                } else {
                                    offset = 0
                                    isSwiped = false
                                }
                            }
                        }
                )
        }
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Entry", systemImage: "trash")
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
