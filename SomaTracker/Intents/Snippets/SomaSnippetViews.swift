//
//  SomaSnippetViews.swift
//  SomaTracker
//
//  The cards Siri shows alongside its answer. They are rendered outside the app's normal screen
//  flow, so they take plain values and read nothing from the environment, SwiftData, or storage.
//

import SwiftUI

/// Today's four meters, the same ones the home screen leads with, in one compact card.
struct SomaDaySnippetView: View {
    let calories: Int
    let calorieGoal: Int
    let protein: Double
    let proteinGoal: Double
    let water: Int
    let waterGoal: Int
    let waterUnit: String
    let steps: Int
    let stepGoal: Int

    private var remaining: Int { max(0, calorieGoal - calories) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today in Soma")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SomaColors.subtext)

            HStack(alignment: .top, spacing: 22) {
                meter(
                    icon: "flame.fill",
                    color: SomaColors.coral,
                    value: calories.formatted(),
                    unit: "kcal",
                    detail: remaining > 0 ? "\(remaining.formatted()) left" : "goal reached"
                )
                meter(
                    icon: "bolt.fill",
                    color: SomaColors.iris,
                    value: Int(protein.rounded()).formatted(),
                    unit: "g",
                    detail: "of \(Int(proteinGoal.rounded())) g protein"
                )
            }

            HStack(alignment: .top, spacing: 22) {
                meter(
                    icon: "drop.fill",
                    color: SomaColors.aqua,
                    value: water.formatted(),
                    unit: waterUnit,
                    detail: "of \(waterGoal.formatted()) \(waterUnit)"
                )
                meter(
                    icon: "figure.walk",
                    color: SomaColors.emerald,
                    value: steps.formatted(),
                    unit: "",
                    detail: "of \(stepGoal.formatted()) steps"
                )
            }
        }
        .padding(16)
    }

    private func meter(icon: String, color: Color, value: String, unit: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(.label))

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SomaColors.subtext)
                }
            }

            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(SomaColors.subtext)
                .lineLimit(1)
        }
        .frame(minWidth: 88, alignment: .leading)
    }
}

/// The streak card: one number, and whether today already counts.
struct SomaStreakSnippetView: View {
    let current: Int
    let best: Int
    let loggedToday: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(SomaColors.streakOrange.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "flame.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SomaColors.streakOrange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(current == 0 ? "No streak yet" : "\(current) day streak")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(.label))

                Text(loggedToday
                     ? "Today is logged. Best: \(best) days."
                     : "Nothing logged today yet. Best: \(best) days.")
                    .font(.system(size: 12))
                    .foregroundStyle(SomaColors.subtext)
            }
        }
        .padding(16)
    }
}
