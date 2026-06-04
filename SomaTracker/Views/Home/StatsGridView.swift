import SwiftUI

struct StatsGridView: View {
    let calorieValue: Int
    let calorieLabel: String
    let proteinG: Double
    let waterValue: Int
    let waterUnit: String
    let steps: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                StatGridCell(value: calorieValue.formatted(), unit: "Kcal", label: calorieLabel)
                verticalDivider
                StatGridCell(value: Int(proteinG.rounded()).formatted(), unit: "g", label: "Protein")
            }

            horizontalDivider

            HStack(spacing: 0) {
                StatGridCell(value: waterValue.formatted(), unit: waterUnit, label: "Water")
                verticalDivider
                StatGridCell(value: steps.formatted(), unit: "", label: "Steps")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .default))
                    .foregroundStyle(Color(.label))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 14, weight: .bold, design: .default))
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }

            Text(label)
                .font(SomaTypography.body)
                .foregroundStyle(Color(.secondaryLabel))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
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
