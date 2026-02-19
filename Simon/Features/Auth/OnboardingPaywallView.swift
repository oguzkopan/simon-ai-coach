//
//  OnboardingPaywallView.swift
//  Simon
//
//  Created on 2026-02-19.
//

import SwiftUI
import RevenueCat

struct OnboardingPaywallView: View {
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
            // Background with gradient
            LinearGradient(
                colors: [
                    theme.accentPrimary.opacity(0.12),
                    theme.accentPrimary.opacity(0.05),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)
                
                // Crown icon with glow effect
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    theme.accentPrimary.opacity(0.3),
                                    theme.accentPrimary.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [theme.accentPrimary, theme.accentPrimary.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 72, height: 72)
                            .shadow(color: theme.accentPrimary.opacity(0.4), radius: 16, y: 6)
                        
                        Image(systemName: "crown.fill")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                // Title
                VStack(spacing: 6) {
                    Text("Unlock Simon Pro")
                        .font(theme.font(28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Build systems that stick")
                        .font(theme.font(16))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                Spacer()
                    .frame(height: 32)
                
                // Features - compact horizontal layout
                HStack(spacing: 12) {
                    CompactFeature(icon: "infinity", title: "Unlimited\nMessages", color: .blue)
                    CompactFeature(icon: "square.and.arrow.up", title: "Publish\nCoaches", color: .purple)
                    CompactFeature(icon: "arrow.triangle.2.circlepath", title: "Advanced\nSystems", color: .orange)
                }
                .padding(.horizontal, 20)
                
                Spacer()
                    .frame(height: 32)
                
                // Pricing section
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(theme.accentPrimary)
                        Text("Loading plans...")
                            .font(theme.font(14))
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 180)
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.orange)
                        
                        Text(errorMessage)
                            .font(theme.font(14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        Button(action: {
                            Task {
                                await loadOfferings()
                            }
                        }) {
                            Text("Try Again")
                                .font(theme.font(16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 120, height: 44)
                                .background(theme.accentPrimary)
                                .cornerRadius(22)
                        }
                    }
                    .frame(height: 180)
                } else if let offerings = offerings,
                          let packages = offerings.current?.availablePackages,
                          !packages.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(packages, id: \.identifier) { package in
                            CompactProductCard(
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
                }
                
                Spacer()
                
                // Bottom buttons
                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await restorePurchases()
                        }
                    }) {
                        Text("Restore Purchases")
                            .font(theme.font(14))
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: onDismiss) {
                        Text("Maybe later")
                            .font(theme.font(15))
                            .foregroundColor(.secondary)
                    }
                    
                    // Privacy & Terms links
                    HStack(spacing: 4) {
                        Link("Privacy", destination: URL(string: "https://simon-7a833.web.app/privacy/")!)
                            .font(theme.font(11))
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(theme.font(11))
                            .foregroundColor(.secondary)
                        
                        Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            .font(theme.font(11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            AnalyticsManager.shared.logPaywallViewed()
            Task {
                await loadOfferings()
            }
        }
    }
    
    private func loadOfferings() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let loadedOfferings = try await Purchases.shared.offerings()
            offerings = loadedOfferings
            
            if offerings?.current?.availablePackages.isEmpty ?? true {
                errorMessage = "No subscription products are currently available. Please check back later."
            }
        } catch {
            let errorString = error.localizedDescription
            if errorString.contains("no App Store products registered") || errorString.contains("CONFIGURATION_ERROR") {
                errorMessage = "Subscription products are being set up. Please check back soon!"
            } else {
                errorMessage = "Failed to load products. Please try again."
            }
        }
        
        isLoading = false
    }
    
