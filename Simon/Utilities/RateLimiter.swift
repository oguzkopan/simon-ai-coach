//
//  RateLimiter.swift
//  Simon
//
//  Created on Day 19-21: Polish + Edge Cases
//

import Foundation
import Combine

@MainActor
final class RateLimiter: ObservableObject {
    @Published private(set) var isRateLimited: Bool = false
    @Published private(set) var cooldownRemaining: Int = 0
    
    private var cooldownTimer: Timer?
    private var lastRequestTime: Date?
    private let minimumInterval: TimeInterval
    
    init(minimumInterval: TimeInterval = 1.0) {
        self.minimumInterval = minimumInterval
    }
    
    func canMakeRequest() -> Bool {
        guard let lastTime = lastRequestTime else {
            return true
        }
        
        let elapsed = Date().timeIntervalSince(lastTime)
        return elapsed >= minimumInterval
    }
    
    func recordRequest() {
        lastRequestTime = Date()
    }
    
    func startCooldown(seconds: Int) {
        isRateLimited = true
        cooldownRemaining = seconds
        
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.cooldownRemaining -= 1
                
                if self.cooldownRemaining <= 0 {
                    self.endCooldown()
                }
            }
        }
    }
    
    func endCooldown() {
        isRateLimited = false
        cooldownRemaining = 0
        cooldownTimer?.invalidate()
        cooldownTimer = nil
    }
    
    deinit {
        cooldownTimer?.invalidate()
    }
}
