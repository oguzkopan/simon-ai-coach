import SwiftUI

struct PlanView: View {
    @StateObject private var viewModel = PlanViewModel(apiClient: .shared)
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    SFullScreenLoading()
                } else if viewModel.plans.isEmpty {
                    emptyState
                } else {
                    plansList
                }
            }
            .navigationTitle("Plans")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadPlans()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        SEmptyState(
            icon: "list.bullet.clipboard",
            title: "No Plans Yet",
            message: "Plans will appear here when your coach creates them during sessions"
        )
    }
    
    // MARK: - Plans List
    
    private var plansList: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(viewModel.plans) { plan in
                    PlanDetailCard(plan: plan, viewModel: viewModel)
                }
            }
            .padding()
        }
    }
}

// MARK: - Plan Card

struct PlanDetailCard: View {
    let plan: Plan
    @ObservedObject var viewModel: PlanViewModel
    @State private var isExpanded = true
    
    var body: some View {
        SCard {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                header
                
                // Progress
                progressBar
                
                if isExpanded {
                    // Milestones
                    if !plan.milestones.isEmpty {
                        milestonesSection
                    }
                    
                    // Next Actions
                    if !plan.nextActions.isEmpty {
                        nextActionsSection
                    }
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Horizon badge
                HStack(spacing: 4) {
                    Image(systemName: plan.horizon.icon)
                    Text(plan.horizon.displayName)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                
                Spacer()
                
                // Expand/collapse button
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            
            // Title
            Text(plan.title)
                .font(.title3)
                .fontWeight(.semibold)
            
            // Objective
            Text(plan.objective)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(plan.completedActionsCount) of \(plan.totalActionsCount) actions")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(plan.progress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * plan.progress, height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
        }
    }
    
    // MARK: - Milestones Section
    
    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Milestones")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(plan.milestones) { milestone in
                    MilestoneRow(
                        milestone: milestone,
                        onTap: {
                            Task {
                                await viewModel.toggleMilestoneStatus(
                                    planId: plan.id,
                                    milestoneId: milestone.id
                                )
                            }
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Next Actions Section
    
    private var nextActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Next Actions")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(plan.nextActions) { action in
                    NextActionRow(
                        action: action,
                        onToggle: {
                            Task {
                                await viewModel.toggleActionCompletion(
                                    planId: plan.id,
                                    actionId: action.id
                                )
                            }
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Milestone Row

struct MilestoneRow: View {
    let milestone: Milestone
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: milestone.status.icon)
                    .foregroundColor(statusColor)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(milestone.title)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    if let description = milestone.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let dueDate = milestone.dueDate {
                        Text("Due: \(dueDate, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text(milestone.status.displayName)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
            .padding(12)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    private var statusColor: Color {
        switch milestone.status {
        case .pending: return .secondary
        case .inProgress: return .orange
        case .completed: return .green
        }
    }
}

// MARK: - Next Action Row

struct NextActionRow: View {
    let action: NextAction
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: action.status == .completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(action.status == .completed ? .green : .secondary)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(action.title)
                        .font(.body)
                        .foregroundColor(.primary)
                        .strikethrough(action.status == .completed)
                    
                    HStack(spacing: 12) {
                        if let duration = action.durationMin {
                            Label("\(duration) min", systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let energy = action.energy {
                            Label(energy.displayName, systemImage: energy.icon)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let when = action.when {
                            Label(when.kind.displayName, systemImage: "calendar")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(12)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