    private func purchase(_ package: Package) async {
        isPurchasing = true
        
        do {
            let result = try await Purchases.shared.purchase(package: package)
            
            if result.customerInfo.entitlements["Simon Pro"]?.isActive == true {
                await purchases.loadCustomerInfo()
                onPurchaseComplete(true, "🎉 Welcome to Pro! You now have unlimited messages.")
            } else {
                onPurchaseComplete(false, "Purchase completed but Pro status not activated. Please contact support.")
            }
        } catch let error as ErrorCode {
            switch error {
            case .purchaseCancelledError:
                break
            case .productAlreadyPurchasedError:
                onPurchaseComplete(false, "You already own this product. Try restoring purchases.")
            case .networkError:
                onPurchaseComplete(false, "Network error. Please check your connection and try again.")
            default:
                onPurchaseComplete(false, "Purchase failed: \(error.localizedDescription)")
            }
        } catch {
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
            onPurchaseComplete(false, "Failed to restore purchases. Please try again.")
        }
        
        isPurchasing = false
    }
}

// MARK: - Compact Feature Component

struct CompactFeature: View {
    let icon: String
    let title: String
    let color: Color
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(theme.font(12, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
        )
    }
}

// MARK: - Compact Product Card Component

struct CompactProductCard: View {
    let package: Package
    let isSelected: Bool
    let isPurchasing: Bool
    let onTap: () -> Void
    let allPackages: [Package]
    
    @EnvironmentObject private var theme: ThemeStore
    
    private var displayName: String {
        switch package.packageType {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .annual: return "Yearly"
        case .lifetime: return "Lifetime"
        default: return package.storeProduct.localizedTitle
        }
    }
    
    private var displayPrice: String {
        package.storeProduct.localizedPriceString
    }
    
    private var pricePerWeek: Double {
        let price = package.storeProduct.price as Decimal
        let priceDouble = (price as NSDecimalNumber).doubleValue
        
        switch package.packageType {
        case .weekly: return priceDouble
        case .monthly: return priceDouble / 4.0
        case .annual: return priceDouble / 52.0
        default: return priceDouble
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
        case .weekly: return "\(formattedPrice)/week"
        case .monthly: return "~\(formattedPrice)/week"
        case .annual: return "~\(formattedPrice)/week"
        case .lifetime: return "One-time"
        default: return package.storeProduct.localizedDescription
        }
    }
    
    private var isPopular: Bool {
        package.packageType == .annual
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 12) {
                    // Left side - Plan info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName)
                            .font(theme.font(18, weight: .bold))
                            .foregroundColor(isSelected ? .white : .primary)
                        
                        Text(displayDescription)
                            .font(theme.font(13))
                            .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
                    }
                    
                    Spacer()
                    
                    // Right side - Price and action
                    HStack(spacing: 8) {
                        if isPurchasing {
                            ProgressView()
                                .tint(isSelected ? .white : theme.accentPrimary)
                        } else {
                            Text(displayPrice)
                                .font(theme.font(22, weight: .bold))
                                .foregroundColor(isSelected ? .white : theme.accentPrimary)
                            
                            if let savings = savingsInfo {
                                Text(savings.description)
                                    .font(theme.font(10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(Color.green)
                                    )
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            isSelected
                                ? LinearGradient(
                                    colors: [theme.accentPrimary, theme.accentPrimary.opacity(0.85)],
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
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            isSelected
                                ? Color.clear
                                : (isPopular ? theme.accentPrimary.opacity(0.5) : Color(.systemGray5)),
                            lineWidth: isPopular && !isSelected ? 2 : 1
                        )
                )
                .shadow(
                    color: isSelected
                        ? theme.accentPrimary.opacity(0.3)
                        : Color.black.opacity(0.06),
                    radius: isSelected ? 12 : 8,
                    y: isSelected ? 6 : 3
                )
                
                // Most popular badge
                if isPopular && !isSelected {
                    Text("POPULAR")
                        .font(theme.font(9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(theme.accentPrimary)
                        )
                        .offset(x: -10, y: -8)
                }
            }
        }
        .disabled(isPurchasing)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    OnboardingPaywallView(
        onDismiss: {},
        onPurchaseComplete: { _, _ in }
    )
    .environmentObject(ThemeStore())
    .environmentObject(PurchasesService())
}
