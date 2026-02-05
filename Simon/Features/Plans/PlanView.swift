import SwiftUI

// MARK: - Single Plan View (for viewing/editing one plan)

struct SinglePlanView: View {
    let planId: String
    @StateObject private var viewModel: SinglePlanViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeStore
    
    init(planId: String) {
        self.planId = planId
        _viewModel = StateObject(wrappedValue: SinglePlanViewModel(apiClient: SimonAPIClient.shared, planId: planId))
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let plan = viewModel.plan {
                ScrollView {
                    VStack(spacing: 24) {
                        EditablePlanCard(plan: plan, viewModel: viewModel)
                    }
                    .padding()
                }
            } else {
                SEmptyState(
                    icon: "exclamationmark.triangle",
                    title: "Plan Not Found",
                    message: "This plan may have been deleted or you don't have access to it"
                )
            }
        }
        .navigationTitle("Plan Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadPlan()
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
        .alert("Delete Plan", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deletePlan()
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to delete this plan? This action cannot be undone.")
        }
    }
}

// MARK: - All Plans View (for viewing all plans)

struct AllPlansView: View {
    @StateObject private var viewModel: PlanViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(viewModel: PlanViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.plans.isEmpty {
                emptyState
            } else {
                plansList
            }
        }
        .navigationTitle("All Plans")
        .navigationBarTitleDisplayMode(.large)
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
    
    private var emptyState: some View {
        SEmptyState(
            icon: "list.bullet.clipboard",
            title: "No Plans Yet",
            message: "Plans will appear here when your coach creates them during sessions"
        )
    }
    
    private var plansList: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(viewModel.plans) { plan in
                    NavigationLink(destination: SinglePlanView(planId: plan.id)) {
                        PlanSummaryCard(plan: plan)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}

// MARK: - Plan Summary Card (for list view)

struct PlanSummaryCard: View {
    let plan: Plan
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: plan.horizon.icon)
                    Text(plan.horizon.displayName)
                }
                .font(theme.font(12))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                
                Spacer()
                
