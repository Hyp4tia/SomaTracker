//
//  SubscriptionManager.swift
//  SomaTracker
//
//  Production-ready StoreKit 2 & RevenueCat-compatible subscription manager.
//  Provides 3 free AI trial scans and manages Pro entitlements.
//

import Foundation
import StoreKit
import Observation

@Observable
final class SubscriptionManager: NSObject {
    static let shared = SubscriptionManager()

    // MARK: - Product IDs
    enum ProductID: String, CaseIterable {
        case weekly = "soma_pro_weekly"
        case monthly = "soma_pro_monthly"
        case yearly = "soma_pro_yearly"

        static var allRawValues: Set<String> {
            Set(allCases.map { $0.rawValue })
        }
    }

    // MARK: - Published State
    var isPro: Bool = false
    var availableProducts: [Product] = []
    var isPurchasing: Bool = false
    var isRestoring: Bool = false
    var lastErrorMessage: String? = nil

    /// Active subscription tier / plan name (e.g. "Annual Plan", "Developer Testing Pass")
    var activePlanName: String? = nil
    /// Billing duration/frequency (e.g. "1 Year", "Unlimited Access")
    var activePlanDuration: String? = nil
    /// Expiration or renewal date for StoreKit subscription
    var subscriptionExpirationDate: Date? = nil

    /// Free scans remaining for un-subscribed users (starts at 3)
    var remainingFreeScans: Int {
        didSet {
            UserDefaults.standard.set(remainingFreeScans, forKey: "soma_remaining_free_scans")
        }
    }

    /// User can use AI if they are Pro OR if they still have free trial scans
    var canUseAIFeatures: Bool {
        isPro || remainingFreeScans > 0
    }

    private var updatesTask: Task<Void, Never>? = nil

