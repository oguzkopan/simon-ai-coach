import Foundation
import SwiftUI
import Combine

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var recentSessions: [Session] = []
    @Published var savedCoaches: [Coach] = []
    @Published var pinnedSystems: [System] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedSystem: System?
    
    private let apiClient: SimonAPI
    
    init(apiClient: SimonAPI) {
        self.apiClient = apiClient
    }
    
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        await loadRecentSessions()
        await loadSavedCoaches()
        await loadPinnedSystems()
        
        isLoading = false
    }
    
    func refresh() async {
        await loadData()
    }
    
    private func loadRecentSessions() async {
        do {
            recentSessions = try await apiClient.listSessions(limit: 10)
        } catch {
            print("Failed to load sessions: \(error)")
        }
    }
    
    private func loadSavedCoaches() async {
        // TODO: Implement saved coaches endpoint
        // For now, load all coaches (will be filtered by saved status)
        savedCoaches = []
    }
    
    private func loadPinnedSystems() async {
        do {
            pinnedSystems = try await apiClient.listSystems()
        } catch {
            print("Failed to load systems: \(error)")
        }
    }
    
    func continueSession(_ session: Session) {
        // Navigate to chat with session
        print("Continue session: \(session.id)")
    }
    
    func startCoach(_ coach: Coach) {
        // Navigate to chat with coach
        print("Start coach: \(coach.id)")
    }
    
    func viewSystem(_ system: System) {
        selectedSystem = system
    }
    
    func showBrowse() {
        // Navigate to browse tab
        print("Show browse")
    }
}
