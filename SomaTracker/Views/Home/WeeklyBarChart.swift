import SwiftUI

struct WeeklyBarChart: View {
    let logs: [DailyLog]

    @State private var isAnimated = false
    @State private var selectedDay: ChartDay?

    private let maxValue = 4_000
    private let calendar = Calendar.current

    // Total layout heights
    private let totalHeight: CGFloat = 256
    private let barHeight: CGFloat = 160
    private let labelHeight: CGFloat = 18
    private let bottomBuffer: CGFloat = 48

    // Empty-day "slot" placeholder: a short, faint capsule signalling a day exists.
    private let placeholderHeight: CGFloat = 7

    var body: some View {
        VStack(spacing: 0) {
            // Selected Day Tooltip Pill (with full vertical clearance)
            ZStack {
                if let selected = selectedDay {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.orange)

                        Text("\(selected.fullDateString): \(selected.value.formatted()) kcal")
                            .font(.system(size: 12, weight: .bold, design: .default))
                            .foregroundStyle(SomaColors.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(SomaColors.white.opacity(0.2))
                    .clipShape(Capsule())
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .frame(height: 30)
            .padding(.top, 4)
            .padding(.bottom, 6)

            // Bars row
            HStack(alignment: .bottom, spacing: 10) {
                yAxisLabels

                HStack(alignment: .bottom, spacing: 16) {
                    ForEach(chartDays) { day in
                        GeometryReader { proxy in
                            let barH = proxy.size.height * day.normalizedValue

                            VStack {
                                Spacer()
                                Capsule()
                                    .fill(barFill(for: day))
                                    .frame(height: barFrameHeight(for: day, fullHeight: barH))
                                    .scaleEffect(selectedDay?.id == day.id ? 1.05 : 1.0, anchor: .bottom)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard day.hasData else { return }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    if selectedDay?.id == day.id {
                                        selectedDay = nil
                                    } else {
                                        selectedDay = day
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: barHeight)
            .padding(.bottom, 8)

            // Day labels row
            HStack(spacing: 10) {
                Color.clear.frame(width: 26)

                HStack(spacing: 16) {
                    ForEach(chartDays) { day in
                        Text(day.label)
                            .font(.system(size: 11, weight: selectedDay?.id == day.id ? .heavy : .bold, design: .default))
                            .foregroundStyle(selectedDay?.id == day.id ? SomaColors.white : SomaColors.white.opacity(day.hasData ? 0.85 : 0.45))
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard day.hasData else { return }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    if selectedDay?.id == day.id {
                                        selectedDay = nil
                                    } else {
                                        selectedDay = day
                                    }
                                }
                            }
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
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
                isAnimated = true
            }
        }
    }

    private func barFill(for day: ChartDay) -> Color {
        guard day.hasData else {
            return SomaColors.white.opacity(0.12) // empty-day slot
        }
        if let selected = selectedDay {
            if selected.id == day.id {
                return SomaColors.white
            } else {
                return SomaColors.white.opacity(0.28)
            }
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

    var fullDateString: String {
        if isToday {
            return "Today"
        }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}

#Preview {
    WeeklyBarChart(logs: [])
        .padding()
        .background(SomaColors.navy)
}
