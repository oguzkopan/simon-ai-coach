import SwiftUI

struct NextActionsCard: View {
    let items: [NextActionsCardPayload.NextActionItem]
    let onActionComplete: (String) -> Void
    let onConvertToReminder: (NextActionsCardPayload.NextActionItem) -> Void
    let onConvertToCalendar: (NextActionsCardPayload.NextActionItem) -> Void
    
    @State private var completedActions: Set<String> = []
    
    var body: some View {
        SCard {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                header
                
                // Actions list
                VStack(spacing: 12) {
                    ForEach(items, id: \.id) { item in
                        NextActionCardRow(
                            item: item,
                            isCompleted: completedActions.contains(item.id),
                            onToggle: {
                                toggleAction(item.id)
                            },
                            onConvertToReminder: {
                                onConvertToReminder(item)
                            },
                            onConvertToCalendar: {
                                onConvertToCalendar(item)
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Image(systemName: "list.bullet.clipboard")
                .font(.title2)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Next Actions")
                    .font(.headline)
                
                Text("\(items.count) action\(items.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func toggleAction(_ id: String) {
        withAnimation {
            if completedActions.contains(id) {
                completedActions.remove(id)
            } else {
                completedActions.insert(id)
            }
        }
        onActionComplete(id)
    }
}

// MARK: - Next Action Card Row

struct NextActionCardRow: View {
    let item: NextActionsCardPayload.NextActionItem
    let isCompleted: Bool
    let onToggle: () -> Void
    let onConvertToReminder: () -> Void
    let onConvertToCalendar: () -> Void
    
    @State private var showingActions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main row
            HStack(spacing: 12) {
                // Checkbox
                Button(action: onToggle) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isCompleted ? .green : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.body)
                        .foregroundColor(.primary)
                        .strikethrough(isCompleted)
                    
                    // Metadata
                    HStack(spacing: 12) {
                        Label("\(item.durationMin) min", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label(item.energy.capitalized, systemImage: energyIcon(item.energy))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // More actions button
                Button {
                    showingActions.toggle()
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Action buttons (when expanded)
            if showingActions {
                HStack(spacing: 8) {
                    Button {
                        onConvertToReminder()
                        showingActions = false
                    } label: {
                        Label("Add to Reminders", systemImage: "checklist")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button {
                        onConvertToCalendar()
                        showingActions = false
                    } label: {
                        Label("Add to Calendar", systemImage: "calendar.badge.plus")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.leading, 36)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func energyIcon(_ energy: String) -> String {
        switch energy.lowercased() {
        case "low": return "battery.25"
        case "medium": return "battery.50"
        case "high": return "battery.100"
        default: return "battery.50"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct NextActionsCard_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 16) {
                NextActionsCard(
                    items: [
                        NextActionsCardPayload.NextActionItem(
                            id: "1",
                            title: "Write 5 bullet outline",
                            durationMin: 10,
                            energy: "low",
                            when: NextActionsCardPayload.NextActionItem.WhenInfo(
                                kind: "today_window",
                                startIso: Date().ISO8601Format(),
                                endIso: Date().addingTimeInterval(3600).ISO8601Format()
                            ),
                            confidence: 0.78
                        ),
                        NextActionsCardPayload.NextActionItem(
                            id: "2",
                            title: "Draft hero section",
                            durationMin: 30,
                            energy: "medium",
                            when: NextActionsCardPayload.NextActionItem.WhenInfo(
                                kind: "now",
                                startIso: nil,
                                endIso: nil
                            ),
                            confidence: 0.85
                        )
                    ],
                    onActionComplete: { _ in },
                    onConvertToReminder: { _ in },
                    onConvertToCalendar: { _ in }
                )
            }
            .padding()
        }
    }
}
#endif
