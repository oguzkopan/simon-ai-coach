import Foundation
import SwiftUI
import Combine

// MARK: - Single Plan View Model (for viewing/editing one plan)

@MainActor
class SinglePlanViewModel: ObservableObject {
    @Published var plan: Plan?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showDeleteConfirmation = false
    
    private let apiClient: SimonAPI
    private let planId: String
    
    init(apiClient: SimonAPI, planId: String) {
        self.apiClient = apiClient
        self.planId = planId
    }
    
    func loadPlan() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Get all plans and find the one we need
            let plans = try await apiClient.listPlans(status: nil, limit: 100)
            plan = plans.first { $0.id == planId }
        } catch {
            errorMessage = "Failed to load plan: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func updateTitle(_ newTitle: String) async {
        guard !newTitle.isEmpty else { return }
        
        do {
            let updated = try await apiClient.updatePlan(planId: planId, updates: ["title": newTitle])
            plan = updated
        } catch {
            errorMessage = "Failed to update title: \(error.localizedDescription)"
        }
    }
    
    func updateObjective(_ newObjective: String) async {
        guard !newObjective.isEmpty else { return }
        
        do {
            let updated = try await apiClient.updatePlan(planId: planId, updates: ["objective": newObjective])
            plan = updated
        } catch {
            errorMessage = "Failed to update objective: \(error.localizedDescription)"
        }
    }
    
    func toggleMilestoneStatus(milestoneId: String) async {
        guard var currentPlan = plan,
              let milestoneIndex = currentPlan.milestones.firstIndex(where: { $0.id == milestoneId }) else {
            return
        }
        
        let currentStatus = currentPlan.milestones[milestoneIndex].status
        let newStatus: MilestoneStatus = {
            switch currentStatus {
            case .pending: return .inProgress
            case .inProgress: return .completed
            case .completed: return .pending
            }
        }()
        
        currentPlan.milestones[milestoneIndex].status = newStatus
        plan = currentPlan
        
        do {
            let updated = try await apiClient.updatePlan(
                planId: planId,
                updates: ["milestones": currentPlan.milestones.map { milestone -> [String: Any] in
                    var dict: [String: Any] = [
                        "id": milestone.id,
                        "title": milestone.title,
                        "status": milestone.status.rawValue
                    ]
                    if let description = milestone.description {
                        dict["description"] = description
                    }
                    if let dueDate = milestone.dueDate {
                        dict["due_date"] = dueDate.ISO8601Format()
                    }
                    return dict
                }]
            )
            plan = updated
        } catch {
            currentPlan.milestones[milestoneIndex].status = currentStatus
            plan = currentPlan
            errorMessage = "Failed to update milestone: \(error.localizedDescription)"
        }
    }
    
    func deleteMilestone(milestoneId: String) async {
        guard var currentPlan = plan else { return }
        
        let originalMilestones = currentPlan.milestones
        currentPlan.milestones.removeAll { $0.id == milestoneId }
        plan = currentPlan
        
        do {
            let updated = try await apiClient.updatePlan(
                planId: planId,
                updates: ["milestones": currentPlan.milestones.map { milestone -> [String: Any] in
                    var dict: [String: Any] = [
                        "id": milestone.id,
                        "title": milestone.title,
                        "status": milestone.status.rawValue
                    ]
                    if let description = milestone.description {
                        dict["description"] = description
                    }
                    if let dueDate = milestone.dueDate {
                        dict["due_date"] = dueDate.ISO8601Format()
                    }
                    return dict
                }]
            )
            plan = updated
        } catch {
            currentPlan.milestones = originalMilestones
            plan = currentPlan
            errorMessage = "Failed to delete milestone: \(error.localizedDescription)"
        }
    }
    
    func toggleActionCompletion(actionId: String) async {
        guard var currentPlan = plan,
              let actionIndex = currentPlan.nextActions.firstIndex(where: { $0.id == actionId }) else {
            return
        }
        
        let newStatus: ActionStatus = currentPlan.nextActions[actionIndex].status == .completed ? .pending : .completed
        currentPlan.nextActions[actionIndex].status = newStatus
        currentPlan.nextActions[actionIndex].completedAt = newStatus == .completed ? Date() : nil
        plan = currentPlan
        
        do {
            let updated = try await apiClient.updatePlan(
                planId: planId,
                updates: ["next_actions": currentPlan.nextActions.map { action -> [String: Any] in
                    var dict: [String: Any] = [
                        "id": action.id,
                        "title": action.title,
                        "status": action.status.rawValue
                    ]
                    if let duration = action.durationMin {
                        dict["duration_min"] = duration
                    }
                    if let energy = action.energy {
                        dict["energy"] = energy.rawValue
                    }
                    if let when = action.when {
                        var whenDict: [String: Any] = ["kind": when.kind.rawValue]
                        if let startISO = when.startISO {
                            whenDict["start_iso"] = startISO.ISO8601Format()
                        }
                        if let endISO = when.endISO {
                            whenDict["end_iso"] = endISO.ISO8601Format()
                        }
                        dict["when"] = whenDict
                    }
                    if let completedAt = action.completedAt {
                        dict["completed_at"] = completedAt.ISO8601Format()
                    }
                    return dict
                }]
            )
            plan = updated
        } catch {
            currentPlan.nextActions[actionIndex].status = newStatus == .completed ? .pending : .completed
            currentPlan.nextActions[actionIndex].completedAt = nil
            plan = currentPlan
            errorMessage = "Failed to update action: \(error.localizedDescription)"
        }
    }
    
    func deleteAction(actionId: String) async {
        guard var currentPlan = plan else { return }
        
        let originalActions = currentPlan.nextActions
        currentPlan.nextActions.removeAll { $0.id == actionId }
        plan = currentPlan
        
        do {
            let updated = try await apiClient.updatePlan(
                planId: planId,
                updates: ["next_actions": currentPlan.nextActions.map { action -> [String: Any] in
                    var dict: [String: Any] = [
                        "id": action.id,
                        "title": action.title,
                        "status": action.status.rawValue
                    ]
                    if let duration = action.durationMin {
                        dict["duration_min"] = duration
                    }
                    if let energy = action.energy {
                        dict["energy"] = energy.rawValue
                    }
                    if let when = action.when {
                        var whenDict: [String: Any] = ["kind": when.kind.rawValue]
                        if let startISO = when.startISO {
                            whenDict["start_iso"] = startISO.ISO8601Format()
                        }
                        if let endISO = when.endISO {
                            whenDict["end_iso"] = endISO.ISO8601Format()
                        }
                        dict["when"] = whenDict
                    }
                    if let completedAt = action.completedAt {
                        dict["completed_at"] = completedAt.ISO8601Format()
                    }
                    return dict
                }]
            )
            plan = updated
        } catch {
            currentPlan.nextActions = originalActions
            plan = currentPlan
            errorMessage = "Failed to delete action: \(error.localizedDescription)"
        }
    }
    
    func deletePlan() async {
        do {
            _ = try await apiClient.updatePlan(planId: planId, updates: ["status": "archived"])
        } catch {
            errorMessage = "Failed to delete plan: \(error.localizedDescription)"
        }
    }
}

// MARK: - All Plans View Model

@MainActor
class PlanViewModel: ObservableObject {
    @Published var plans: [Plan] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiClient: SimonAPI
    
    init(apiClient: SimonAPI) {
        self.apiClient = apiClient
    }
    
    // MARK: - Load Plans
    
    func loadPlans() async {
        isLoading = true
        errorMessage = nil
        
        do {
            plans = try await apiClient.listPlans(status: nil, limit: 100)
        } catch {
            errorMessage = "Failed to load plans: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}
