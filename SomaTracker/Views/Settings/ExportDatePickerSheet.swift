import SwiftUI
import SwiftData

struct ExportDatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let logs: [DailyLog]

    @State private var startDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
    @State private var endDate: Date = .now
    @State private var selectedPreset: ExportPreset = .past30Days
    @State private var exportShareURL: URL?

    enum ExportPreset: String, CaseIterable, Identifiable {
        case allTime = "All Time"
        case past7Days = "7 Days"
        case past30Days = "30 Days"
        case thisMonth = "This Month"
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
                // Preset segment
                Section {
                    Picker("Preset", selection: $selectedPreset) {
                        ForEach(ExportPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .onChange(of: selectedPreset) { _, newPreset in
                        applyPreset(newPreset)
                    }
                } header: {
                    Text("QUICK RANGE")
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
                        selectedPreset = .custom
                    }

                    DatePicker(
                        "End Date",
                        selection: $endDate,
                        in: startDate...Date.now,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .onChange(of: endDate) { _, _ in
                        selectedPreset = .custom
                    }
                } header: {
                    Text("DATE RANGE")
                } footer: {
                    Text("Choose the date boundaries to include in your exported file.")
                }

                // Summary & File Info
                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(SomaColors.navy)
                                .frame(width: 36, height: 36)

                            Image(systemName: "tablecells")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
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
                }

                // Export Button
                Section {
                    Button {
                        exportData()
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Export CSV")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .frame(height: 44)
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
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(SomaColors.navy)
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
                startDate = oldestLog.date
                selectedPreset = .allTime
            } else {
                applyPreset(.past30Days)
            }
        }
    }

    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: .now)
    }

    private func applyPreset(_ preset: ExportPreset) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        endDate = .now

        switch preset {
        case .allTime:
            if let oldest = logs.min(by: { $0.date < $1.date }) {
                startDate = oldest.date
            } else {
                startDate = calendar.date(byAdding: .day, value: -30, to: today) ?? today
            }
        case .past7Days:
            startDate = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        case .past30Days:
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
    }

    private func exportData() {
        if let url = DataExporter.createExportFileURL(logs: logs, startDate: startDate, endDate: endDate) {
            exportShareURL = url
        }
    }
}

#Preview {
    ExportDatePickerSheet(logs: [])
}
