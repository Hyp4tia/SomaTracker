import SwiftUI

struct WeeklyBarChart: View {
    let logs: [DailyLog]

    @State private var isAnimated = false

    private let maxValue = 4_000
    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 12) {
                yAxisLabels

                HStack(alignment: .bottom, spacing: 18) {
                    ForEach(chartDays) { day in
                        VStack(spacing: 12) {
                            GeometryReader { proxy in
                                let barHeight = proxy.size.height * day.normalizedValue

                                VStack {
                                    Spacer()
                                    Capsule()
                                        .fill(day.isToday ? SomaColors.white : SomaColors.white.opacity(0.48))
                                        .frame(height: isAnimated ? barHeight : 0)
                                }
                            }
                            .frame(height: 220)

                            Text(day.label)
                                .font(.system(size: 11, weight: .bold, design: .default))
                                .foregroundStyle(SomaColors.white.opacity(0.78))
                                .frame(width: 30)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
                isAnimated = true
            }
        }
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
        .frame(width: 26, height: 248)
    }

    private var chartDays: [ChartDay] {
        let today = calendar.startOfDay(for: .now)
        let logValues = logs.reduce(into: [Date: Int]()) { result, log in
            result[calendar.startOfDay(for: log.date), default: 0] += log.totalCalories
        }

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
