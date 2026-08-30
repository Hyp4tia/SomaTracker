import SwiftUI
import SwiftData

struct WaterLogSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var logs: [DailyLog]

    @AppStorage(Units.storageKey) private var unitSystemRaw = UnitSystem.metric.rawValue
    private var unitSystem: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    @State private var pendingAmount = 0  // always stored in ml
    @State private var showCustomInput = false

    private let waterBlue = Color(red: 0.38, green: 0.82, blue: 1.0)

    private var waterUnit: String { Units.waterUnit(unitSystem) }
    private func display(_ ml: Int) -> Int { Units.waterValue(ml: ml, system: unitSystem) }

    private var profileWaterGoal: Int {
        // Read the goal off the same query the rest of the app uses.
        (try? modelContext.fetch(FetchDescriptor<UserProfile>()))?.first?.dailyWaterGoalML ?? 2_000
    }

    private var todayWater: Int {
        let today = Calendar.current.startOfDay(for: .now)
        return logs.first { Calendar.current.isDate($0.date, inSameDayAs: today) }?.totalWater ?? 0
    }

    private var yesterdayWater: Int {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: .now)) else {
            return 0
        }
        return logs.first { calendar.isDate($0.date, inSameDayAs: yesterday) }?.totalWater ?? 0
    }

    private var todayEntries: [WaterEntry] {
        let today = Calendar.current.startOfDay(for: .now)
        let log = logs.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
        return (log?.waterEntries ?? []).sorted { $0.timestamp > $1.timestamp }
    }

    private var projectedTotal: Int {
        todayWater + pendingAmount
    }

    private var progress: Double {
        guard profileWaterGoal > 0 else { return 0 }
        return min(Double(projectedTotal) / Double(profileWaterGoal), 1)
    }

    // Comparison of projected total vs yesterday.
    private var trend: (text: String, isUp: Bool, hasData: Bool) {
        guard yesterdayWater > 0 else { return ("No data for yesterday", true, false) }
        let diff = projectedTotal - yesterdayWater
        let pct = Int(((Double(diff) / Double(yesterdayWater)) * 100).rounded())
        let direction = diff >= 0 ? "more" : "less"
        return ("\(abs(pct))% \(direction) than yesterday", diff >= 0, true)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerBadge
                    .padding(.top, 12)

                // Big projected total
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(display(projectedTotal).formatted())
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.2), value: projectedTotal)

                    Text(waterUnit)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 18)

                Text("of \(display(profileWaterGoal).formatted()) \(waterUnit) goal today")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(.secondaryLabel))
                    .padding(.top, 2)

                // Progress bar
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.tertiarySystemFill))
                        Capsule()
                            .fill(waterBlue)
                            .frame(width: proxy.size.width * progress)
                            .animation(.snappy(duration: 0.25), value: progress)
                    }
                }
                .frame(height: 12)
                .padding(.horizontal, 28)
                .padding(.top, 20)

                // vs yesterday
                comparisonRow
                    .padding(.horizontal, 28)
                    .padding(.top, 16)

                // Today's log fills the remaining space
                todayLogSection
                    .padding(.top, 24)

                // Quick add chips
                quickAddGrid
                    .padding(.horizontal, 20)

                // Save button + custom amount
                HStack(spacing: 12) {
                    Button {
                        save()
                    } label: {
                        Text(pendingAmount > 0 ? "Add \(display(pendingAmount)) \(waterUnit)" : "Add Water")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(SomaColors.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(pendingAmount > 0 ? waterBlue : waterBlue.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(pendingAmount == 0)

                    Button {
                        showCustomInput = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(waterBlue)
                            .frame(width: 54, height: 54)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add custom amount")
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 8)
            }
            .navigationTitle("Water Intake")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemBackground))
        .sheet(isPresented: $showCustomInput) {
            // Dismiss this water sheet too, so the user returns to the home page.
            CustomWaterEntryView(onAdded: { dismiss() })
                .preferredColorScheme(.light)
        }
    }

    // MARK: - Header

    private var headerBadge: some View {
        Image(systemName: "waterbottle.fill")
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(SomaColors.white)
            .frame(width: 56, height: 56)
            .background(Color(red: 0.20, green: 0.62, blue: 0.92))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Comparison

    private var comparisonRow: some View {
        HStack(spacing: 8) {
            Image(systemName: !trend.hasData
                ? "minus"
                : (trend.isUp ? "arrow.up.right" : "arrow.down.right"))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(!trend.hasData ? Color(.secondaryLabel) : (trend.isUp ? .green : .orange))

            Text(trend.text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(.label))

            Spacer()

            Text("Yesterday: \(display(yesterdayWater).formatted()) \(waterUnit)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(.secondaryLabel))
        }
    }

    // MARK: - Today's Log

    private var todayLogSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TODAY'S LOG")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)

            if todayEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "drop")
                        .font(.system(size: 30, weight: .regular))
                        .foregroundStyle(.tertiary)
                    Text("No water logged yet today")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(todayEntries) { entry in
                            HStack(spacing: 12) {
                                Image(systemName: "waterbottle.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(waterBlue)
                                    .frame(width: 32, height: 32)
                                    .background(waterBlue.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                Text("\(display(entry.amount)) \(waterUnit)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color(.label))

                                Spacer()

                                Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Quick Add

    private var quickAddGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Units.waterQuickAmounts(unitSystem), id: \.self) { amount in
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        pendingAmount += Units.waterToML(amount, system: unitSystem)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                        Text("\(amount) \(waterUnit)")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(Color(.label))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .topTrailing) {
            if pendingAmount > 0 {
                Button {
                    withAnimation(.snappy(duration: 0.2)) { pendingAmount = 0 }
                } label: {
                    Text("Reset")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .offset(y: -26)
            }
        }
    }

    // MARK: - Save

    private func save() {
        guard pendingAmount > 0 else { return }
        let log = DailyLog.fetchOrCreateToday(context: modelContext)
        let entry = WaterEntry(amount: pendingAmount)
        log.waterEntries.append(entry)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Custom Water Entry (calculator)

struct CustomWaterEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(Units.storageKey) private var unitSystemRaw = UnitSystem.metric.rawValue

    /// Called after the entry is saved — used to also close the parent water sheet.
    var onAdded: () -> Void = {}

    @State private var displayValue = "0"

    private let waterBlue = Color(red: 0.38, green: 0.82, blue: 1.0)
    private var unitSystem: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }
    private var unit: String { Units.waterUnit(unitSystem) }
    private var numericValue: Int { Int(displayValue) ?? 0 }
    private var canSave: Bool { numericValue > 0 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerBadge
                    .padding(.top, 16)

                // Display
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(displayValue)
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text(unit)
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.15), value: displayValue)
                .padding(.top, 18)

                Spacer(minLength: 16)

                numberPad
                    .padding(.horizontal, 20)

                Button {
                    save()
                } label: {
                    Text("Add Water")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(SomaColors.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(canSave ? waterBlue : waterBlue.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!canSave)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }
            .navigationTitle("Custom Amount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var headerBadge: some View {
        Image(systemName: "waterbottle.fill")
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(SomaColors.white)
            .frame(width: 56, height: 56)
            .background(Color(red: 0.20, green: 0.62, blue: 0.92))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var numberPad: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

        return LazyVGrid(columns: columns, spacing: 12) {
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
            appendDigit(label)
        } label: {
            Text(label)
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundStyle(Color(.label))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var deleteButton: some View {
        Button {
            deleteLastDigit()
        } label: {
            Image(systemName: "delete.backward")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color(.label))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
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
        let log = DailyLog.fetchOrCreateToday(context: modelContext)
        let ml = Units.waterToML(numericValue, system: unitSystem)
        log.waterEntries.append(WaterEntry(amount: ml))
        try? modelContext.save()

        dismiss()      // close this calculator
        onAdded()      // close the parent water sheet → back to home
    }
}

#Preview {
    WaterLogSheetView()
        .modelContainer(PreviewData.container)
}
