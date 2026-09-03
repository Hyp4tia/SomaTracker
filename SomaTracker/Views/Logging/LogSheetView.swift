import SwiftUI
import SwiftData

enum LogCategory: String, CaseIterable, Identifiable {
    case calories = "Calories"
    case water = "Water"
    case protein = "Protein"

    var id: Self { self }

    var unit: String {
        switch self {
        case .calories: "kcal"
        case .water: "ml"
        case .protein: "g"
        }
    }

    var icon: String {
        switch self {
        case .calories: "flame.fill"
        case .water: "drop.fill"
        case .protein: "figure.strengthtraining.traditional"
        }
    }

    var accentColor: Color {
        switch self {
        case .calories: Color.orange
        case .water: Color.blue
        case .protein: Color.purple
        }
    }
}

struct LogSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedCategory: LogCategory = .calories
    @State private var displayValue = "0"
    @State private var descriptionText = ""
    @FocusState private var isDescriptionFocused: Bool

    private var numericValue: Int {
        Int(displayValue) ?? 0
    }

    private var canSave: Bool {
        numericValue > 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Hero Display Section (Kept persistent to avoid responder loop)
                displaySection
                    .padding(.top, isDescriptionFocused ? 8 : 14)

                // Category Chips (Kept persistent)
                categoryChips
                    .padding(.top, isDescriptionFocused ? 14 : 16)
                    .padding(.bottom, isDescriptionFocused ? 8 : 12)

                if !isDescriptionFocused {
                    Spacer(minLength: 8)

                    // Custom Keypad
                    numberPad
                        .padding(.horizontal, 20)

                    // Primary Save Button
                    Button {
                        save()
                    } label: {
                        Text("Save")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(canSave ? Color.white : Color(.tertiaryLabel))
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(canSave ? selectedCategory.accentColor : Color(.tertiarySystemFill))
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
            .navigationTitle(isDescriptionFocused ? "" : "Log Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
        }
        .presentationDetents([.fraction(0.78)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemBackground))
    }

    // MARK: - Category Chips

    private var categoryChips: some View {
        HStack(spacing: 10) {
            ForEach(LogCategory.allCases) { cat in
                let isSelected = selectedCategory == cat

                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.snappy(duration: 0.2)) {
                        selectedCategory = cat
                        displayValue = "0"
                        descriptionText = ""
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 13, weight: .semibold))

                        Text(cat.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(isSelected ? Color.white : Color(.label).opacity(0.85))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(isSelected ? cat.accentColor : Color(.secondarySystemFill))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Hero Display

    private var displaySection: some View {
        VStack(spacing: 4) {
            // Numeric Hero Value & Trailing Unit Lockup
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(displayValue)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(.label))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text(selectedCategory.unit)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color(.secondaryLabel))
            }
            .contentTransition(.numericText())
            .animation(.snappy(duration: 0.15), value: displayValue)

            // Transparent Centered Description Field
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

    // MARK: - Keypad Grid (4x3 Structure)

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

    // MARK: - Input Logic

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

    // MARK: - Save

    private func save() {
        let log = DailyLog.fetchOrCreateToday(context: modelContext)
        let label = descriptionText.trimmingCharacters(in: .whitespaces)

        switch selectedCategory {
        case .calories:
            let entry = FoodEntry(
                name: label.isEmpty ? "Food" : label,
                calories: numericValue,
                proteinG: 0,
                carbsG: 0,
                fatG: 0,
                mealType: ""
            )
            log.foodEntries.append(entry)

        case .water:
            let entry = WaterEntry(
                amount: numericValue,
                timestamp: .now,
                label: label.isEmpty ? nil : label
            )
            log.waterEntries.append(entry)

        case .protein:
            let proteinValue = Double(numericValue)
            let calculatedKcal = Int(round(proteinValue * 4.0))
            let entry = FoodEntry(
                name: label.isEmpty ? "Protein" : label,
                calories: calculatedKcal,
                proteinG: proteinValue,
                carbsG: 0,
                fatG: 0,
                mealType: ""
            )
            log.foodEntries.append(entry)
        }

        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

#Preview {
    LogSheetView()
        .modelContainer(PreviewData.container)
}
