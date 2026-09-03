import SwiftUI

struct WeeklyBarChart: View {
    let logs: [DailyLog]
    @Binding var selectedDate: Date?

    @State private var isAnimated = false

    private let maxValue = 4_000
    private let calendar = Calendar.current

    // Total layout heights
    private let totalHeight: CGFloat = 256
    private let barHeight: CGFloat = 160
    private let labelHeight: CGFloat = 18
    private let bottomBuffer: CGFloat = 48

    // Empty-day "slot" placeholder: a short, faint capsule signalling a day exists.
    private let placeholderHeight: CGFloat = 7

    private var selectedDay: ChartDay? {
        guard let selectedDate else { return nil }
        return chartDays.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Selected Day Tooltip Pill (with full vertical clearance)
            ZStack {
                if let selected = selectedDay {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedDate = nil
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.orange)

                            Text("\(selected.fullDateString): \(selected.value.formatted()) kcal")
                                .font(.system(size: 12, weight: .bold, design: .default))
                                .foregroundStyle(SomaColors.white)

                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(SomaColors.white.opacity(0.6))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(SomaColors.white.opacity(0.2))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
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
                                    if let selectedDate, calendar.isDate(selectedDate, inSameDayAs: day.date) {
                                        self.selectedDate = nil
                                    } else {
                                        self.selectedDate = day.date
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
                                    if let selectedDate, calendar.isDate(selectedDate, inSameDayAs: day.date) {
                                        self.selectedDate = nil
                                    } else {
                                        self.selectedDate = day.date
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
        let logMap = logs.reduce(into: [Date: DailyLog]()) { result, log in
            result[calendar.startOfDay(for: log.date)] = log
        }

        // Oldest on left, today on right
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - 6, to: today) else {
                return nil
            }

            let log = logMap[date]
            let calories = log?.totalCalories ?? 0
            let hasAnyData = calories > 0 || (log?.totalWater ?? 0) > 0 || (log?.steps ?? 0) > 0

            return ChartDay(
                date: date,
                value: calories,
                maxValue: maxValue,
                isToday: calendar.isDate(date, inSameDayAs: today),
                hasData: hasAnyData
            )
        }
    }
}

private struct ChartDay: Identifiable {
    let date: Date
    let value: Int
    let maxValue: Int
    let isToday: Bool
    let hasData: Bool

    var id: Date { date }

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
    @Previewable @State var selectedDate: Date? = nil
    WeeklyBarChart(logs: [], selectedDate: $selectedDate)
        .padding()
        .background(SomaColors.navy)
}
