import SwiftUI

struct WeeklyBarChart: View {
    let logs: [DailyLog]

    @State private var isAnimated = false

    private let maxValue = 4_000
    private let calendar = Calendar.current

    // Total: 248 (unchanged footprint)
    // Bars:   190pt
    // Labels:  18pt
    // Buffer:  40pt (hidden behind white panel overlap)
    private let totalHeight: CGFloat = 248
    private let barHeight: CGFloat = 170
    private let labelHeight: CGFloat = 18
    private let bottomBuffer: CGFloat = 52

    // Empty-day "slot" placeholder: a short, faint capsule signalling a day exists.
    private let placeholderHeight: CGFloat = 7

    var body: some View {
        VStack(spacing: 0) {
            // Bars row
            HStack(alignment: .bottom, spacing: 12) {
                yAxisLabels

                HStack(alignment: .bottom, spacing: 18) {
                    ForEach(chartDays) { day in
                        GeometryReader { proxy in
                            let barH = proxy.size.height * day.normalizedValue

                            VStack {
                                Spacer()
                                Capsule()
                                    .fill(barFill(for: day))
                                    .frame(height: barFrameHeight(for: day, fullHeight: barH))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: barHeight)
            .padding(.bottom, 8)

            // Day labels row
            HStack(spacing: 12) {
                Color.clear.frame(width: 26)

                HStack(spacing: 18) {
                    ForEach(chartDays) { day in
                        Text(day.label)
                            .font(.system(size: 11, weight: .bold, design: .default))
                            .foregroundStyle(SomaColors.white.opacity(0.78))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: labelHeight)

            // Buffer — eaten by white panel overlap
            Spacer()
                .frame(height: bottomBuffer)
        }
        .frame(height: totalHeight)
        .clipped()
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
                isAnimated = true
            }
        }
    }

    private func barFill(for day: ChartDay) -> Color {
        guard day.hasData else {
            return SomaColors.white.opacity(0.12)  // empty-day slot
        }
        return day.isToday ? SomaColors.white : SomaColors.white.opacity(0.48)
    }

    private func barFrameHeight(for day: ChartDay, fullHeight: CGFloat) -> CGFloat {
        guard day.hasData else {
            return placeholderHeight  // fixed short slot, always visible
        }
        return isAnimated ? fullHeight : 0
    }

    private var yAxisLabels: some View {
        VStack(alignment: .leading) {
            ForEach((0...4).reversed(), id: \.self) { value in
                Text("\(value)k")
                    .font(.system(size: 12, weight: .bold, design: .default))
                    .foregroundStyle(SomaColors.white.opacity(0.65))

                if value != 0 {
                    Spacer()
                }
            }
        }
        .frame(width: 26)
    }

    private var chartDays: [ChartDay] {
        let today = calendar.startOfDay(for: .now)
        let logValues = logs.reduce(into: [Date: Int]()) { result, log in
            result[calendar.startOfDay(for: log.date), default: 0] += log.totalCalories
        }

        // Oldest on left, today on right
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - 6, to: today) else {
                return nil
            }

            let value = logValues[date] ?? 0
            return ChartDay(
                date: date,
                value: value,
                maxValue: maxValue,
                isToday: calendar.isDate(date, inSameDayAs: today)
            )
        }
    }
}

private struct ChartDay: Identifiable {
    let date: Date
    let value: Int
    let maxValue: Int
    let isToday: Bool

    var id: Date { date }

    var hasData: Bool { value > 0 }

    var normalizedValue: Double {
        min(Double(value) / Double(maxValue), 1)
    }

    var label: String {
        date.formatted(.dateTime.weekday(.abbreviated))
    }
}

#Preview {
    WeeklyBarChart(logs: [])
        .padding()
        .background(SomaColors.navy)
}
