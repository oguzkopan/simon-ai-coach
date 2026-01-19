import Foundation
import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var coaches: [Coach] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedCategory: String?
    @Published var searchText = ""
    @Published var showSearch = false
    @Published var showPaywall = false
    @Published var toast: ToastMessage?
    @Published var isOffline = false
    
    let categories = ["All", "Focus", "Planning", "Creativity", "Decision", "Health", "Confidence"]
    
    private let apiClient: SimonAPI
    private let networkMonitor = NetworkMonitor.shared
    private let errorHandler = ErrorHandler()
    private var cancellables = Set<AnyCancellable>()
    
    init(apiClient: SimonAPI) {
        self.apiClient = apiClient
        
        // Monitor network status
        networkMonitor.$isConnected
            .sink { [weak self] isConnected in
                self?.isOffline = !isConnected
                if !isConnected {
                    self?.errorMessage = "No internet connection"
                }
            }
            .store(in: &cancellables)
    }
    
    func loadCoaches() async {
        guard networkMonitor.isConnected else {
            errorMessage = "No internet connection"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let tag = selectedCategory == "All" || selectedCategory == nil ? nil : selectedCategory?.lowercased()
            coaches = try await apiClient.listCoaches(tag: tag, featured: nil)
            
            // Haptic feedback on success
            HapticManager.shared.light()
        } catch let error as APIError {
            handleAPIError(error)
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.error()
        }
        
        isLoading = false
    }
    
    func selectCategory(_ category: String) {
        selectedCategory = category
        HapticManager.shared.selection()
        
        Task {
            await loadCoaches()
        }
    }
    
    func startCoach(_ coach: Coach) {
        HapticManager.shared.buttonTap()
        // Navigate to chat (to be implemented)
        print("Starting coach: \(coach.title)")
    }
    
    private func handleAPIError(_ error: APIError) {
        switch error {
        case .proRequired:
            showPaywall = true
            toast = ToastMessage(type: .info, message: "This feature requires Simon Pro")
        case .httpError(429):
            errorMessage = "Too many requests. Please wait a moment."
        case .httpError(401):
            errorMessage = "Session expired. Please sign in again."
        case .httpError(let code) where code >= 500:
            errorMessage = "Server error. Please try again later."
        default:
            errorMessage = error.localizedDescription
        }
        
        HapticManager.shared.error()
    }
}
