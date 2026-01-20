import Foundation
import SwiftUI
import Combine

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var recentSessions: [Session] = []
    @Published var thisWeekSessions: [Session] = []
    @Published var archivedSessions: [Session] = []
    @Published var pinnedSystems: [System] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedSystem: System?
    
    private let apiClient: SimonAPI
    var onNavigateToChat: ((String) -> Void)?
    var onNavigateToMoment: (() -> Void)?
    var onNavigateToSettings: (() -> Void)?
    var onShowAllSessions: (() -> Void)?
    
    init(apiClient: SimonAPI) {
        self.apiClient = apiClient
    }
    
    func loadData() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Load data concurrently
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadRecentSessions() }
            group.addTask { await self.loadPinnedSystems() }
        }
        
        // Organize sessions by time
        organizeSessions()
        
        isLoading = false
    }
    
    func refresh() async {
        await loadData()
    }
    
    private func loadRecentSessions() async {
        do {
            // Load recent sessions, sorted by most recently updated
            let sessions = try await apiClient.listSessions(limit: 20)
            recentSessions = sessions.sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            print("Failed to load sessions: \(error)")
            if recentSessions.isEmpty {
                errorMessage = "Failed to load sessions. Pull to refresh to try again."
            }
        }
    }
    
    private func loadPinnedSystems() async {
        do {
            pinnedSystems = try await apiClient.listSystems()
        } catch {
            print("Failed to load systems: \(error)")
            if pinnedSystems.isEmpty && recentSessions.isEmpty {
                errorMessage = "Failed to load library. Pull to refresh to try again."
            }
        }
    }
    
    private func organizeSessions() {
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        
        // This week: sessions from last 7 days (excluding the very latest which is featured)
        thisWeekSessions = recentSessions
            .dropFirst() // Skip the latest one (it's featured)
            .filter { $0.updatedAt >= weekAgo }
        
        // Archive: sessions older than 7 days
        archivedSessions = recentSessions
            .filter { $0.updatedAt < weekAgo }
    }
    
    func continueSession(_ session: Session) {
        onNavigateToChat?(session.id)
    }
    
    func viewSystem(_ system: System) {
        selectedSystem = system
    }
    
    func startNewMoment() {
        onNavigateToMoment?()
    }
    
    func showSettings() {
        onNavigateToSettings?()
    }
    
    func showAllSessions() {
        onShowAllSessions?()
    }
}
