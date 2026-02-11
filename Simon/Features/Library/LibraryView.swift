import SwiftUI

struct LibraryView: View {
    @StateObject private var vm: LibraryViewModel
    @StateObject private var authManager = AuthenticationManager.shared
    @EnvironmentObject private var theme: ThemeStore
    
    @State private var showThisWeek = true
    @State private var showArchive = false
    @State private var authErrorMessage: String?
    
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
                    
                    // Sign In Prompt (when not authenticated)
                    if !authManager.isAuthenticated {
                        signInPrompt
                            .padding(.horizontal, 20)
                            .padding(.top, 40)
                    }
                    // Loading State
                    else if vm.isLoading {
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
                        // My Progress Section (at the top)
                        if !vm.activePlans.isEmpty || !vm.recentCheckins.isEmpty || vm.isLoadingProgress {
                            myProgressSection
                                .padding(.horizontal, 20)
                        }
                        
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
            // Only load data if authenticated
            if authManager.isAuthenticated {
                await vm.loadData()
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            // Load data when user signs in
            if isAuthenticated {
                Task {
                    await vm.refresh()
                }
            }
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

// MARK: - My Progress Section

extension LibraryView {
    private var signInPrompt: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 56))
                    .foregroundColor(theme.accentPrimary)
                
                Text("Sign in to access your library")
                    .font(theme.font(22, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Your sessions, plans, and progress will be saved and synced across all your devices.")
                    .font(theme.font(15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 20)
            
            VStack(spacing: 12) {
                Button(action: {
                    Task {
                        do {
                            try await authManager.signInWithApple()
                        } catch {
                            authErrorMessage = error.localizedDescription
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Continue with Apple")
                            .font(theme.font(16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    Task {
                        do {
                            try await authManager.signInWithGoogle()
                        } catch {
                            authErrorMessage = error.localizedDescription
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "g.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Continue with Google")
                            .font(theme.font(16, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .alert("Sign In Error", isPresented: .constant(authErrorMessage != nil)) {
            Button("OK") {
                authErrorMessage = nil
            }
        } message: {
            if let error = authErrorMessage {
                Text(error)
            }
        }
    }
    
    private var myProgressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("My Progress")
                    .font(theme.font(22, weight: .bold))
                
                Spacer()
                
                if vm.activePlans.count > 3 {
                    NavigationLink(destination: AllPlansView(viewModel: PlanViewModel(apiClient: SimonAPIClient.shared))) {
                        HStack(spacing: 4) {
                            Text("More")
                                .font(theme.font(14, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(theme.accentPrimary)
                    }
                }
            }
            
            if vm.isLoadingProgress {
                // Loading skeleton
                VStack(spacing: 12) {
                    ForEach(0..<2, id: \.self) { _ in
                        ProgressCardSkeletonLibrary()
                    }
                }
            } else {
                VStack(spacing: 12) {
                    // Active Plans (show max 3)
                    ForEach(vm.activePlans.prefix(3)) { plan in
                        NavigationLink(destination: SinglePlanView(planId: plan.id)) {
                            BeautifulProgressPlanCard(plan: plan)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Recent Check-ins
                    ForEach(vm.recentCheckins) { checkin in
                        BeautifulProgressCheckinCard(checkin: checkin)
                    }
                }
            }
        }
    }
}

// MARK: - Beautiful Progress Plan Card

struct BeautifulProgressPlanCard: View {
    let plan: Plan
    @EnvironmentObject private var theme: ThemeStore
    
    var completedMilestones: Int {
        plan.milestones.filter { $0.status == .completed }.count
    }
    
    var pendingActions: Int {
        plan.nextActions.filter { $0.status == .pending }.count
    }
    
    var completionPercentage: Int {
        guard !plan.milestones.isEmpty else { return 0 }
        return Int((Double(completedMilestones) / Double(plan.milestones.count)) * 100)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "target")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(theme.font(17, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text("Last active \(plan.updatedAt.timeAgoShort())")
                        .font(theme.font(13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Completion Badge
                Text("\(completionPercentage)%")
                    .font(theme.font(15, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Checklist Preview (first 3 milestones)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(plan.milestones.prefix(3)) { milestone in
                    HStack(spacing: 10) {
                        Image(systemName: milestone.status == .completed ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundColor(milestone.status == .completed ? .green : Color(.systemGray4))
                        
                        Text(milestone.title)
                            .font(theme.font(15))
                            .foregroundColor(milestone.status == .completed ? .secondary : .primary)
                            .strikethrough(milestone.status == .completed)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                }
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("\(plan.milestones.count - completedMilestones) tasks remaining")
                    .font(theme.font(13))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("Resume")
                        .font(theme.font(14, weight: .medium))
                        .foregroundColor(theme.accentPrimary)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.accentPrimary)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Beautiful Progress Checkin Card

struct BeautifulProgressCheckinCard: View {
    let checkin: Checkin
    @EnvironmentObject private var theme: ThemeStore
    
    var streakDays: Int {
        // Mock streak calculation
        return Int.random(in: 3...15)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "book.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Journaling")
                        .font(theme.font(17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Current Streak")
                        .font(theme.font(13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Streak Badge
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                    
                    Text("\(streakDays) Days")
                        .font(theme.font(15, weight: .bold))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Checklist items
            VStack(alignment: .leading, spacing: 10) {
                ProgressChecklistItem(title: "Morning reflection", isCompleted: false)
                ProgressChecklistItem(title: "Goal setting", isCompleted: false)
                ProgressChecklistItem(title: "Evening review", isCompleted: false, isDisabled: true)
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("Start your day")
                    .font(theme.font(13))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("Open")
                        .font(theme.font(14, weight: .medium))
                        .foregroundColor(theme.accentPrimary)
                    
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.accentPrimary)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Progress Checklist Item

struct ProgressChecklistItem: View {
    let title: String
    let isCompleted: Bool
    var isDisabled: Bool = false
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundColor(isCompleted ? .green : (isDisabled ? Color(.systemGray5) : Color(.systemGray4)))
            
            Text(title)
                .font(theme.font(15))
                .foregroundColor(isDisabled ? .secondary.opacity(0.5) : (isCompleted ? .secondary : .primary))
                .strikethrough(isCompleted)
            
            Spacer()
        }
    }
}

// MARK: - Progress Card Skeleton (Library)

struct ProgressCardSkeletonLibrary: View {
    @EnvironmentObject private var theme: ThemeStore
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray5))
                    .frame(width: 44, height: 44)
                
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 18)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(width: 100, height: 14)
                }
                
                Spacer()
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 50, height: 28)
            }
            
            VStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 18, height: 18)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 16)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear {
            isAnimating = true
        }
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
