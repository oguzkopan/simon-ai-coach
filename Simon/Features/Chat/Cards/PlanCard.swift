import SwiftUI

struct PlanCard: View {
    let planInfo: PlanCardPayload.PlanInfo
    let onSave: () -> Void
    
    @State private var isSaved = false
    
    var body: some View {
        SCard {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                header
                
                // Objective
                VStack(alignment: .leading, spacing: 8) {
                    Text("Objective")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Text(planInfo.objective)
                        .font(.body)
                }
                
                // Horizon
                HStack {
                    Image(systemName: horizonIcon(planInfo.horizon))
                    Text(planInfo.horizon.capitalized)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                
                // Milestones
                if !planInfo.milestones.isEmpty {
                    milestonesSection
                }
                
                // Next Actions
                if !planInfo.nextActions.isEmpty {
                    nextActionsSection
                }
                
                // Save button
                saveButton
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Image(systemName: "target")
                .font(.title2)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Plan")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Text(planInfo.title)
                    .font(.headline)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Milestones Section
    
    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Milestones")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(planInfo.milestones, id: \.label) { milestone in
                    HStack(spacing: 8) {
                        Image(systemName: "circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(milestone.label)
                                .font(.subheadline)
                            
                            if let dueDateHint = milestone.dueDateHint {
                                Text("Due: \(dueDateHint)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let successMetric = milestone.successMetric {
                                Text(successMetric)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Next Actions Section
    
    private var nextActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next Actions (\(planInfo.nextActions.count))")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(planInfo.nextActions.prefix(3), id: \.self) { action in
                    HStack(spacing: 8) {
                        Image(systemName: "circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(action)
                            .font(.subheadline)
                    }
                }
                
                if planInfo.nextActions.count > 3 {
                    Text("+ \(planInfo.nextActions.count - 3) more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                }
            }
        }
    }
    
    // MARK: - Save Button
    
    private var saveButton: some View {
        Button {
            withAnimation {
                isSaved = true
            }
            onSave()
            
            // Reset after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    isSaved = false
                }
            }
        } label: {
            HStack {
                Image(systemName: isSaved ? "checkmark.circle.fill" : "square.and.arrow.down")
                Text(isSaved ? "Saved to Plans" : "Save Plan")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSaved ? Color.green : Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .disabled(isSaved)
    }
    
    // MARK: - Helpers
    
    private func horizonIcon(_ horizon: String) -> String {
        switch horizon.lowercased() {
        case "today": return "sun.max"
        case "week": return "calendar.badge.clock"
        case "month": return "calendar"
        case "quarter": return "calendar.badge.plus"
        default: return "calendar"
        }
    }
}
