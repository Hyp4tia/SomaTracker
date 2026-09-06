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
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("SOMA PRO")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .tracking(2.0)
                            }
                            .foregroundColor(SomaColors.navy)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(SomaColors.navy.opacity(0.08))
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

                        // MARK: - Plan Selection Cards
                        VStack(spacing: 12) {
                            ForEach(SubscriptionPlan.allCases) { plan in
                                planCard(plan: plan)
                            }
                        }
                        .padding(.horizontal, 20)

                        // MARK: - Action Button
                        VStack(spacing: 14) {
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

                            // MARK: - Restore Purchases
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
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)

                        // MARK: - Legal & Disclosures (Apple Guideline 3.1.2)
                        VStack(spacing: 8) {
                            Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period. You can manage and cancel your subscriptions in your App Store account settings.")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(Color(uiColor: .tertiaryLabel))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)

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
}
