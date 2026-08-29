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
        case .protein: "fish.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .calories: .orange
        case .water: .blue
        case .protein: .purple
        }
    }
}

struct LogSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedCategory: LogCategory = .calories
    @State private var displayValue = "0"
    @State private var descriptionText = ""

    private var numericValue: Int {
        Int(displayValue) ?? 0
    }

    private var canSave: Bool {
        numericValue > 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Display area
                displaySection
                    .padding(.top, 24)

                // Description field
                TextField("Description (optional)", text: $descriptionText)
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 40)
                    .padding(.top, 6)

                Spacer(minLength: 16)

                // Category chips
                categoryChips
                    .padding(.bottom, 14)

                // Number pad
                numberPad
                    .padding(.horizontal, 20)

                // Save button
                Button {
                    save()
                } label: {
                    Text("Save")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(SomaColors.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(canSave ? SomaColors.navy : SomaColors.navy.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!canSave)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }
            .navigationTitle("Log Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Category Chips

    private var categoryChips: some View {
        HStack(spacing: 10) {
            ForEach(LogCategory.allCases) { cat in
                let isSelected = selectedCategory == cat

                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        selectedCategory = cat
                        displayValue = "0"
                        descriptionText = ""
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 14, weight: .semibold))

                        Text(cat.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(isSelected ? .white : Color(.label))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(isSelected ? cat.accentColor : Color(.tertiarySystemFill))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Display

    private var displaySection: some View {
        VStack(spacing: 4) {
            Image(systemName: selectedCategory.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(selectedCategory.accentColor)
                .padding(.bottom, 8)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(displayValue)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(.label))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text(selectedCategory.unit)
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .contentTransition(.numericText())
            .animation(.snappy(duration: 0.15), value: displayValue)
        }
    }

    // MARK: - Number Pad

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
                mealType: ""
            )
            log.foodEntries.append(entry)

        case .water:
            let entry = WaterEntry(amount: numericValue)
            log.waterEntries.append(entry)

        case .protein:
            let entry = FoodEntry(
                name: label.isEmpty ? "Protein" : label,
                calories: 0,
                proteinG: Double(numericValue),
                mealType: ""
            )
            log.foodEntries.append(entry)
        }

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    LogSheetView()
        .modelContainer(PreviewData.container)
}