    private override init() {
        if UserDefaults.standard.object(forKey: "soma_remaining_free_scans") == nil {
            self.remainingFreeScans = 3
            UserDefaults.standard.set(3, forKey: "soma_remaining_free_scans")
        } else {
            self.remainingFreeScans = UserDefaults.standard.integer(forKey: "soma_remaining_free_scans")
        }

        // Initialize Pro status with dev access if active
        if DevAccessManager.isDevAccessActive {
            self.isPro = true
            self.activePlanName = "Developer Testing Pass"
            self.activePlanDuration = "Unlimited Access"
        }

        super.init()

        // Start listening to background transaction updates (renewals, cancellations, family sharing)
        startTransactionListener()

        Task {
            await refreshProducts()
            await checkCurrentEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Transaction Listener (StoreKit 2)

    private func startTransactionListener() {
        updatesTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                if let transaction = try? Self.checkVerified(result) {
                    await self?.updateProStatus(for: transaction)
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Product Fetching

    func refreshProducts() async {
        do {
            let products = try await Product.products(for: ProductID.allRawValues)
            await MainActor.run {
                // Sort: Yearly first (Best Value), Monthly, then Weekly
                self.availableProducts = products.sorted { p1, p2 in
                    if p1.id == ProductID.yearly.rawValue { return true }
                    if p2.id == ProductID.yearly.rawValue { return false }
                    if p1.id == ProductID.monthly.rawValue { return true }
                    return false
                }
            }
        } catch {
            print("[SubscriptionManager] Failed to fetch products: \(error.localizedDescription)")
        }
    }

    // MARK: - Check Current Active Subscriptions

    func checkCurrentEntitlements() async {
        var hasActivePro = false
        var planName: String? = nil
        var planDuration: String? = nil
        var expDate: Date? = nil

        for await result in Transaction.currentEntitlements {
            if let transaction = try? Self.checkVerified(result) {
                if ProductID.allRawValues.contains(transaction.productID) {
                    if transaction.revocationDate == nil {
                        hasActivePro = true
                        expDate = transaction.expirationDate
                        switch transaction.productID {
                        case ProductID.yearly.rawValue:
                            planName = "Annual Plan"
                            planDuration = "1 Year"
                        case ProductID.monthly.rawValue:
                            planName = "Monthly Plan"
                            planDuration = "1 Month"
                        case ProductID.weekly.rawValue:
                            planName = "Weekly Plan"
                            planDuration = "1 Week"
                        default:
                            planName = "Soma Pro"
                            planDuration = "Auto-Renewable"
                        }
                        break
                    }
                }
            }
        }

        let isDev = DevAccessManager.isDevAccessActive
        let active = hasActivePro || isDev

        if isDev && !hasActivePro {
            planName = "Developer Testing Pass"
            planDuration = "Unlimited Access"
            expDate = nil
        }

        await MainActor.run {
            self.isPro = active
            self.activePlanName = planName
            self.activePlanDuration = planDuration
            self.subscriptionExpirationDate = expDate
        }
    }

    // MARK: - Purchasing

    @MainActor
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        lastErrorMessage = nil

        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try Self.checkVerified(verification)
                await updateProStatus(for: transaction)
                await transaction.finish()
                return true

            case .userCancelled:
                return false

            case .pending:
                lastErrorMessage = "Purchase is pending approval (e.g. Ask to Buy)."
                return false

            @unknown default:
                return false
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Restore Purchases (App Store Requirement)

    @MainActor
    func restorePurchases() async -> Bool {
        isRestoring = true
        lastErrorMessage = nil

        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await checkCurrentEntitlements()
            return isPro
        } catch {
            if DevAccessManager.isDevAccessActive {
                self.isPro = true
                return true
            }
            lastErrorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Free Tier Scan Consumption

    /// Consumes 1 free scan if the user is not Pro. Returns true if scan was permitted.
    @discardableResult
    func consumeFreeScanIfFreeUser() -> Bool {
        if isPro {
            return true
        }

        if remainingFreeScans > 0 {
            remainingFreeScans -= 1
            return true
        }

        return false
    }

    // MARK: - Helpers
 
    nonisolated static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    private func updateProStatus(for transaction: Transaction) async {
        let isRevoked = transaction.revocationDate != nil
        let isExpired: Bool
        if let expiration = transaction.expirationDate {
            isExpired = expiration < Date()
        } else {
            isExpired = false
        }

        let hasStoreKitPro = !isRevoked && !isExpired && ProductID.allRawValues.contains(transaction.productID)
        let isDev = DevAccessManager.isDevAccessActive
        let active = hasStoreKitPro || isDev

        var planName: String? = nil
        var planDuration: String? = nil
        var expDate: Date? = nil

        if hasStoreKitPro {
            expDate = transaction.expirationDate
            switch transaction.productID {
            case ProductID.yearly.rawValue:
                planName = "Annual Plan"
                planDuration = "1 Year"
            case ProductID.monthly.rawValue:
                planName = "Monthly Plan"
                planDuration = "1 Month"
            case ProductID.weekly.rawValue:
                planName = "Weekly Plan"
                planDuration = "1 Week"
            default:
                planName = "Soma Pro"
                planDuration = "Auto-Renewable"
            }
        } else if isDev {
            planName = "Developer Testing Pass"
            planDuration = "Unlimited Access"
            expDate = nil
        }

        await MainActor.run {
            self.isPro = active
            self.activePlanName = planName
            self.activePlanDuration = planDuration
            self.subscriptionExpirationDate = expDate
        }
    }

    // MARK: - Dev Access (Temporary for Testing - Easy to Remove)

    @MainActor
    func redeemCode(_ code: String) -> DevRedeemResult {
        let result = DevAccessManager.redeem(code: code)
        switch result {
        case .unlocked:
            self.isPro = true
            self.activePlanName = "Developer Testing Pass"
            self.activePlanDuration = "Unlimited Access"
            self.subscriptionExpirationDate = nil
        case .revoked:
            self.isPro = false
            self.activePlanName = nil
            self.activePlanDuration = nil
            self.subscriptionExpirationDate = nil
            Task {
                await checkCurrentEntitlements()
            }
        case .invalid:
            break
        }
        return result
    }

    @MainActor
    func revokeDevAccess() {
        _ = redeemCode("revoke")
    }
}
