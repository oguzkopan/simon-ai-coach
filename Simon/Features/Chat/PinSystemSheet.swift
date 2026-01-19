import SwiftUI

struct PinSystemSheet: View {
    let message: Message
    let onSave: (String, [String], String, [String]) async -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeStore
    
    @State private var title = ""
    @State private var checklist: [String] = []
    @State private var schedule = ""
    @State private var metrics: [String] = []
    @State private var newChecklistItem = ""
    @State private var newMetric = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("System Title") {
                    TextField("e.g., Weekly Review", text: $title)
                }
                
                Section("Checklist") {
                    ForEach(Array(checklist.enumerated()), id: \.offset) { index, item in
                        HStack {
                            Text(item)
                            Spacer()
                            Button(action: { checklist.remove(at: index) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    HStack {
                        TextField("Add step...", text: $newChecklistItem)
                        Button(action: addChecklistItem) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(theme.accentPrimary)
                        }
                        .disabled(newChecklistItem.isEmpty)
                    }
                }
                
                Section("Schedule") {
                    TextField("e.g., Every Sunday at 6pm", text: $schedule)
                }
                
                Section("Metrics to Track") {
                    ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                        HStack {
                            Text(metric)
                            Spacer()
                            Button(action: { metrics.remove(at: index) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    HStack {
                        TextField("Add metric...", text: $newMetric)
                        Button(action: addMetric) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(theme.accentPrimary)
                        }
                        .disabled(newMetric.isEmpty)
                    }
                }
            }
            .navigationTitle("Pin as System")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await save()
                        }
                    }
                    .disabled(title.isEmpty || checklist.isEmpty || isSaving)
                }
            }
        }
        .onAppear {
            parseMessageContent()
        }
    }
    
    private func parseMessageContent() {
        // Try to extract a title from the message
        let lines = message.contentText.components(separatedBy: .newlines)
        if let firstLine = lines.first, !firstLine.isEmpty {
            title = firstLine.trimmingCharacters(in: .whitespaces)
            if title.count > 60 {
                title = String(title.prefix(60))
            }
        }
        
        // Try to extract checklist items (lines starting with numbers or bullets)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            // Match patterns like "1. ", "- ", "• "
            if trimmed.range(of: "^[0-9]+\\.", options: .regularExpression) != nil ||
               trimmed.hasPrefix("- ") ||
               trimmed.hasPrefix("• ") {
                let cleaned = trimmed
                    .replacingOccurrences(of: "^[0-9]+\\.\\s*", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "^[-•]\\s*", with: "", options: .regularExpression)
                if !cleaned.isEmpty {
                    checklist.append(cleaned)
                }
            }
        }
        
        // If no checklist items found, add the whole message as one item
        if checklist.isEmpty {
            checklist.append(message.contentText)
        }
    }
    
    private func addChecklistItem() {
        guard !newChecklistItem.isEmpty else { return }
        checklist.append(newChecklistItem)
        newChecklistItem = ""
    }
    
    private func addMetric() {
        guard !newMetric.isEmpty else { return }
        metrics.append(newMetric)
        newMetric = ""
    }
    
    private func save() async {
        isSaving = true
        await onSave(title, checklist, schedule, metrics)
        isSaving = false
        dismiss()
    }
}
