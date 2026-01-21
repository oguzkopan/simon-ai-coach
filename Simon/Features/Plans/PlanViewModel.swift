import Foundation
import SwiftUI
import Combine

@MainActor
class PlanViewModel: ObservableObject {
    @Published var plans: [Plan] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiClient: SimonAPIClient
    
    init(apiClient: SimonAPIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - Load Plans
    
    func loadPlans() async {
        isLoading = true
        errorMessage = nil
        
        do {
            plans = try await apiClient.listPlans()
        } catch {
            errorMessage = "Failed to load plans: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Toggle Action Completion
    
    func toggleActionCompletion(planId: String, actionId: String) async {
        guard let planIndex = plans.firstIndex(where: { $0.id == planId }) else {
            return
        }
        
        var plan = plans[planIndex]
        guard let actionIndex = plan.nextActions.firstIndex(where: { $0.id == actionId }) else {
            return
        }
        
        // Toggle status
        let newStatus: ActionStatus = plan.nextActions[actionIndex].status == .completed ? .pending : .completed
        plan.nextActions[actionIndex].status = newStatus
        plan.nextActions[actionIndex].completedAt = newStatus == .completed ? Date() : nil
        
        // Update locally first for immediate UI feedback
        plans[planIndex] = plan
        
        // Update on server
        do {
            try await apiClient.updatePlan(
                id: planId,
                updates: ["next_actions": plan.nextActions.map { action in
                    [
                        "id": action.id,
                        "title": action.title,
                        "duration_min": action.durationMin as Any,
                        "energy": action.energy?.rawValue as Any,
                        "when": action.when as Any,
                        "status": action.status.rawValue,
                        "completed_at": action.completedAt?.ISO8601Format() as Any
                    ]
                }]
            )
        } catch {
            // Revert on error
            plan.nextActions[actionIndex].status = newStatus == .completed ? .pending : .completed
            plan.nextActions[actionIndex].completedAt = nil
            plans[planIndex] = plan
            errorMessage = "Failed to update action: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Toggle Milestone Status
    
    func toggleMilestoneStatus(planId: String, milestoneId: String) async {
        guard let planIndex = plans.firstIndex(where: { $0.id == planId }) else {
            return
        }
        
        var plan = plans[planIndex]
        guard let milestoneIndex = plan.milestones.firstIndex(where: { $0.id == milestoneId }) else {
            return
        }
        
        // Cycle through statuses: pending -> in_progress -> completed -> pending
        let currentStatus = plan.milestones[milestoneIndex].status
        let newStatus: MilestoneStatus = {
            switch currentStatus {
            case .pending: return .inProgress
            case .inProgress: return .completed
            case .completed: return .pending
            }
        }()
        
        plan.milestones[milestoneIndex].status = newStatus
        
        // Update locally first
        plans[planIndex] = plan
        
        // Update on server
        do {
            try await apiClient.updatePlan(
                id: planId,
                updates: ["milestones": plan.milestones.map { milestone in
                    [
                        "id": milestone.id,
                        "title": milestone.title,
                        "description": milestone.description as Any,
                        "due_date": milestone.dueDate?.ISO8601Format() as Any,
                        "status": milestone.status.rawValue
                    ]
                }]
            )
        } catch {
            // Revert on error
            plan.milestones[milestoneIndex].status = currentStatus
            plans[planIndex] = plan
            errorMessage = "Failed to update milestone: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Archive Plan
    
    func archivePlan(id: String) async {
        guard let planIndex = plans.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        do {
            try await apiClient.updatePlan(id: id, updates: ["status": "archived"])
            plans.remove(at: planIndex)
        } catch {
            errorMessage = "Failed to archive plan: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Complete Plan
    
    func completePlan(id: String) async {
        guard let planIndex = plans.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        do {
            try await apiClient.updatePlan(id: id, updates: ["status": "completed"])
            plans[planIndex].status = .completed
        } catch {
            errorMessage = "Failed to complete plan: \(error.localizedDescription)"
        }
    }
}

// MARK: - API Client Extension

extension SimonAPIClient {
    func listPlans() async throws -> [Plan] {
        let url = baseURL.appendingPathComponent("/v1/plans")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let token = try await AuthenticationManager.shared.idToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Plan].self, from: data)
    }
    
    func updatePlan(id: String, updates: [String: Any]) async throws {
        let url = baseURL.appendingPathComponent("/v1/plans/\(id)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let token = try await AuthenticationManager.shared.idToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body = ["updates": updates]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
}
