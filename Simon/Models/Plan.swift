import Foundation

// MARK: - Plan

/// Represents a structured plan with objectives, milestones, and next actions
struct Plan: Codable, Identifiable {
    let id: String
    let uid: String
    let coachId: String
    let title: String
    let objective: String
    let horizon: PlanHorizon
    var milestones: [Milestone]
    var nextActions: [NextAction]
    var status: PlanStatus
    let createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case uid
        case coachId = "coach_id"
        case title
        case objective
        case horizon
        case milestones
        case nextActions = "next_actions"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Plan Horizon

enum PlanHorizon: String, Codable, CaseIterable {
    case today
    case week
    case month
    case quarter
    
    var displayName: String {
        switch self {
        case .today: return "Today"
        case .week: return "This Week"
        case .month: return "This Month"
        case .quarter: return "This Quarter"
        }
    }
    
    var icon: String {
        switch self {
        case .today: return "sun.max"
        case .week: return "calendar.badge.clock"
        case .month: return "calendar"
        case .quarter: return "calendar.badge.plus"
        }
    }
}

// MARK: - Plan Status

enum PlanStatus: String, Codable {
    case active
    case completed
    case archived
    
    var displayName: String {
        switch self {
        case .active: return "Active"
        case .completed: return "Completed"
        case .archived: return "Archived"
        }
    }
    
    var color: String {
        switch self {
        case .active: return "blue"
        case .completed: return "green"
        case .archived: return "gray"
        }
    }
}

// MARK: - Milestone

struct Milestone: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let dueDate: Date?
    var status: MilestoneStatus
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case dueDate = "due_date"
        case status
    }
}

// MARK: - Milestone Status

enum MilestoneStatus: String, Codable {
    case pending
    case inProgress = "in_progress"
    case completed
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .completed: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Next Action

struct NextAction: Codable, Identifiable {
    let id: String
    let title: String
    let durationMin: Int?
    let energy: EnergyLevel?
    let when: ActionTiming?
    var status: ActionStatus
    var completedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case durationMin = "duration_min"
        case energy
        case when
        case status
        case completedAt = "completed_at"
    }
}

// MARK: - Energy Level

enum EnergyLevel: String, Codable {
    case low
    case medium
    case high
    
    var displayName: String {
        switch self {
        case .low: return "Low Energy"
        case .medium: return "Medium Energy"
        case .high: return "High Energy"
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "battery.25"
        case .medium: return "battery.50"
        case .high: return "battery.100"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "orange"
        case .high: return "red"
        }
    }
}

// MARK: - Action Status

enum ActionStatus: String, Codable {
    case pending
    case completed
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .completed: return "Completed"
        }
    }
}

// MARK: - Action Timing

struct ActionTiming: Codable {
    let kind: TimingKind
    let startISO: Date?
    let endISO: Date?
    
    enum CodingKeys: String, CodingKey {
        case kind
        case startISO = "start_iso"
        case endISO = "end_iso"
    }
}

// MARK: - Timing Kind

enum TimingKind: String, Codable {
    case now
    case todayWindow = "today_window"
    case scheduleExact = "schedule_exact"
    
    var displayName: String {
        switch self {
        case .now: return "Now"
        case .todayWindow: return "Today"
        case .scheduleExact: return "Scheduled"
        }
    }
}

// MARK: - Plan Extensions

extension Plan {
    var completedActionsCount: Int {
        nextActions.filter { $0.status == .completed }.count
    }
    
    var totalActionsCount: Int {
        nextActions.count
    }
    
    var progress: Double {
        guard totalActionsCount > 0 else { return 0 }
        return Double(completedActionsCount) / Double(totalActionsCount)
    }
    
    var completedMilestonesCount: Int {
        milestones.filter { $0.status == .completed }.count
    }
    
    var totalMilestonesCount: Int {
        milestones.count
    }
}

// MARK: - Sample Data

#if DEBUG
extension Plan {
    static let sample = Plan(
        id: "plan_sample",
        uid: "user_123",
        coachId: "coach_456",
        title: "Landing Page MVP",
        objective: "Ship landing page by Friday",
        horizon: .week,
        milestones: [
            Milestone(
                id: "milestone_1",
                title: "Outline complete",
                description: "Define 5 key sections",
                dueDate: Date().addingTimeInterval(86400 * 2),
                status: .pending
            ),
            Milestone(
                id: "milestone_2",
                title: "First draft",
                description: "Write copy for all sections",
                dueDate: Date().addingTimeInterval(86400 * 4),
                status: .pending
            )
        ],
        nextActions: [
            NextAction(
                id: "action_1",
                title: "Write 5 bullet outline",
                durationMin: 10,
                energy: .low,
                when: ActionTiming(
                    kind: .todayWindow,
                    startISO: Date().addingTimeInterval(3600 * 2),
                    endISO: Date().addingTimeInterval(3600 * 4)
                ),
                status: .pending,
                completedAt: nil
            ),
            NextAction(
                id: "action_2",
                title: "Draft hero section",
                durationMin: 30,
                energy: .medium,
                when: ActionTiming(
                    kind: .todayWindow,
                    startISO: Date().addingTimeInterval(3600 * 4),
                    endISO: Date().addingTimeInterval(3600 * 6)
                ),
                status: .pending,
                completedAt: nil
            )
        ],
        status: .active,
        createdAt: Date(),
        updatedAt: Date()
    )
}
#endif
