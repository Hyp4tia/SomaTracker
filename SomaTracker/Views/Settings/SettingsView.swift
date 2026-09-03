import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var appRouter
    @Query private var profiles: [UserProfile]
    @Query private var logs: [DailyLog]

    @StateObject private var notificationManager = NotificationManager.shared
    @AppStorage(Units.storageKey) private var unitSystemRaw = UnitSystem.metric.rawValue

    @State private var editingGoal: GoalType?
    @State private var goalDraftValue = ""
    @State private var showResetConfirmation = false
    @State private var showExportSheet = false

    private var unitSystem: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }
    private var profile: UserProfile? { profiles.first }

    var body: some View {
        List {
            // MARK: - Profile
            Section {
                NavigationLink {
                    ProfileEditView()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Color.white, Color(.systemGray3))
                            .font(.system(size: 54))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(profile?.name.isEmpty == false ? profile!.name : "User")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color(.label))

                            Text("Personal Info & Body Stats")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            // MARK: - Goals
            Section {
                goalRow(
                    icon: "flame.fill",
                    iconColor: SomaColors.coral,
                    isCircularBadge: false,
                    title: "Calories",
                    subtitle: "Daily energy target",
                    value: "\(profile?.dailyCalorieGoal ?? 2_000) kcal",
                    goalType: .calories
                )

                goalRow(
                    icon: "drop.fill",
                    iconColor: .blue,
                    isCircularBadge: false,
                    title: "Water",
                    subtitle: "Daily hydration goal",
                    value: "\(Units.waterValue(ml: profile?.dailyWaterGoalML ?? 2_000, system: unitSystem)) \(Units.waterUnit(unitSystem))",
                    goalType: .water
                )

                goalRow(
                    icon: "leaf.fill",
                    iconColor: SomaColors.iris,
                    isCircularBadge: false,
                    title: "Protein",
                    subtitle: "Macro recovery target",
                    value: "\(profile?.dailyProteinGoalG ?? 120) g",
                    goalType: .protein
                )
            } header: {
                Text("DAILY GOALS")
            } footer: {
                Text("Goals determine your daily progress bars and target statistics.")
            }

            // MARK: - Logs & History
            Section {
                NavigationLink {
                    HistoryView()
                } label: {
                    HStack(spacing: 14) {
                        rowIcon(icon: "clock.arrow.circlepath", color: SomaColors.navy, isCircularBadge: false)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Log History")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(.label))

                            Text("Review past logs & timeline")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                    }
                    .padding(.vertical, 3)
                }

                Button {
                    showExportSheet = true
                } label: {
                    HStack(spacing: 14) {
                        rowIcon(icon: "square.and.arrow.up", color: SomaColors.emerald, isCircularBadge: false)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export Data (.csv)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(.label))

                            Text("Download spreadsheet report")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(.secondaryLabel))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                    .padding(.vertical, 3)
                }
            } header: {
                Text("HISTORY & DATA")
            }

            // MARK: - Preferences
            Section {
                HStack(spacing: 14) {
                    // Soft coral/red bell matching screenshot
                    rowIcon(icon: "bell.fill", color: Color(red: 0.95, green: 0.35, blue: 0.35), isCircularBadge: false)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily reminder")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(.label))

                        Text("Get a gentle practice nudge")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(.secondaryLabel))
                    }

                    Spacer()

                    Toggle("", isOn: $notificationManager.isEnabled)
                        .labelsHidden()
                        .tint(Color.green)
                }
                .padding(.vertical, 3)

                if notificationManager.isEnabled {
                    HStack(spacing: 14) {
                        // Royal blue circular badge with white clock icon matching screenshot
                        rowIcon(icon: "clock.fill", color: Color(red: 0.08, green: 0.45, blue: 0.95), isCircularBadge: true)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reminder time")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(.label))

                            Text("Morning habit check-in")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(.secondaryLabel))
                        }

                        Spacer()

                        DatePicker(
                            "",
                            selection: $notificationManager.dailyReminderTime,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    }
                    .padding(.vertical, 3)

                    HStack(spacing: 14) {
                        // Evening wrap up reminder time
                        rowIcon(icon: "moon.fill", color: Color(red: 0.35, green: 0.35, blue: 0.85), isCircularBadge: true)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Evening wrap-up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(.label))

                            Text("Review what you missed before bed")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(.secondaryLabel))
                        }

                        Spacer()

                        DatePicker(
                            "",
                            selection: $notificationManager.eveningReminderTime,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    }
                    .padding(.vertical, 3)
                }

                Picker(selection: $unitSystemRaw) {
                    ForEach(UnitSystem.allCases) { system in
                        Text(system.title).tag(system.rawValue)
                    }
                } label: {
                    HStack(spacing: 14) {
                        rowIcon(icon: "ruler.fill", color: Color(hex: "007AFF"), isCircularBadge: false)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Units")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(.label))

                            Text("Measurement standard")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                    }
                    .padding(.vertical, 3)
                }
                .pickerStyle(.menu)
            } header: {
                Text("PREFERENCES")
            }

            // MARK: - About & Feedback
            Section {
                Button {
                    requestReview()
                } label: {
                    HStack(spacing: 14) {
                        rowIcon(icon: "star.fill", color: Color(hex: "FFCC00"), isCircularBadge: false)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rate Soma")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(.label))

                            Text("Share your review on the App Store")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(.secondaryLabel))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                    .padding(.vertical, 3)
                }

                Button {
                    openURL("https://x.com/hypatox?s=21&t=-yUOJjsm0CIezkq3MgTq5Q")
                } label: {
                    HStack(spacing: 14) {
                        rowIcon(icon: "paperplane.fill", color: Color(hex: "5856D6"), isCircularBadge: false)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Contact & Feedback")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(.label))

                            Text("Reach out directly with questions")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(.secondaryLabel))
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                    .padding(.vertical, 3)
                }

                Button {
                    openURL("https://soma-tracker.app/privacy")
                } label: {
                    HStack(spacing: 14) {
                        rowIcon(icon: "lock.fill", color: Color(hex: "64748B"), isCircularBadge: false)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Privacy Policy")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(.label))

                            Text("Your health data stays on device")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(.secondaryLabel))
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                    .padding(.vertical, 3)
                }
            } header: {
                Text("ABOUT & FEEDBACK")
            }

            // MARK: - Danger Zone
            Section {
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    HStack(spacing: 14) {
                        rowIcon(icon: "trash.fill", color: .red, isCircularBadge: false)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reset All Data")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.red)

                            Text("Delete all records and restart")
                                .font(.system(size: 13))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                    }
                    .padding(.vertical, 3)
                }
                .confirmationDialog(
                    "Reset All Data?",
                    isPresented: $showResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Reset All Data", role: .destructive) {
                        resetAllData()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently delete all your logs, entries, and profile data. You will be returned to the initial setup screen.")
                }
            } header: {
                Text("ACCOUNT")
            }

            // MARK: - Version & Credits
            Section {
                VStack(spacing: 4) {
                    Text("Soma 1.0.0")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(.secondaryLabel))

                    Text("Track what matters.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("Edit \(editingGoal?.title ?? "") Goal", isPresented: .init(
            get: { editingGoal != nil },
            set: { if !$0 { editingGoal = nil } }
        )) {
            TextField("Value", text: $goalDraftValue)
                .keyboardType(.numberPad)
            Button("Save") { saveGoal() }
            Button("Cancel", role: .cancel) { editingGoal = nil }
        } message: {
            Text("Enter your daily \(editingGoal?.title.lowercased() ?? "") goal in \(editingGoalUnit).")
        }
        .sheet(isPresented: $showExportSheet) {
            ExportDatePickerSheet(logs: logs)
                .preferredColorScheme(.light)
                .presentationDetents([.fraction(0.70), .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Row Helpers

    private func goalRow(
        icon: String,
        iconColor: Color,
        isCircularBadge: Bool,
        title: String,
        subtitle: String,
        value: String,
        goalType: GoalType
    ) -> some View {
        Button {
            editingGoal = goalType
            switch goalType {
            case .calories:
                goalDraftValue = "\(profile?.dailyCalorieGoal ?? 2_000)"
            case .water:
                goalDraftValue = "\(Units.waterValue(ml: profile?.dailyWaterGoalML ?? 2_000, system: unitSystem))"
            case .protein:
                goalDraftValue = "\(profile?.dailyProteinGoalG ?? 120)"
            }
        } label: {
            HStack(spacing: 14) {
                rowIcon(icon: icon, color: iconColor, isCircularBadge: isCircularBadge)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(.label))

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(.secondaryLabel))
                }

                Spacer()

                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(.label))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(.vertical, 3)
        }
    }

    @ViewBuilder
    private func rowIcon(icon: String, color: Color, isCircularBadge: Bool) -> some View {
        if isCircularBadge {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 26, height: 26)

                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 28, height: 28)
        } else {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28, alignment: .center)
        }
    }

    private var profileInitials: String {
        guard let name = profile?.name.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return "S"
        }
        let initials = name
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
        return initials.isEmpty ? "S" : initials.uppercased()
    }

    private func saveGoal() {
        guard let goal = editingGoal,
              let value = Int(goalDraftValue),
              value > 0,
              let profile else {
            editingGoal = nil
            return
        }

        switch goal {
        case .calories:
            profile.dailyCalorieGoal = value
        case .water:
            profile.dailyWaterGoalML = Units.waterToML(value, system: unitSystem)
        case .protein:
            profile.dailyProteinGoalG = value
        }

        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        editingGoal = nil
    }

    private var editingGoalUnit: String {
        switch editingGoal {
        case .water: return Units.waterUnit(unitSystem)
        case .calories: return "kcal"
        case .protein: return "g"
        case .none: return ""
        }
    }

    private func resetAllData() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        do {
            try modelContext.delete(model: FoodEntry.self)
            try modelContext.delete(model: WaterEntry.self)
            try modelContext.delete(model: DailyLog.self)
            try modelContext.delete(model: UserProfile.self)
            try modelContext.save()
        } catch {
            print("[Settings] Reset failed: \(error.localizedDescription)")
        }

        appRouter.hasCompletedOnboarding = false
    }

    private func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return
        }
        AppStore.requestReview(in: scene)
    }

    private func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - GoalType

