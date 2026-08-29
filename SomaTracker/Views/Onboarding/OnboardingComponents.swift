import SwiftUI

/// Resigns the first responder, dismissing the keyboard from anywhere.
@MainActor
func dismissKeyboard() {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil,
        from: nil,
        for: nil
    )
}

extension View {
    /// Adds a "Done" button above the keyboard and lets a tap anywhere on the
    /// background dismiss it — so onboarding fields never trap the user.
    func dismissKeyboardOnInteraction() -> some View {
        self
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                        .fontWeight(.semibold)
                }
            }
    }
}

struct OnboardingTopBar: View {
    let step: Int
    var onBack: (() -> Void)? = nil

    var body: some View {
        ZStack {
            if let onBack = onBack {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(SomaColors.white)
                            .frame(width: 44, height: 44)
                            .background(SomaColors.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
            }

            OnboardingProgressDots(step: step)
        }
        .frame(height: 44)
    }
}

struct OnboardingProgressDots: View {
    let step: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { index in
                Capsule()
                    .fill(index == step ? SomaColors.white : SomaColors.white.opacity(0.35))
                    .frame(width: index == step ? 24 : 8, height: 8)
            }
        }
        .frame(height: 8)
    }
}

struct OnboardingIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 28, weight: .semibold, design: .default))
            .foregroundStyle(SomaColors.white)
            .frame(width: 80, height: 80)
            .background(SomaColors.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct OnboardingField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(SomaTypography.caption.weight(.bold))
                .foregroundStyle(SomaColors.white.opacity(0.62))
                .textCase(.uppercase)

            TextField("", text: $text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(SomaTypography.body.weight(.bold))
                .foregroundStyle(SomaColors.white)
                .tint(SomaColors.white)
                .padding(.horizontal, 18)
                .frame(height: 58)
                .background(SomaColors.white.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(SomaColors.white.opacity(0.25), lineWidth: 1)
                }
        }
    }
}

struct OnboardingPickerField: View {
    let title: String
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(SomaTypography.caption.weight(.bold))
                .foregroundStyle(SomaColors.white.opacity(0.62))
                .textCase(.uppercase)

            Menu {
                Button("Male") { selection = "Male" }
                Button("Female") { selection = "Female" }
                Button("Other") { selection = "Other" }
            } label: {
                HStack {
                    Text(selection.isEmpty ? "Select" : selection)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(SomaColors.white.opacity(0.6))
                }
                .font(SomaTypography.body.weight(.bold))
                .foregroundStyle(SomaColors.white)
                .padding(.horizontal, 18)
                .frame(height: 58)
                .background(SomaColors.white.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(SomaColors.white.opacity(0.25), lineWidth: 1)
                }
            }
        }
    }
}

struct OnboardingContinueLabel: View {
    var title: String = "Continue"
    var showArrow: Bool = true
    var foregroundColor: Color = SomaColors.navy

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(SomaTypography.body.weight(.bold))

            if showArrow {
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .bold))
            }
        }
        .foregroundStyle(foregroundColor)
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(SomaColors.white)
        .clipShape(Capsule())
    }
}

struct OnboardingSkipLink<Destination: View>: View {
    let destination: Destination

    var body: some View {
        NavigationLink(destination: destination) {
            Text("Skip for now")
                .font(SomaTypography.body.weight(.semibold))
                .foregroundStyle(SomaColors.white.opacity(0.48))
        }
    }
}
