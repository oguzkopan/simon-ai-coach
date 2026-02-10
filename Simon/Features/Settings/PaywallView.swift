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
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer()
                            .frame(height: 20)
                        
                        VStack(spacing: 16) {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(theme.accentPrimary)
                            
                            Text("Upgrade to Pro")
                                .font(theme.font(28, weight: .bold))
                            
                            Text("Build systems that stick")
                                .font(theme.font(17))
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            FeatureRow(
                                icon: "infinity",
                                title: "Unlimited Messages",
                                description: "Get guidance whenever you need it"
                            )
                            
                            FeatureRow(
                                icon: "square.and.arrow.up",
                                title: "Publish & Share Coaches",
                                description: "Share your custom coaches with the community"
                            )
                            
                            FeatureRow(
                                icon: "arrow.triangle.2.circlepath",
                                title: "Turn Advice into Systems",
                                description: "Advanced system mode with schedules and metrics"
                            )
                        }
                        .padding(.horizontal, 16)
                        
                        Spacer()
                            .frame(height: 20)
                        
                        // Product offerings
                        if isLoading {
                            ProgressView()
                                .padding()
                        } else if let errorMessage = errorMessage {
                            VStack(spacing: 12) {
                                Text(errorMessage)
                                    .font(theme.font(14))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Button("Retry") {
                                    Task {
                                        await loadOfferings()
                                    }
                                }
                                .font(theme.font(15, weight: .semibold))
                                .foregroundColor(theme.accentPrimary)
                            }
                            .padding()
                        } else if let offerings = offerings, let packages = offerings.current?.availablePackages, !packages.isEmpty {
                            VStack(spacing: 12) {
                                ForEach(packages, id: \.identifier) { package in
                                    ProductCard(
                                        package: package,
                                        isSelected: selectedPackage?.identifier == package.identifier,
                                        isPurchasing: isPurchasing && selectedPackage?.identifier == package.identifier
                                    ) {
                                        selectedPackage = package
                                        Task {
                                            await purchase(package)
                                        }
                                    }
                                }
                                
                                Button("Restore Purchases") {
                                    Task {
                                        await restorePurchases()
                                    }
                                }
                                .font(theme.font(15))
                                .foregroundColor(theme.accentPrimary)
                                .padding(.top, 8)
                            }
                            .padding(.horizontal, 16)
                        } else {
                            VStack(spacing: 12) {
                                Button(action: {
                                    Task {
                                        await purchase(nil)
                                    }
                                }) {
                                    Text("Start Pro")
                                        .font(theme.font(17, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 52)
                                }
                                .background(theme.accentPrimary)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .disabled(isPurchasing)
                                
                                Button("Not now") {
                                    onDismiss()
                                }
                                .font(theme.font(15))
                                .foregroundColor(theme.accentPrimary)
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        Spacer()
                            .frame(height: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
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
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(theme.accentPrimary)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.font(15, weight: .semibold))
                
                Text(description)
                    .font(theme.font(13))
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ProductCard: View {
    let package: Package
    let isSelected: Bool
    let isPurchasing: Bool
    let onTap: () -> Void
    
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
            return priceDouble / 4.0 // ~4 weeks per month
        case .annual:
            return priceDouble / 52.0 // 52 weeks per year
        default:
            return priceDouble
        }
    }
    
    private var savingsInfo: (percentage: Int, description: String)? {
        // Base price is weekly at $3.99
        let weeklyPrice = 3.99
        let currentPricePerWeek = pricePerWeek
        
        switch package.packageType {
        case .monthly:
            // Monthly: $9.99 / 4 weeks = $2.50/week vs $3.99/week
            let savings = ((weeklyPrice - currentPricePerWeek) / weeklyPrice) * 100
            return (Int(savings), "Save \(Int(savings))%")
        case .annual:
            // Yearly: $79.99 / 52 weeks = $1.54/week vs $3.99/week
            let savings = ((weeklyPrice - currentPricePerWeek) / weeklyPrice) * 100
            return (Int(savings), "Save \(Int(savings))%")
        default:
            return nil
        }
    }
    
    private var displayDescription: String {
        switch package.packageType {
        case .weekly:
            return "$3.99 per week"
        case .monthly:
            return "~$2.50 per week"
        case .annual:
            return "~$1.54 per week"
        case .lifetime:
            return "One-time payment"
        default:
            return package.storeProduct.localizedDescription
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(displayName)
                                .font(theme.font(17, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            // Savings badge
                            if let savings = savingsInfo {
                                Text(savings.description)
                                    .font(theme.font(11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green)
                                    .cornerRadius(6)
                            }
                            
                            // Most popular badge for yearly
                            if package.packageType == .annual {
                                Text("MOST POPULAR")
                                    .font(theme.font(9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(theme.accentPrimary)
                                    .cornerRadius(4)
                            }
                        }
                        
                        Text(displayDescription)
                            .font(theme.font(13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isPurchasing {
                        ProgressView()
                    } else {
                        Text(displayPrice)
                            .font(theme.font(20, weight: .bold))
                            .foregroundColor(theme.accentPrimary)
                    }
                }
                .padding(16)
            }
            .background(isSelected ? theme.accentPrimary.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? theme.accentPrimary : Color.clear, lineWidth: 2)
            )
        }
        .disabled(isPurchasing)
    }
}