private enum GoalType {
    case calories, water, protein

    var title: String {
        switch self {
        case .calories: "Calories"
        case .water: "Water"
        case .protein: "Protein"
        }
    }
}

// MARK: - Profile Edit View

struct ProfileEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @AppStorage(Units.storageKey) private var unitSystemRaw = UnitSystem.metric.rawValue

    @State private var name = ""
    @State private var age = ""
    @State private var gender = "Male"
    @State private var activityLevel = "Moderate"
    @State private var weight = ""
    @State private var height = ""

    private var profile: UserProfile? { profiles.first }
    private var unitSystem: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    private let genderOptions = ["Male", "Female", "Other"]
    private let activityLevelOptions = ["Sedentary", "Light", "Moderate", "Active", "VeryActive"]

    var body: some View {
        Form {
            Section("Personal Info") {
                HStack {
                    Text("Name")
                        .frame(width: 80, alignment: .leading)
                    TextField("Full Name", text: $name)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Age")
                        .frame(width: 80, alignment: .leading)
                    TextField("Age", text: $age)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }

                Picker("Gender", selection: $gender) {
                    ForEach(genderOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
            }

            Section("Body Stats") {
                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("0", text: $weight)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 80)
                    Text(Units.weightUnit(unitSystem))
                        .foregroundStyle(Color(.secondaryLabel))
                }

                HStack {
                    Text("Height")
                    Spacer()
                    TextField("0", text: $height)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 80)
                    Text(Units.heightUnit(unitSystem))
                        .foregroundStyle(Color(.secondaryLabel))
                }

                Picker("Activity Level", selection: $activityLevel) {
                    ForEach(activityLevelOptions, id: \.self) { level in
                        Text(formatActivityLevel(level)).tag(level)
                    }
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard let profile else { return }
            name = profile.name
            age = "\(profile.age)"
            gender = profile.gender.isEmpty ? "Male" : profile.gender
            activityLevel = profile.activityLevel.isEmpty ? "Moderate" : profile.activityLevel
            weight = String(format: "%.1f", Units.weightValue(kg: profile.weightKG, system: unitSystem))
            height = String(format: "%.1f", Units.heightValue(cm: profile.heightCM, system: unitSystem))
        }
        .onDisappear {
            guard let profile else { return }
            profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if let a = Int(age) { profile.age = a }
            profile.gender = gender
            profile.activityLevel = activityLevel
            if let w = Double(weight) { profile.weightKG = Units.weightToKG(w, system: unitSystem) }
            if let h = Double(height) { profile.heightCM = Units.heightToCM(h, system: unitSystem) }
            try? modelContext.save()
        }
    }

    private func formatActivityLevel(_ level: String) -> String {
        switch level {
        case "Sedentary": return "Sedentary"
        case "Light": return "Lightly Active"
        case "Moderate": return "Moderately Active"
        case "Active": return "Active"
        case "VeryActive": return "Very Active"
        default: return level
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(PreviewData.container)
    .environment(AppRouter())
}

