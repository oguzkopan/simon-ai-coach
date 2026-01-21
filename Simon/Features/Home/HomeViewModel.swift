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
    private var loadTask: Task<Void, Never>?
    
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
    
    deinit {
        // Cancel ongoing task when view model is deallocated
        loadTask?.cancel()
    }
    
    func loadCoaches() async {
        // Cancel any existing load task
        loadTask?.cancel()
        
        guard networkMonitor.isConnected else {
            errorMessage = "No internet connection"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        loadTask = Task {
            do {
                let tag = selectedCategory == "All" || selectedCategory == nil ? nil : selectedCategory?.lowercased()
                let fetchedCoaches = try await apiClient.listCoaches(tag: tag, featured: nil)
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                coaches = fetchedCoaches
                
                // Haptic feedback on success
                HapticManager.shared.light()
            } catch let error as APIError {
                guard !Task.isCancelled else { return }
                handleAPIError(error)
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
                HapticManager.shared.error()
            }
            
            isLoading = false
        }
        
        await loadTask?.value
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
