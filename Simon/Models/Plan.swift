import Foundation

// MARK: - Plan

/// Represents a structured plan with objectives, milestones, and next actions
struct Plan: Codable, Identifiable {
    let id: String
    let uid: String
    let coachId: String?  // Made optional to handle missing values
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
    
    // Custom decoder to handle missing or malformed fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        uid = try container.decode(String.self, forKey: .uid)
        coachId = try? container.decode(String.self, forKey: .coachId)
        title = try container.decode(String.self, forKey: .title)
        objective = try container.decode(String.self, forKey: .objective)
        horizon = try container.decode(PlanHorizon.self, forKey: .horizon)
        
        // Provide defaults for arrays if missing
        milestones = (try? container.decode([Milestone].self, forKey: .milestones)) ?? []
        nextActions = (try? container.decode([NextAction].self, forKey: .nextActions)) ?? []
        
        status = try container.decode(PlanStatus.self, forKey: .status)
        
        // Provide defaults for dates if missing
        createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
        updatedAt = (try? container.decode(Date.self, forKey: .updatedAt)) ?? Date()
    }
    
    // Custom encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(uid, forKey: .uid)
        try container.encodeIfPresent(coachId, forKey: .coachId)
        try container.encode(title, forKey: .title)
        try container.encode(objective, forKey: .objective)
        try container.encode(horizon, forKey: .horizon)
        try container.encode(milestones, forKey: .milestones)
        try container.encode(nextActions, forKey: .nextActions)
        try container.encode(status, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
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
    static var sample: Plan {
        let plan = Plan(
            id: "plan_sample",
            uid: "user_123",
            coachId: "coach_456",
            title: "Landing Page MVP",
            objective: "Ship landing page by Friday",
            horizon: PlanHorizon.week,
            milestones: [
                Milestone(
                    id: "milestone_1",
                    title: "Outline complete",
                    description: "Define 5 key sections",
                    dueDate: Date().addingTimeInterval(86400 * 2),
                    status: MilestoneStatus.pending
                ),
                Milestone(
                    id: "milestone_2",
                    title: "First draft",
                    description: "Write copy for all sections",
                    dueDate: Date().addingTimeInterval(86400 * 4),
                    status: MilestoneStatus.pending
                )
            ],
            nextActions: [
                NextAction(
                    id: "action_1",
                    title: "Write 5 bullet outline",
                    durationMin: 10,
                    energy: EnergyLevel.low,
                    when: ActionTiming(
                        kind: TimingKind.todayWindow,
                        startISO: Date().addingTimeInterval(3600 * 2),
                        endISO: Date().addingTimeInterval(3600 * 4)
                    ),
                    status: ActionStatus.pending,
                    completedAt: nil
                ),
                NextAction(
                    id: "action_2",
                    title: "Draft hero section",
                    durationMin: 30,
                    energy: EnergyLevel.medium,
                    when: ActionTiming(
                        kind: TimingKind.todayWindow,
                        startISO: Date().addingTimeInterval(3600 * 4),
                        endISO: Date().addingTimeInterval(3600 * 6)
                    ),
                    status: ActionStatus.pending,
                    completedAt: nil
                )
            ],
            status: PlanStatus.active,
            createdAt: Date(),
            updatedAt: Date()
        )
        return plan
    }
    
    // Manual initializer for creating Plan instances
    init(id: String, uid: String, coachId: String?, title: String, objective: String, 
         horizon: PlanHorizon, milestones: [Milestone], nextActions: [NextAction], 
         status: PlanStatus, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.uid = uid
        self.coachId = coachId
        self.title = title
        self.objective = objective
        self.horizon = horizon
        self.milestones = milestones
        self.nextActions = nextActions
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
#endif
