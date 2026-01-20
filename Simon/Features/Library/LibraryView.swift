import SwiftUI

struct LibraryView: View {
    @StateObject private var vm: LibraryViewModel
    @EnvironmentObject private var theme: ThemeStore
    
    @State private var showThisWeek = true
    @State private var showArchive = false
    
    init(vm: LibraryViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        Text("Library")
                            .font(theme.font(32, weight: .bold))
                        
                        Spacer()
                        
                        Button(action: { vm.showSettings() }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    
                    // Loading State
                    if vm.isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                            Text("Loading your library...")
                                .font(theme.font(15))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }
                    // Empty State
                    else if vm.recentSessions.isEmpty && vm.pinnedSystems.isEmpty {
                        SEmptyState(
                            icon: "books.vertical",
                            title: "Your library is empty",
                            message: "Start a conversation or create a system to see them here.",
                            primaryAction: EmptyStateAction(
                                title: "Start a Moment",
                                action: { vm.startNewMoment() }
                            )
                        )
                        .padding(.top, 60)
                    }
                    // Content
                    else {
                        // Latest Moment Card (Featured)
                        if let latestSession = vm.recentSessions.first {
                            LatestMomentCard(session: latestSession) {
                                vm.continueSession(latestSession)
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // This Week Section
                        if !vm.thisWeekSessions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Button(action: { withAnimation { showThisWeek.toggle() } }) {
                                    HStack {
                                        Text("This Week")
                                            .font(theme.font(22, weight: .bold))
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.up")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.secondary)
                                            .rotationEffect(.degrees(showThisWeek ? 0 : 180))
                                    }
                                }
                                .padding(.horizontal, 20)
                                
                                if showThisWeek {
                                    VStack(spacing: 8) {
                                        ForEach(vm.thisWeekSessions) { session in
                                            SessionRowCard(session: session) {
                                                vm.continueSession(session)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        
                        // Pinned Systems Section
                        if !vm.pinnedSystems.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Pinned Systems")
                                    .font(theme.font(22, weight: .bold))
                                    .padding(.horizontal, 20)
                                
                                VStack(spacing: 12) {
                                    ForEach(vm.pinnedSystems) { system in
                                        PinnedSystemCard(system: system) {
                                            vm.viewSystem(system)
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        // Archive Section
                        if !vm.archivedSessions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Button(action: { withAnimation { showArchive.toggle() } }) {
                                    HStack {
                                        Text("Archive")
                                            .font(theme.font(22, weight: .bold))
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.up")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.secondary)
                                            .rotationEffect(.degrees(showArchive ? 0 : 180))
                                    }
                                }
                                .padding(.horizontal, 20)
                                
                                if showArchive {
                                    VStack(spacing: 8) {
                                        ForEach(vm.archivedSessions) { session in
                                            SessionRowCard(session: session) {
                                                vm.continueSession(session)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 100)
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
        .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
            Button("OK") {
                vm.errorMessage = nil
            }
        } message: {
            if let error = vm.errorMessage {
                Text(error)
            }
        }
    }
}

// MARK: - Latest Moment Card (Featured)
struct LatestMomentCard: View {
    let session: Session
    let action: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // Gradient Image Area
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [
                            theme.accentPrimary.opacity(0.6),
                            theme.accentPrimary.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 180)
                    
                    Text("Latest Moment")
                        .font(theme.font(13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                        .padding(16)
                }
                
                // Content Area
                VStack(alignment: .leading, spacing: 8) {
                    Text(session.title)
                        .font(theme.font(20, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(generateDescription(for: session))
                        .font(theme.font(14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        Text(session.updatedAt.timeAgoDetailed())
                            .font(theme.font(12))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Text("Read More")
                                .font(theme.font(13, weight: .medium))
                                .foregroundColor(theme.accentPrimary)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(theme.accentPrimary)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(16)
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private func generateDescription(for session: Session) -> String {
        "Session focused on \(session.mode) to help you achieve your goals."
    }
}

// MARK: - Session Row Card
struct SessionRowCard: View {
    let session: Session
    let action: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 20))
                        .foregroundColor(iconColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title)
                        .font(theme.font(16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(session.updatedAt.timeAgoShort())
                            .font(theme.font(13))
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(sessionType)
                            .font(theme.font(13))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private var iconName: String {
        switch session.mode.lowercased() {
        case "moment": return "bolt.fill"
        case "coach": return "person.fill"
        default: return "bubble.left.fill"
        }
    }
    
    private var iconColor: Color {
        switch session.mode.lowercased() {
        case "moment": return .orange
        case "coach": return theme.accentPrimary
        default: return .blue
        }
    }
    
    private var sessionType: String {
        session.mode.capitalized
    }
}

// MARK: - Pinned System Card
struct PinnedSystemCard: View {
    let system: System
    let action: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "rocket.fill")
                            .font(.system(size: 16))
                            .foregroundColor(theme.accentPrimary)
                        
                        Text(system.title)
                            .font(theme.font(17, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    // Progress badge
                    Text("\(completionPercentage)%")
                        .font(theme.font(13, weight: .semibold))
                        .foregroundColor(theme.accentPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(theme.accentPrimary.opacity(0.15))
                        .cornerRadius(8)
                }
                
                Text("Last active \(system.createdAt.timeAgoShort())")
                    .font(theme.font(12))
                    .foregroundColor(.secondary)
                
                // Checklist preview
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(system.checklist.prefix(3), id: \.self) { item in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.green)
                            
                            Text(item)
                                .font(theme.font(14))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }
                }
                
                if system.checklist.count > 3 {
                    HStack {
                        Text("\(system.checklist.count - 3) tasks remaining")
                            .font(theme.font(13))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Text("Resume")
                                .font(theme.font(13, weight: .medium))
                                .foregroundColor(theme.accentPrimary)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12))
                                .foregroundColor(theme.accentPrimary)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
    
    private var completionPercentage: Int {
        guard !system.checklist.isEmpty else { return 0 }
        // Mock completion - in real app, track actual completion
        return Int.random(in: 30...90)
    }
}

// MARK: - Date Extensions
extension Date {
    func timeAgo() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    func timeAgoShort() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    func timeAgoDetailed() -> String {
        let interval = Date().timeIntervalSince(self)
        let hours = Int(interval / 3600)
        
        if hours < 1 {
            return "Just now"
        } else if hours < 24 {
            return "\(hours) hours ago"
        } else {
            return timeAgoShort()
        }
    }
}
