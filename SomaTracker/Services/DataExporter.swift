import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum ExportDateRange: String, CaseIterable, Identifiable {
    case allTime = "All Time"
    case past7Days = "Past 7 Days"
    case past30Days = "Past 30 Days"
    case thisMonth = "This Month"

    var id: Self { self }

    func filter(logs: [DailyLog]) -> [DailyLog] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        switch self {
        case .allTime:
            return logs
        case .past7Days:
            guard let cutoff = calendar.date(byAdding: .day, value: -7, to: today) else { return logs }
            return logs.filter { $0.date >= cutoff }
        case .past30Days:
            guard let cutoff = calendar.date(byAdding: .day, value: -30, to: today) else { return logs }
            return logs.filter { $0.date >= cutoff }
        case .thisMonth:
            guard let monthInterval = calendar.dateInterval(of: .month, for: today) else { return logs }
            return logs.filter { $0.date >= monthInterval.start && $0.date <= monthInterval.end }
        }
    }
}

struct DataExporter {
    static func generateCSV(logs: [DailyLog]) -> String {
        var csv = "Date,Steps,Total Calories (kcal),Total Protein (g),Total Water (ml),Detailed Items Logged\n"

        let sortedLogs = logs.sorted { $0.date > $1.date }

        for log in sortedLogs {
            let dateStr = log.date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
            let steps = "\(log.steps)"
            let calories = "\(log.totalCalories)"
            let protein = "\(Int(log.totalProtein.rounded()))"
            let water = "\(log.totalWater)"

            var allItemSummaries: [String] = []

            for entry in log.foodEntries {
                let name = entry.name.isEmpty ? "Food" : entry.name
                var details = "\(name): \(entry.effectiveCalories) kcal"
                var macros: [String] = []
                if entry.proteinG > 0 {
                    macros.append("\(Int(entry.proteinG.rounded()))g P")
                }
                if entry.carbsG > 0 {
                    macros.append("\(Int(entry.carbsG.rounded()))g C")
                }
                if entry.fatG > 0 {
                    macros.append("\(Int(entry.fatG.rounded()))g F")
                }
                if !macros.isEmpty {
                    details += " (\(macros.joined(separator: ", ")))"
                }
                allItemSummaries.append(details)
            }

            for waterEntry in log.waterEntries {
                let title = waterEntry.resolvedTitle
                allItemSummaries.append("\(title): \(waterEntry.amount) ml")
            }

            let itemsJoined = allItemSummaries.joined(separator: " | ")
            let escapedItems = "\"\(itemsJoined.replacingOccurrences(of: "\"", with: "\"\""))\""

            let row = "\(dateStr),\(steps),\(calories),\(protein),\(water),\(escapedItems)\n"
            csv.append(row)
        }

        return csv
    }

    static func createExportFileURL(logs: [DailyLog], range: ExportDateRange = .allTime) -> URL? {
        let filtered = range.filter(logs: logs)
        return createExportFileURL(logs: filtered)
    }

    static func createExportFileURL(logs: [DailyLog], startDate: Date, endDate: Date) -> URL? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate

        let filtered = logs.filter { $0.date >= start && $0.date <= end }
        return createExportFileURL(logs: filtered)
    }

    private static func createExportFileURL(logs: [DailyLog]) -> URL? {
        let csvContent = generateCSV(logs: logs)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: .now)

        let filename = "Soma_History_Export_\(dateString).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("Failed to write CSV export file: \(error)")
            return nil
        }
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
