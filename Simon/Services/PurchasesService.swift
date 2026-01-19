//
//  PurchasesService.swift
//  Simon
//
//  Created on 2026-01-20.
//

import Foundation
import Combine
import RevenueCat

@MainActor
final class PurchasesService: ObservableObject {
    @Published private(set) var isPro: Bool = false
    @Published private(set) var customerInfo: CustomerInfo?
    
    init() {
        // Listen to purchase updates
        Task {
            await loadCustomerInfo()
        }
    }
    
    func loadCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            self.customerInfo = info
            self.isPro = info.entitlements["pro"]?.isActive == true
        } catch {
            print("Failed to load customer info: \(error)")
        }
    }
    
    func restorePurchases() async throws {
        let info = try await Purchases.shared.restorePurchases()
        self.customerInfo = info
        self.isPro = info.entitlements["pro"]?.isActive == true
    }
}
