import SwiftUI
import UIKit

struct SystemDetailView: View {
    let system: System
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeStore
    @State private var completedItems: Set<Int> = []
    @State private var showShareSheet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Title
                    Text(system.title)
                        .font(theme.font(28, weight: .bold))
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    
                    // Schedule
                    if !system.scheduleSuggestion.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Schedule", systemImage: "calendar")
                                .font(theme.font(15, weight: .semibold))
                                .foregroundColor(theme.accentPrimary)
                            
                            Text(system.scheduleSuggestion)
                                .font(theme.font(15))
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.accentTint)
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                    }
                    
                    // Checklist
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Checklist")
                            .font(theme.font(17, weight: .semibold))
                            .padding(.horizontal, 16)
                        
                        VStack(spacing: 8) {
                            ForEach(Array(system.checklist.enumerated()), id: \.offset) { index, item in
                                ChecklistItem(
                                    text: item,
                                    isCompleted: completedItems.contains(index)
                                ) {
                                    toggleItem(index)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Metrics
                    if !system.metrics.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Track")
                                .font(theme.font(17, weight: .semibold))
                                .padding(.horizontal, 16)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(system.metrics, id: \.self) { metric in
                                    HStack {
                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                            .foregroundColor(theme.accentPrimary)
                                        Text(metric)
                                            .font(theme.font(15))
                                    }
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    // Actions
                    VStack(spacing: 12) {
                        SButton(
                            "Export to Notes",
                            style: .secondary,
                            action: exportToNotes
                        )
                        
                        SButton(
                            "Copy",
                            style: .tertiary,
                            action: copyToClipboard
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                .padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [formatSystemText()])
        }
    }
    
    private func toggleItem(_ index: Int) {
        if completedItems.contains(index) {
            completedItems.remove(index)
        } else {
            completedItems.insert(index)
        }
    }
    
    private func exportToNotes() {
        // TODO: Implement export to Notes app
        print("Export to Notes")
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = formatSystemText()
    }
    
    private func formatSystemText() -> String {
        var text = "# \(system.title)\n\n"
        
        if !system.scheduleSuggestion.isEmpty {
            text += "**Schedule:** \(system.scheduleSuggestion)\n\n"
        }
        
        text += "**Checklist:**\n"
        for (index, item) in system.checklist.enumerated() {
            text += "\(index + 1). \(item)\n"
        }
        
        if !system.metrics.isEmpty {
            text += "\n**Track:**\n"
            for metric in system.metrics {
                text += "- \(metric)\n"
            }
        }
        
        return text
    }
}

struct ChecklistItem: View {
    let text: String
    let isCompleted: Bool
    let action: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isCompleted ? theme.accentPrimary : .secondary)
                    .font(.system(size: 24))
                
                Text(text)
                    .font(theme.font(15))
                    .foregroundColor(isCompleted ? .secondary : .primary)
                    .strikethrough(isCompleted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// Share Sheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
