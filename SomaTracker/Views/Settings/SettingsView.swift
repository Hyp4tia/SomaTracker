import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var appRouter
    @Query private var profiles: [UserProfile]

    @State private var editingGoal: GoalType?
    @State private var goalDraftValue = ""
    @State private var showResetConfirmation = false
    @State private var notificationsEnabled = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        ZStack(alignment: .top) {
            // Base layer: white fills the whole screen (bottom + behind tab bar)
            SomaColors.white
                .ignoresSafeArea()

            // Top layer: navy only at the top — fills the top overscroll area
            SomaColors.navy
                .frame(height: 220)
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea(edges: .top)

            ScrollView {
                VStack(spacing: 0) {
                    // Navy header with illustration
                    headerSection

                    VStack(spacing: 20) {
                        profileCard
                            .padding(.horizontal, 16)

                        goalsSection
                            .padding(.horizontal, 16)

                        preferencesSection
                            .padding(.horizontal, 16)

                        aboutSection
                            .padding(.horizontal, 16)

                        versionLabel

                        buyMeCoffeeButton
                            .padding(.horizontal, 16)

                        resetDataButton
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                    .frame(maxWidth: .infinity)
                    .background(SomaColors.white)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 24,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 24,
                            style: .continuous
                        )
                    )
                    .offset(y: -24)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .ignoresSafeArea(edges: .top)
        }
        .alert("Edit \(editingGoal?.title ?? "")", isPresented: .init(
            get: { editingGoal != nil },
            set: { if !$0 { editingGoal = nil } }
        )) {
            TextField("Value", text: $goalDraftValue)
                .keyboardType(.numberPad)
            Button("Save") { saveGoal() }
            Button("Cancel", role: .cancel) { editingGoal = nil }
        } message: {
            Text("Enter your daily \(editingGoal?.title.lowercased() ?? "") goal in \(editingGoal?.unit ?? "")")
        }
        .alert("Reset All Data", isPresented: $showResetConfirmation) {
            Button("Reset", role: .destructive) { resetAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all your logs, entries, and profile data. This action cannot be undone.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        ZStack(alignment: .topLeading) {
            SomaColors.navy
                .frame(height: 184)

            Image("splash-illustration")
                .resizable()
                .scaledToFit()
                .frame(width: 180)
                .opacity(0.35)
                .padding(.top, 20)
                .padding(.leading, -20)
        }
        .clipped()
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        NavigationLink {
            ProfileEditView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color(.systemGray4), Color(.systemGray6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile?.name ?? "User")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(.label))

                    Text("Edit Profile")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(.secondaryLabel))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(16)
            .background(Color(.systemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Goals Section

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("GOALS")

            VStack(spacing: 0) {
                goalRow(
                    icon: "flame.fill",
                    title: "Daily Calories",
                    value: "\(profile?.dailyCalorieGoal ?? 2_000) kcal",
                    goalType: .calories
                )

                Divider().padding(.leading, 56)

                goalRow(
                    icon: "drop.fill",
                    title: "Daily Water",
                    value: "\(profile?.dailyWaterGoalML ?? 2_000) ml",
                    goalType: .water
                )

                Divider().padding(.leading, 56)

                goalRow(
                    icon: "fish.fill",
                    title: "Daily Protein",
                    value: "\(profile?.dailyProteinGoalG ?? 120) g",
                    goalType: .protein
                )
            }
            .background(Color(.systemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func goalRow(
        icon: String,
        title: String,
        value: String,
        goalType: GoalType
    ) -> some View {
        Button {
            editingGoal = goalType
            switch goalType {
            case .calories: goalDraftValue = "\(profile?.dailyCalorieGoal ?? 2_000)"
            case .water: goalDraftValue = "\(profile?.dailyWaterGoalML ?? 2_000)"
            case .protein: goalDraftValue = "\(profile?.dailyProteinGoalG ?? 120)"
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SomaColors.navy)
                    .frame(width: 32, height: 32)
                    .background(SomaColors.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(Color(.label))

                Spacer()

                Text(value)
                    .font(.system(size: 15))
                    .foregroundStyle(Color(.secondaryLabel))

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("PREFERENCES")

            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(SomaColors.navy)
                        .frame(width: 32, height: 32)
                        .background(SomaColors.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Text("Notifications")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(.label))

                    Spacer()

                    Toggle("", isOn: $notificationsEnabled)
                        .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)

                Divider().padding(.leading, 56)

                HStack(spacing: 14) {
                    Image(systemName: "ruler.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(SomaColors.navy)
                        .frame(width: 32, height: 32)
                        .background(SomaColors.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Text("Units")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(.label))

                    Spacer()

                    Text("Metric")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(.secondaryLabel))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            }
            .background(Color(.systemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("ABOUT")

            VStack(spacing: 0) {
                aboutRow(icon: "star.fill", iconColor: .yellow, title: "Rate the App") {
                    requestReview()
                }

                Divider().padding(.leading, 56)

                aboutRow(icon: "lock.fill", title: "Privacy Policy") {
                    openURL("https://soma-tracker.app/privacy")
                }

                Divider().padding(.leading, 56)

                aboutRow(icon: "message.fill", title: "Contact Me") {
                    openURL("https://x.com/hypatox?s=21&t=-yUOJjsm0CIezkq3MgTq5Q")
                }
            }
            .background(Color(.systemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func aboutRow(
        icon: String,
        iconColor: Color = SomaColors.navy,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 32, height: 32)
                    .background(SomaColors.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(Color(.label))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var versionLabel: some View {
        Text("Version 1.0.0")
            .font(.system(size: 13))
            .foregroundStyle(Color(.tertiaryLabel))
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }

    private var buyMeCoffeeButton: some View {
        Button {
            openURL("https://buymeacoffee.com/zeyadhussein")
        } label: {
            HStack(spacing: 8) {
                Text("\u{2615}")
                    .font(.system(size: 18))

                Text("Buy Me a Coffee")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(SomaColors.buyMeCoffeeYellow)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var resetDataButton: some View {
        Button {
            showResetConfirmation = true
        } label: {
            Text("Reset All Data")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color(.secondaryLabel))
            .padding(.leading, 4)
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
        case .calories: profile.dailyCalorieGoal = value
        case .water: profile.dailyWaterGoalML = value
        case .protein: profile.dailyProteinGoalG = value
        }

        try? modelContext.save()
        editingGoal = nil
    }

    private func resetAllData() {
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

    var unit: String {
        switch self {
        case .calories: "kcal"
        case .water: "ml"
        case .protein: "g"
        }
    }
}

// MARK: - Profile Edit

struct ProfileEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var name = ""
    @State private var age = ""
    @State private var weight = ""
    @State private var height = ""

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        Form {
            Section("Personal Info") {
                TextField("Name", text: $name)
                TextField("Age", text: $age)
                    .keyboardType(.numberPad)
            }

            Section("Body Stats") {
                TextField("Weight (kg)", text: $weight)
                    .keyboardType(.decimalPad)
                TextField("Height (cm)", text: $height)
                    .keyboardType(.decimalPad)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard let profile else { return }
            name = profile.name
            age = "\(profile.age)"
            weight = String(format: "%.1f", profile.weightKG)
            height = String(format: "%.1f", profile.heightCM)
        }
        .onDisappear {
            guard let profile else { return }
            profile.name = name
            profile.age = Int(age) ?? profile.age
            profile.weightKG = Double(weight) ?? profile.weightKG
            profile.heightCM = Double(height) ?? profile.heightCM
            try? modelContext.save()
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
