import SwiftUI

struct LibraryView: View {
    @StateObject private var vm: LibraryViewModel
    @EnvironmentObject private var theme: ThemeStore
    
    init(vm: LibraryViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Library")
                            .font(theme.font(28, weight: .bold))
                        Text("Your coaches, sessions, and systems.")
                            .font(theme.font(15))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
                    // Continue Section
                    if !vm.recentSessions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Continue")
                                .font(theme.font(17, weight: .semibold))
                                .padding(.horizontal, 16)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(vm.recentSessions) { session in
                                        SessionCard(session: session) {
                                            vm.continueSession(session)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    // Saved Coaches Section
                    if !vm.savedCoaches.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Saved Coaches")
                                .font(theme.font(17, weight: .semibold))
                                .padding(.horizontal, 16)
                            
                            LazyVStack(spacing: 12) {
                                ForEach(vm.savedCoaches) { coach in
                                    CoachCard(coach: coach) {
                                        vm.startCoach(coach)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    // Pinned Systems Section
                    if !vm.pinnedSystems.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Pinned Systems")
                                .font(theme.font(17, weight: .semibold))
                                .padding(.horizontal, 16)
                            
                            LazyVStack(spacing: 12) {
                                ForEach(vm.pinnedSystems) { system in
                                    SystemCard(system: system) {
                                        vm.viewSystem(system)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    // Empty State
                    if vm.recentSessions.isEmpty && vm.savedCoaches.isEmpty && vm.pinnedSystems.isEmpty {
                        SEmptyState(
                            icon: "books.vertical",
                            title: "Your library is empty",
                            message: "Start a Moment or browse coaches to begin.",
                            primaryAction: EmptyStateAction(
                                title: "Browse Coaches",
                                action: { vm.showBrowse() }
                            )
                        )
                        .padding(.top, 60)
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await vm.refresh()
            }
        }
        .task {
            await vm.loadData()
        }
        .sheet(item: $vm.selectedSystem) { system in
            SystemDetailView(system: system)
        }
    }
}

struct SessionCard: View {
    let session: Session
    let action: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(session.title)
                    .font(theme.font(17, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("Last updated \(session.updatedAt.timeAgo())")
                    .font(theme.font(13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 280, alignment: .leading)
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

struct SystemCard: View {
    let system: System
    let action: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(system.title)
                    .font(theme.font(17, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                if let firstItem = system.checklist.first {
                    Text("Next: \(firstItem)")
                        .font(theme.font(15))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    if !system.scheduleSuggestion.isEmpty {
                        STagChip(title: system.scheduleSuggestion)
                    }
                    
                    if !system.metrics.isEmpty {
                        STagChip(title: "\(system.metrics.count) metrics")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// Helper extension for time ago
extension Date {
    func timeAgo() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
