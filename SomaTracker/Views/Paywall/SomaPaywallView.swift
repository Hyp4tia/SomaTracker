//
//  SomaPaywallView.swift
//  SomaTracker
//
//  Luxury minimal paywall compliant with Apple Guideline 3.1.2 & 4.2.
//  Offers Weekly, Monthly, and Annual (3-Day Free Trial) plans.
//

import SwiftUI
import StoreKit

struct SomaPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedPlan: SubscriptionPlan = .yearly
    @State private var showRestoreSuccessAlert = false
    @State private var showRestoreFailureAlert = false

    // MARK: - Dev Redeem Code (Temporary for Testing - Easy to Remove)
    @State private var showRedeemCodeAlert = false
    @State private var redeemCodeInput = ""
    @State private var showRedeemResultAlert = false
    @State private var redeemAlertTitle = ""
    @State private var redeemAlertMessage = ""
    @State private var isRedeemSuccess = false
    @State private var showRevokeConfirmAlert = false

    enum SubscriptionPlan: String, CaseIterable, Identifiable {
        case yearly = "soma_pro_yearly"
        case monthly = "soma_pro_monthly"
        case weekly = "soma_pro_weekly"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .yearly: return "Annual Plan"
            case .monthly: return "Monthly Plan"
            case .weekly: return "Weekly Plan"
            }
        }

        var priceDescription: String {
            switch self {
            case .yearly: return "$29.99 / yr"
            case .monthly: return "$4.99 / mo"
            case .weekly: return "$1.99 / wk"
            }
        }

        var subDescription: String {
            switch self {
            case .yearly: return "$2.50 / mo · Billed annually"
            case .monthly: return "Flexible monthly billing"
            case .weekly: return "Billed weekly"
            }
        }

        var badgeText: String? {
            switch self {
            case .yearly: return "SAVE 70%"
            case .monthly: return nil
            case .weekly: return nil
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // MARK: - Header
                        VStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: subscriptionManager.isPro ? "checkmark.seal.fill" : "sparkles")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(subscriptionManager.isPro ? SomaColors.emerald : SomaColors.navy)
                                Text(subscriptionManager.isPro ? "SOMA PRO ACTIVE" : "SOMA PRO")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .tracking(2.0)
                                    .foregroundColor(subscriptionManager.isPro ? SomaColors.emerald : SomaColors.navy)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(subscriptionManager.isPro ? SomaColors.emerald.opacity(0.12) : SomaColors.navy.opacity(0.08))
                            )

                            Text("Elevate Your Nutrition")
                                .font(.system(size: 28, weight: .bold, design: .serif))
                                .foregroundColor(SomaColors.navy)
                                .multilineTextAlignment(.center)

                            Text("Unlimited multimodal AI voice, vision & Action Button lock screen intelligence.")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(SomaColors.subtext)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .padding(.top, 16)

                        // MARK: - Pro Features List
                        VStack(spacing: 14) {
                            featureRow(
                                icon: "camera.viewfinder",
                                title: "Unlimited AI Food Photos",
                                subtitle: "Instant OCR nutrition extraction for packaged cans, plates & Egyptian dishes."
                            )
                            featureRow(
                                icon: "waveform",
                                title: "Live Voice Logging",
                                subtitle: "Speak naturally in Egyptian Arabic or English with zero letter dropping."
                            )
                            featureRow(
                                icon: "bolt.fill",
                                title: "Action Button & Siri Logging",
                                subtitle: "Log meals and hydration instantly from the Lock Screen with zero taps."
                            )
                            featureRow(
                                icon: "flame.fill",
                                title: "Smart Macro Calibration",
                                subtitle: "Mathematical calorie consistency with AI-estimated meal and macro breakdowns."
                            )
                        }
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.03), radius: 10, y: 4)
                        )
                        .padding(.horizontal, 20)

                        // MARK: - Plan Selection or Active Subscription Card
                        if subscriptionManager.isPro {
                            activeSubscriptionCard
                        } else {
                            VStack(spacing: 12) {
                                ForEach(SubscriptionPlan.allCases) { plan in
                                    planCard(plan: plan)
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // MARK: - Action Button
                        VStack(spacing: 14) {
                            if subscriptionManager.isPro {
                                Button {
                                    dismiss()
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 15, weight: .bold))
                                        Text("Done")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(SomaColors.navy)
                                    )
                                    .shadow(color: SomaColors.navy.opacity(0.25), radius: 8, y: 4)
                                }
                            } else {
                                Button {
                                    handlePurchaseTapped()
                                } label: {
                                    HStack(spacing: 8) {
                                        if subscriptionManager.isPurchasing {
                                            ProgressView()
                                                .tint(.white)
                                        } else {
                                            Text("Continue with \(selectedPlan.title)")
                                                .font(.system(size: 16, weight: .semibold))
                                            Image(systemName: "arrow.right")
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(SomaColors.navy)
                                    )
                                    .shadow(color: SomaColors.navy.opacity(0.25), radius: 8, y: 4)
                                }
                                .disabled(subscriptionManager.isPurchasing)
                            }

                            // MARK: - Restore Purchases & Dev Redeem Code
                            HStack(spacing: 16) {
                                if !subscriptionManager.isPro {
                                    Button {
                                        handleRestoreTapped()
                                    } label: {
                                        if subscriptionManager.isRestoring {
                                            ProgressView()
                                                .tint(SomaColors.navy)
                                        } else {
                                            Text("Restore Purchases")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(SomaColors.navy)
                                        }
                                    }
                                    .disabled(subscriptionManager.isRestoring)

                                    Text("·")
                                        .foregroundColor(Color(uiColor: .tertiaryLabel))
                                }

                                Button {
                                    redeemCodeInput = ""
                                    showRedeemCodeAlert = true
                                } label: {
                                    Text(subscriptionManager.isPro ? "Redeem Another Code" : "Redeem Code")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(SomaColors.navy)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)

                        // MARK: - Legal & Disclosures (Apple Guideline 3.1.2)
                        VStack(spacing: 8) {
                            if !subscriptionManager.isPro {
                                Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period. You can manage and cancel your subscriptions in your App Store account settings.")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(Color(uiColor: .tertiaryLabel))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            } else if subscriptionManager.subscriptionExpirationDate != nil {
                                Text("Your subscription is active and managed through your Apple ID account.")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(Color(uiColor: .tertiaryLabel))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }

                            HStack(spacing: 16) {
                                Link("Terms of Use (EULA)", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(SomaColors.subtext)

                                Text("·")
                                    .foregroundColor(Color(uiColor: .tertiaryLabel))

                                Link("Privacy Policy", destination: URL(string: "https://soma-tracker.app/privacy")!)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(SomaColors.subtext)
                            }
                            .padding(.top, 4)
                        }
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(uiColor: .systemGray3))
                    }
                }
            }
            .alert("Purchases Restored", isPresented: $showRestoreSuccessAlert) {
                Button("OK") {
                    if subscriptionManager.isPro {
                        dismiss()
                    }
                }
            } message: {
                Text(subscriptionManager.isPro ? "Your Soma Pro subscription is active!" : "No previous subscriptions were found for this Apple ID.")
            }
            .alert("Restore Failed", isPresented: $showRestoreFailureAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(subscriptionManager.lastErrorMessage ?? "Unable to restore purchases at this time.")
            }
            // MARK: - Dev Redeem Code Alerts (Temporary for Testing - Easy to Remove)
            .alert("Redeem Code", isPresented: $showRedeemCodeAlert) {
                TextField("Code (e.g. dev67)", text: $redeemCodeInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Redeem") {
                    handleRedeemCode()
                }
                Button("Cancel", role: .cancel) {
                    redeemCodeInput = ""
                }
            } message: {
                Text("Enter your access code to unlock all Soma AI features.")
            }
            .alert(redeemAlertTitle, isPresented: $showRedeemResultAlert) {
                Button("OK") {
                    if isRedeemSuccess {
                        dismiss()
                    }
                }
            } message: {
                Text(redeemAlertMessage)
            }
            .alert("Revoke Testing Access?", isPresented: $showRevokeConfirmAlert) {
                Button("Revoke Access", role: .destructive) {
                    subscriptionManager.revokeDevAccess()
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will lock all AI features back to the standard trial limits and restore subscription plan options.")
            }
        }
    }

    // MARK: - Subviews

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(SomaColors.navy)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(SomaColors.navy.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(SomaColors.navy)

                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(SomaColors.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }

    private func planCard(plan: SubscriptionPlan) -> some View {
        let isSelected = selectedPlan == plan

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selectedPlan = plan
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isSelected ? SomaColors.navy : Color(uiColor: .systemGray4))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(plan.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(SomaColors.navy)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        if let badge = plan.badgeText {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2.5)
                                .background(
                                    Capsule()
                                        .fill(SomaColors.navy)
                                )
                        }
                    }

                    Text(plan.subDescription)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(SomaColors.subtext)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                Text(planPriceDisplay(for: plan))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(SomaColors.navy)
                    .lineLimit(1)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? SomaColors.navy : Color(uiColor: .systemGray5), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func planPriceDisplay(for plan: SubscriptionPlan) -> String {
        if let product = subscriptionManager.availableProducts.first(where: { $0.id == plan.rawValue }) {
            switch plan {
            case .yearly: return "\(product.displayPrice) / yr"
            case .monthly: return "\(product.displayPrice) / mo"
            case .weekly: return "\(product.displayPrice) / wk"
            }
        }
        return plan.priceDescription
    }

    // MARK: - Active Subscription Card

    private var activeSubscriptionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(SomaColors.emerald)

                VStack(alignment: .leading, spacing: 2) {
                    Text(subscriptionManager.activePlanName ?? "Soma Pro")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(SomaColors.navy)

                    Text("Active Subscription")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(SomaColors.subtext)
                }

                Spacer()

                Text("ACTIVE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.0)
                    .foregroundColor(SomaColors.emerald)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(SomaColors.emerald.opacity(0.12))
                    )
            }

            Divider()
                .background(Color(uiColor: .systemGray5))

            VStack(spacing: 12) {
                subscriptionDetailRow(
                    icon: "clock.arrow.circlepath",
                    title: "Duration / Plan",
                    value: subscriptionManager.activePlanDuration ?? "Unlimited Access"
                )

                if let expDate = subscriptionManager.subscriptionExpirationDate {
                    subscriptionDetailRow(
                        icon: "calendar.badge.clock",
                        title: "Current Period Ends",
                        value: expDate.formatted(date: .abbreviated, time: .omitted)
                    )
                } else if DevAccessManager.isDevAccessActive {
                    subscriptionDetailRow(
                        icon: "infinity",
                        title: "End Period",
                        value: "Unlimited Beta Pass"
                    )
                }
            }

            if DevAccessManager.isDevAccessActive {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showRevokeConfirmAlert = true
                } label: {
                    HStack(spacing: 6) {
                        Spacer()
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Revoke Testing Access")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                    }
                    .foregroundColor(.red.opacity(0.85))
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.08))
                    )
                }
                .padding(.top, 4)
            } else {
                Button {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Spacer()
                        Image(systemName: "gearshape")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Manage in App Store")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                    }
                    .foregroundColor(SomaColors.navy)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(SomaColors.navy.opacity(0.06))
                    )
                }
                .padding(.top, 4)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(SomaColors.emerald.opacity(0.35), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
        )
        .padding(.horizontal, 20)
    }

    private func subscriptionDetailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(SomaColors.navy.opacity(0.7))
                .frame(width: 20)

            Text(title)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(SomaColors.subtext)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(SomaColors.navy)
        }
    }

    // MARK: - Actions

    private func handlePurchaseTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Find matched StoreKit product if loaded
        if let product = subscriptionManager.availableProducts.first(where: { $0.id == selectedPlan.rawValue }) {
            Task {
                let success = await subscriptionManager.purchase(product)
                if success {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                }
            }
        } else {
            // Local fallback simulation if running in preview / before storekit loading
            Task {
                // In local testing, if StoreKit products are loading, attempt refresh
                await subscriptionManager.refreshProducts()
                if let product = subscriptionManager.availableProducts.first(where: { $0.id == selectedPlan.rawValue }) {
                    let success = await subscriptionManager.purchase(product)
                    if success {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    }
                }
            }
        }
    }

    private func handleRestoreTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            let restored = await subscriptionManager.restorePurchases()
            if restored {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                showRestoreSuccessAlert = true
            } else if subscriptionManager.lastErrorMessage != nil {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                showRestoreFailureAlert = true
            } else {
                showRestoreSuccessAlert = true
            }
        }
    }

    // MARK: - Dev Redeem Action (Temporary for Testing - Easy to Remove)

    private func handleRedeemCode() {
        let code = redeemCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        redeemCodeInput = ""
        guard !code.isEmpty else { return }

        let result = subscriptionManager.redeemCode(code)
        switch result {
        case .unlocked:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            isRedeemSuccess = true
            redeemAlertTitle = "Pro Access Unlocked"
            redeemAlertMessage = "Developer access granted! All Soma AI features are now unlocked for testing."
            showRedeemResultAlert = true

        case .revoked:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            isRedeemSuccess = false
            redeemAlertTitle = "Access Revoked"
            redeemAlertMessage = "Developer access has been revoked. Standard limits and paywall restored."
            showRedeemResultAlert = true

        case .invalid:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            isRedeemSuccess = false
            redeemAlertTitle = "Invalid Code"
            redeemAlertMessage = "The code you entered is invalid. Please try again."
            showRedeemResultAlert = true
        }
    }
}
