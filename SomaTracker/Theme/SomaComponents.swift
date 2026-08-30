import SwiftUI

struct SomaPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SomaTypography.body.weight(.semibold))
                .foregroundStyle(SomaColors.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(SomaColors.navy)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SomaStatCard: View {
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(SomaTypography.statValue)
                    .foregroundStyle(SomaColors.navy)

                Text(unit)
                    .font(SomaTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Text(label)
                .font(SomaTypography.statLabel)
                .foregroundStyle(SomaTypography.statLabelColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(SomaColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

enum SomaSegmentedToggleOption: String, CaseIterable, Identifiable {
    case remaining = "Remaining"
    case consumed = "Consumed"

    var id: Self { self }
}

struct SomaSegmentedToggle: View {
    @Binding var selection: SomaSegmentedToggleOption

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(SomaSegmentedToggleOption.allCases) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 4)
        .onChange(of: selection) { _, _ in
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}

struct LiquidGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .opacity(configuration.isPressed ? 0.82 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview("Soma Components") {
    @Previewable @State var selection: SomaSegmentedToggleOption = .remaining

    VStack(spacing: 20) {
        SomaPrimaryButton(title: "Continue") {}

        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
            SomaStatCard(value: "820", unit: "ml", label: "Water")
            SomaStatCard(value: "42", unit: "g", label: "Protein")
        }

        SomaSegmentedToggle(selection: $selection)
    }
    .padding()
    .background(SomaColors.statsBackground)
}
