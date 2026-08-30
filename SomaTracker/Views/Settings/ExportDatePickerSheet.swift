import SwiftUI
import SwiftData

struct ExportDatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let logs: [DailyLog]

    @State private var startDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
    @State private var endDate: Date = .now
    @State private var selectedRange: ExportRange = .last30Days
    @State private var isApplyingPreset = false
    @State private var exportShareURL: URL?

    enum ExportRange: String, CaseIterable, Identifiable {
        case all = "All"
        case last7Days = "7D"
        case last30Days = "30D"
        case thisMonth = "Month"
        case custom = "Custom"

        var id: Self { self }
    }

    private var matchingLogsCount: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate

        return logs.filter { $0.date >= start && $0.date <= end }.count
    }

    var body: some View {
        NavigationStack {
            List {
                // Quick Range Preset segment (Compact labels to prevent truncation)
                Section {
                    Picker("Quick Range", selection: $selectedRange) {
                        ForEach(ExportRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
                    .listRowBackground(Color.clear)
                    .onChange(of: selectedRange) { _, newRange in
                        applyRange(newRange)
                    }
                } header: {
                    Text("QUICK RANGE")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(.secondaryLabel))
                        .textCase(.uppercase)
                }

                // Date Picker components
                Section {
                    DatePicker(
                        "Start Date",
                        selection: $startDate,
                        in: ...endDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .onChange(of: startDate) { _, _ in
                        if !isApplyingPreset {
                            selectedRange = .custom
                        }
                    }

                    DatePicker(
                        "End Date",
                        selection: $endDate,
                        in: startDate...Date.now,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .onChange(of: endDate) { _, _ in
                        if !isApplyingPreset {
                            selectedRange = .custom
                        }
                    }
                } header: {
                    Text("DATE RANGE")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(.secondaryLabel))
                        .textCase(.uppercase)
                } footer: {
                    Text("Choose the date boundaries to include in your exported file.")
                        .font(.caption)
                        .foregroundStyle(Color(.tertiaryLabel))
                }

                // Summary & File Info
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(.secondarySystemFill))
                                .frame(width: 40, height: 40)

                            Image(systemName: "tablecells")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(SomaColors.navy)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Soma_History_Export_\(currentDateString).csv")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(.label))

                            Text("\(matchingLogsCount) daily log\(matchingLogsCount == 1 ? "" : "s") selected")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("EXPORT PREVIEW")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(.secondaryLabel))
                        .textCase(.uppercase)
                }

                // Primary Action Button
                Section {
                    Button {
                        exportData()
                    } label: {
                        HStack(spacing: 8) {
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Export CSV")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .frame(height: 48)
                        .background(SomaColors.navy)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .disabled(matchingLogsCount == 0)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Export History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
            .sheet(isPresented: Binding(get: { exportShareURL != nil }, set: { if !$0 { exportShareURL = nil } })) {
                if let url = exportShareURL {
                    ActivityViewController(activityItems: [url])
                }
            }
        }
        .onAppear {
            if let oldestLog = logs.min(by: { $0.date < $1.date }) {
                isApplyingPreset = true
                startDate = oldestLog.date
                selectedRange = .all
                DispatchQueue.main.async {
                    isApplyingPreset = false
                }
            } else {
                applyRange(.last30Days)
            }
        }
    }

    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: .now)
    }

    private func applyRange(_ range: ExportRange) {
        guard range != .custom else { return }
        isApplyingPreset = true

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        endDate = .now

        switch range {
        case .all:
            if let oldest = logs.min(by: { $0.date < $1.date }) {
                startDate = oldest.date
            } else {
                startDate = calendar.date(byAdding: .day, value: -30, to: today) ?? today
            }
        case .last7Days:
            startDate = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        case .last30Days:
            startDate = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        case .thisMonth:
            if let monthInterval = calendar.dateInterval(of: .month, for: today) {
                startDate = monthInterval.start
            } else {
                startDate = today
            }
        case .custom:
            break
        }
        UISelectionFeedbackGenerator().selectionChanged()

        DispatchQueue.main.async {
            isApplyingPreset = false
        }
    }

    private func exportData() {
        if let url = DataExporter.createExportFileURL(logs: logs, startDate: startDate, endDate: endDate) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            exportShareURL = url
        }
    }
}

#Preview {
    ExportDatePickerSheet(logs: [])
}
