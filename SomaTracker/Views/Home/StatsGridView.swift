import SwiftUI

struct StatsGridView: View {
    let calorieValue: Int
    let calorieLabel: String
    let proteinG: Double
    let waterValue: Int
    let waterUnit: String
    let steps: Int
    var scale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                StatGridCell(value: calorieValue.formatted(), unit: "Kcal", label: calorieLabel, scale: scale)
                verticalDivider
                StatGridCell(value: Int(proteinG.rounded()).formatted(), unit: "g", label: "Protein", scale: scale)
            }

            horizontalDivider

            HStack(spacing: 0) {
                StatGridCell(value: waterValue.formatted(), unit: waterUnit, label: "Water", scale: scale)
                verticalDivider
                StatGridCell(value: steps.formatted(), unit: "", label: "Steps", scale: scale)
            }
        }
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Color(.separator).opacity(0.65))
            .frame(width: 1)
            .padding(.vertical, 8)
    }

    private var horizontalDivider: some View {
        Rectangle()
            .fill(Color(.separator).opacity(0.65))
            .frame(height: 1)
    }
}

private struct StatGridCell: View {
    let value: String
    let unit: String
    let label: String
    var scale: CGFloat = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 4 * scale) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 30 * scale, weight: .bold, design: .default))
                    .foregroundStyle(Color(.label))
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.35, extraBounce: 0.05), value: value)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 14 * scale, weight: .bold, design: .default))
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }

            Text(label)
                .font(SomaTypography.body)
                .foregroundStyle(Color(.secondaryLabel))
                .animation(.snappy(duration: 0.3), value: label)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10 * scale)
        .padding(.horizontal, 8)
    }
}

#Preview {
    StatsGridView(
        calorieValue: 580,
        calorieLabel: "Remaining",
        proteinG: 100,
        waterValue: 1530,
        waterUnit: "ml",
        steps: 5230
    )
    .padding()
}
