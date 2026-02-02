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
    
    // Progress documents (plans, check-ins)
    @Published var activePlans: [Plan] = []
    @Published var recentCheckins: [Checkin] = []
    @Published var isLoadingProgress: Bool = false
    
    private let apiClient: SimonAPI
    private var loadTask: Task<Void, Never>?
    private var hasLoadedData = false // Track if initial load is complete
    private var hasLoadedProgress = false
    
    var onNavigateToChat: ((String, String) -> Void)? // (sessionId, coachName)
    var onNavigateToMoment: (() -> Void)?
    var onNavigateToSettings: (() -> Void)?
    var onShowAllSessions: (() -> Void)?
    
    init(apiClient: SimonAPI) {
        self.apiClient = apiClient
    }
    
    func loadData() async {
        // Skip if already loaded
        guard !hasLoadedData else {
            print("📚 Library data already loaded, skipping...")
            return
        }
        
        // Cancel any existing load task
        loadTask?.cancel()
        
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        loadTask = Task {
            // Load data concurrently
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadRecentSessions() }
                group.addTask { await self.loadPinnedSystems() }
                group.addTask { await self.loadProgressDocuments() }
            }
            
            // Organize sessions by time
            if !Task.isCancelled {
                organizeSessions()
                hasLoadedData = true
            }
            
            isLoading = false
        }
        
        await loadTask?.value
    }
    
    func refresh() async {
        // Force reload by resetting the flag
        hasLoadedData = false
        hasLoadedProgress = false
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
    
    private func loadProgressDocuments() async {
        guard !hasLoadedProgress else {
            print("📊 Progress data already loaded, skipping...")
            return
        }
        
        isLoadingProgress = true
        
        do {
            // Load active plans
            let plans = try await apiClient.listPlans(status: "active", limit: 5)
            activePlans = plans
            
            // TODO: Add check-ins API endpoint
            recentCheckins = []
            
            print("✅ Loaded progress: plans=\(activePlans.count), checkins=\(recentCheckins.count)")
            
            hasLoadedProgress = true
            isLoadingProgress = false
        } catch {
            print("❌ Failed to load progress documents: \(error)")
            hasLoadedProgress = true
            isLoadingProgress = false
        }
    }
    
    func continueSession(_ session: Session) {
        print("🟢 LibraryViewModel.continueSession - sessionID: \(session.id), coachName: \(session.coachName ?? "Coach")")
        onNavigateToChat?(session.id, session.coachName ?? "Coach")
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
    
    deinit {
        loadTask?.cancel()
    }
}
