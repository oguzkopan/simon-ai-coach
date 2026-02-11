//
//  PaywallView.swift
//  Simon
//
//  Created on 2026-01-19.
//

import SwiftUI
import RevenueCat

struct PaywallView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var purchases: PurchasesService
    
    let onDismiss: () -> Void
    let onPurchaseComplete: (Bool, String) -> Void
    
    @State private var offerings: Offerings?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isPurchasing = false
    @State private var selectedPackage: Package?
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    theme.accentPrimary.opacity(0.05),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            NavigationStack {
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [theme.accentPrimary, theme.accentPrimary.opacity(0.7)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "star.fill")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 20)
                            
                            Text("Upgrade to Pro")
                                .font(theme.font(32, weight: .bold))
                            
                            Text("Build systems that stick")
                                .font(theme.font(17))
                                .foregroundColor(.secondary)
                        }
                        
                        // Features
                        VStack(spacing: 20) {
                            FeatureRow(
                                icon: "infinity",
                                title: "Unlimited Messages",
                                description: "Get guidance whenever you need it",
                                color: .blue
                            )
                            
                            FeatureRow(
                                icon: "square.and.arrow.up",
                                title: "Publish & Share Coaches",
                                description: "Share your custom coaches with the community",
                                color: .purple
                            )
                            
                            FeatureRow(
                                icon: "arrow.triangle.2.circlepath",
                                title: "Turn Advice into Systems",
                                description: "Advanced system mode with schedules and metrics",
                                color: .orange
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // Product offerings
                        if isLoading {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Loading plans...")
                                    .font(theme.font(14))
                                    .foregroundColor(.secondary)
                            }
                            .frame(height: 200)
                        } else if let errorMessage = errorMessage {
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.orange)
                                
                                Text(errorMessage)
                                    .font(theme.font(15))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                                
                                Button(action: {
                                    Task {
                                        await loadOfferings()
                                    }
                                }) {
                                    Text("Retry")
                                        .font(theme.font(16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 120, height: 44)
                                        .background(theme.accentPrimary)
                                        .cornerRadius(22)
                                }
                            }
                            .padding(.vertical, 32)
                        } else if let offerings = offerings, let packages = offerings.current?.availablePackages, !packages.isEmpty {
                            VStack(spacing: 16) {
                                Text("Choose Your Plan")
                                    .font(theme.font(20, weight: .bold))
                                    .padding(.top, 8)
                                
                                VStack(spacing: 12) {
                                    ForEach(packages, id: \.identifier) { package in
                                        ProductCard(
                                            package: package,
                                            isSelected: selectedPackage?.identifier == package.identifier,
                                            isPurchasing: isPurchasing && selectedPackage?.identifier == package.identifier,
                                            onTap: {
                                                selectedPackage = package
                                                Task {
                                                    await purchase(package)
                                                }
                                            },
                                            allPackages: packages
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
                                
                                Button(action: {
                                    Task {
                                        await restorePurchases()
                                    }
                                }) {
                                    Text("Restore Purchases")
                                        .font(theme.font(15))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.top, 8)
                            }
                        } else {
                            VStack(spacing: 16) {
                                Button(action: {
                                    Task {
                                        await purchase(nil)
                                    }
                                }) {
                                    HStack {
                                        if isPurchasing {
                                            ProgressView()
                                                .tint(.white)
                                        } else {
                                            Text("Start Pro")
                                                .font(theme.font(18, weight: .semibold))
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(
                                        LinearGradient(
                                            colors: [theme.accentPrimary, theme.accentPrimary.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                                    .shadow(color: theme.accentPrimary.opacity(0.3), radius: 8, y: 4)
                                }
                                .disabled(isPurchasing)
                                
                                Button(action: onDismiss) {
                                    Text("Not now")
                                        .font(theme.font(16))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer()
                            .frame(height: 40)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: onDismiss) {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .onAppear {
                    AnalyticsManager.shared.logPaywallViewed()
                    Task {
                        await loadOfferings()
                    }
                }
            }
        }
    }
    
    private func loadOfferings() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Try to load offerings
            let loadedOfferings = try await Purchases.shared.offerings()
            offerings = loadedOfferings
            
            print("✅ Loaded offerings: \(offerings?.current?.availablePackages.count ?? 0) packages")
            
            // If no packages available, show a helpful message
            if offerings?.current?.availablePackages.isEmpty ?? true {
                print("⚠️ No products found in current configuration")
                errorMessage = "No subscription products are currently available. Please check back later."
            }
        } catch {
            print("❌ Failed to load offerings: \(error)")
            
            // Check if it's a configuration error (no products in dashboard)
            let errorString = error.localizedDescription
            if errorString.contains("no App Store products registered") || errorString.contains("CONFIGURATION_ERROR") {
                errorMessage = "Subscription products are being set up. Please check back soon!"
            } else {
                errorMessage = "Failed to load products. Please try again."
            }
        }
        
        isLoading = false
    }
    
    private func purchase(_ package: Package?) async {
        isPurchasing = true
        
        do {
            let result: PurchaseResultData
            
            if let package = package {
                result = try await Purchases.shared.purchase(package: package)
            } else {
                // Fallback: try to purchase the first available package
                guard let offerings = offerings,
                      let package = offerings.current?.availablePackages.first else {
                    onPurchaseComplete(false, "No products available")
                    isPurchasing = false
                    return
                }
                result = try await Purchases.shared.purchase(package: package)
            }
            
            if result.customerInfo.entitlements["Simon Pro"]?.isActive == true {
                // Purchase successful
                await purchases.loadCustomerInfo()
                onPurchaseComplete(true, "🎉 Welcome to Pro! You now have unlimited messages.")
            } else {
                onPurchaseComplete(false, "Purchase completed but Pro status not activated. Please contact support.")
            }
        } catch let error as ErrorCode {
            print("❌ Purchase failed: \(error)")
            
            // Handle specific RevenueCat errors
            switch error {
            case .purchaseCancelledError:
                // User cancelled - don't show error
                break
            case .productAlreadyPurchasedError:
                onPurchaseComplete(false, "You already own this product. Try restoring purchases.")
            case .networkError:
                onPurchaseComplete(false, "Network error. Please check your connection and try again.")
            default:
                onPurchaseComplete(false, "Purchase failed: \(error.localizedDescription)")
            }
        } catch {
            print("❌ Purchase failed: \(error)")
            onPurchaseComplete(false, "Purchase failed. Please try again.")
        }
        
        isPurchasing = false
    }
    
    private func restorePurchases() async {
        isPurchasing = true
        
        do {
            try await purchases.restorePurchases()
            
            if purchases.isPro {
                onPurchaseComplete(true, "✅ Purchases restored! You now have unlimited messages.")
            } else {
                onPurchaseComplete(false, "No purchases found to restore.")
            }
        } catch {
            print("❌ Restore failed: \(error)")
            onPurchaseComplete(false, "Failed to restore purchases. Please try again.")
        }
        
        isPurchasing = false
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(theme.font(16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(theme.font(14))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 2)
    }
}

struct ProductCard: View {
    let package: Package
    let isSelected: Bool
    let isPurchasing: Bool
    let onTap: () -> Void
    let allPackages: [Package]
    
    @EnvironmentObject private var theme: ThemeStore
    
    private var displayName: String {
        switch package.packageType {
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        case .annual:
            return "Yearly"
        case .lifetime:
            return "Lifetime"
        default:
            return package.storeProduct.localizedTitle
        }
    }
    
    private var displayPrice: String {
        package.storeProduct.localizedPriceString
    }
    
    private var pricePerWeek: Double {
        let price = package.storeProduct.price as Decimal
        let priceDouble = (price as NSDecimalNumber).doubleValue
        
        switch package.packageType {
        case .weekly:
            return priceDouble
        case .monthly:
            return priceDouble / 4.0
        case .annual:
            return priceDouble / 52.0
        default:
            return priceDouble
        }
    }
    
    private var weeklyPackagePrice: Double? {
        guard let weeklyPackage = allPackages.first(where: { $0.packageType == .weekly }) else {
            return nil
        }
        let price = weeklyPackage.storeProduct.price as Decimal
        return (price as NSDecimalNumber).doubleValue
    }
    
    private var savingsInfo: (percentage: Int, description: String)? {
        guard let weeklyPrice = weeklyPackagePrice,
              package.packageType != .weekly else {
            return nil
        }
        
        let currentPricePerWeek = pricePerWeek
        let savings = ((weeklyPrice - currentPricePerWeek) / weeklyPrice) * 100
        
        guard savings > 0 else { return nil }
        
        return (Int(savings), "Save \(Int(savings))%")
    }
    
    private var displayDescription: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = package.storeProduct.priceFormatter?.locale ?? Locale.current
        
        let pricePerWeekValue = pricePerWeek
        let formattedPrice = formatter.string(from: NSNumber(value: pricePerWeekValue)) ?? ""
        
        switch package.packageType {
        case .weekly:
            return "\(formattedPrice) per week"
        case .monthly:
            return "~\(formattedPrice) per week"
        case .annual:
            return "~\(formattedPrice) per week"
        case .lifetime:
            return "One-time payment"
        default:
            return package.storeProduct.localizedDescription
        }
    }
    
    private var isPopular: Bool {
        package.packageType == .annual
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    // Header with badges
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(displayName)
                                .font(theme.font(20, weight: .bold))
                                .foregroundColor(isSelected ? .white : .primary)
                            
                            Text(displayDescription)
                                .font(theme.font(14))
                                .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom, 16)
                    
                    // Price section
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        if isPurchasing {
                            ProgressView()
                                .tint(isSelected ? .white : theme.accentPrimary)
                        } else {
                            Text(displayPrice)
                                .font(theme.font(28, weight: .bold))
                                .foregroundColor(isSelected ? .white : theme.accentPrimary)
                        }
                        
                        Spacer()
                        
                        // Savings badge
                        if let savings = savingsInfo {
                            VStack(spacing: 2) {
                                Text(savings.description)
                                    .font(theme.font(12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.green)
                            )
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            isSelected
                                ? LinearGradient(
                                    colors: [theme.accentPrimary, theme.accentPrimary.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color(.systemBackground), Color(.systemBackground)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            isSelected
                                ? Color.clear
                                : (isPopular ? theme.accentPrimary : Color(.systemGray4)),
                            lineWidth: isPopular && !isSelected ? 2 : 1
                        )
                )
                .shadow(
                    color: isSelected
                        ? theme.accentPrimary.opacity(0.3)
                        : Color.black.opacity(0.05),
                    radius: isSelected ? 12 : 8,
                    y: isSelected ? 6 : 2
                )
                
                // Most popular badge
                if isPopular {
                    Text("MOST POPULAR")
                        .font(theme.font(10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(theme.accentPrimary)
                        )
                        .offset(x: -12, y: -8)
                }
            }
        }
        .disabled(isPurchasing)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