                Text("\(Int(plan.progress * 100))%")
                    .font(theme.font(14, weight: .semibold))
                    .foregroundColor(theme.accentPrimary)
            }
            
            Text(plan.title)
                .font(theme.font(18, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(plan.objective)
                .font(theme.font(14))
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Label("\(plan.completedActionsCount)/\(plan.totalActionsCount) actions", systemImage: "checkmark.circle")
                    .font(theme.font(13))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Editable Plan Card

struct EditablePlanCard: View {
    let plan: Plan
    @ObservedObject var viewModel: SinglePlanViewModel
    @EnvironmentObject private var theme: ThemeStore
    @State private var isEditingTitle = false
    @State private var isEditingObjective = false
    @State private var editedTitle = ""
    @State private var editedObjective = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header with delete button
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: plan.horizon.icon)
                        Text(plan.horizon.displayName)
                    }
                    .font(theme.font(12))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                Button(action: { viewModel.showDeleteConfirmation = true }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            // Editable Title
            if isEditingTitle {
                HStack {
                    TextField("Plan Title", text: $editedTitle)
                        .font(theme.font(24, weight: .bold))
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Save") {
                        Task {
                            await viewModel.updateTitle(editedTitle)
                            isEditingTitle = false
                        }
                    }
                    .font(theme.font(14, weight: .medium))
                    
                    Button("Cancel") {
                        isEditingTitle = false
                    }
                    .font(theme.font(14))
                }
            } else {
                Button(action: {
                    editedTitle = plan.title
                    isEditingTitle = true
                }) {
                    HStack {
                        Text(plan.title)
                            .font(theme.font(24, weight: .bold))
                            .foregroundColor(.primary)
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Editable Objective
            if isEditingObjective {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $editedObjective)
                        .font(theme.font(16))
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    HStack {
                        Button("Save") {
                            Task {
                                await viewModel.updateObjective(editedObjective)
                                isEditingObjective = false
                            }
                        }
                        .font(theme.font(14, weight: .medium))
                        
                        Button("Cancel") {
                            isEditingObjective = false
                        }
                        .font(theme.font(14))
                    }
                }
            } else {
                Button(action: {
                    editedObjective = plan.objective
                    isEditingObjective = true
                }) {
                    HStack {
                        Text(plan.objective)
                            .font(theme.font(16))
                            .foregroundColor(.secondary)
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Progress
            progressBar
            
            // Milestones
            if !plan.milestones.isEmpty {
                editableMilestonesSection
            }
            
            // Next Actions
            if !plan.nextActions.isEmpty {
                editableNextActionsSection
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
    
    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(plan.completedActionsCount) of \(plan.totalActionsCount) actions")
                    .font(theme.font(14))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(plan.progress * 100))%")
                    .font(theme.font(14, weight: .semibold))
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(theme.accentPrimary)
                        .frame(width: geometry.size.width * plan.progress, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }
    
    private var editableMilestonesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Milestones")
                .font(theme.font(20, weight: .semibold))
            
            VStack(spacing: 8) {
                ForEach(plan.milestones) { milestone in
                    EditableMilestoneRow(
                        milestone: milestone,
                        onToggle: {
                            Task {
                                await viewModel.toggleMilestoneStatus(milestoneId: milestone.id)
                            }
                        },
                        onDelete: {
                            Task {
                                await viewModel.deleteMilestone(milestoneId: milestone.id)
                            }
                        }
                    )
                }
            }
        }
    }
    
    private var editableNextActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Next Actions")
                .font(theme.font(20, weight: .semibold))
            
            VStack(spacing: 8) {
                ForEach(plan.nextActions) { action in
                    EditableNextActionRow(
                        action: action,
                        onToggle: {
                            Task {
                                await viewModel.toggleActionCompletion(actionId: action.id)
                            }
                        },
                        onDelete: {
                            Task {
                                await viewModel.deleteAction(actionId: action.id)
                            }
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Editable Milestone Row

struct EditableMilestoneRow: View {
    let milestone: Milestone
    let onToggle: () -> Void
    let onDelete: () -> Void
    @EnvironmentObject private var theme: ThemeStore
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: milestone.status.icon)
                    .foregroundColor(statusColor)
                    .font(.system(size: 20))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .font(theme.font(16))
                    .foregroundColor(.primary)
                
                if let description = milestone.description {
                    Text(description)
                        .font(theme.font(13))
                        .foregroundColor(.secondary)
                }
                
                if let dueDate = milestone.dueDate {
                    Text("Due: \(dueDate, style: .date)")
                        .font(theme.font(12))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: { showDeleteConfirmation = true }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.system(size: 16))
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .alert("Delete Milestone", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("Are you sure you want to delete this milestone?")
        }
    }
    
    private var statusColor: Color {
        switch milestone.status {
        case .pending: return .secondary
        case .inProgress: return .orange
        case .completed: return .green
        }
    }
}

// MARK: - Editable Next Action Row

struct EditableNextActionRow: View {
    let action: NextAction
    let onToggle: () -> Void
    let onDelete: () -> Void
    @EnvironmentObject private var theme: ThemeStore
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: action.status == .completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(action.status == .completed ? .green : .secondary)
                    .font(.system(size: 20))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(action.title)
                    .font(theme.font(16))
                    .foregroundColor(.primary)
                    .strikethrough(action.status == .completed)
                
                HStack(spacing: 12) {
                    if let duration = action.durationMin {
                        Label("\(duration) min", systemImage: "clock")
                            .font(theme.font(12))
                            .foregroundColor(.secondary)
                    }
                    
                    if let energy = action.energy {
                        Label(energy.displayName, systemImage: energy.icon)
                            .font(theme.font(12))
                            .foregroundColor(.secondary)
                    }
                    
                    if let when = action.when {
                        Label(when.kind.displayName, systemImage: "calendar")
                            .font(theme.font(12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Button(action: { showDeleteConfirmation = true }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.system(size: 16))
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .alert("Delete Action", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("Are you sure you want to delete this action?")
        }
    }
}
