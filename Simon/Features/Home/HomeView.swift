import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @EnvironmentObject private var theme: ThemeStore
    let onCoachTap: ((Coach) -> Void)?
    
    init(viewModel: HomeViewModel, onCoachTap: ((Coach) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onCoachTap = onCoachTap
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.categories, id: \.self) { category in
                            FilterChip(
                                title: category,
                                isSelected: viewModel.selectedCategory == category || (viewModel.selectedCategory == nil && category == "All"),
                                action: { viewModel.selectCategory(category) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Loading state
                if viewModel.isLoading {
                    VStack(spacing: 16) {
                        ForEach(0..<3, id: \.self) { _ in
                            CoachCardSkeleton()
                        }
                    }
                    .padding(.horizontal, 20)
                }
                // Error state
                else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Text("Failed to load coaches")
                            .font(theme.font(20, weight: .semibold))
                            .foregroundColor(.primary)
                        Text(errorMessage)
                            .font(theme.font(15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task {
                                await viewModel.loadCoaches()
                            }
                        }
                        .font(theme.font(15, weight: .semibold))
                        .foregroundColor(theme.accentPrimary)
                        .padding(.top, 8)
                    }
                    .padding(40)
                    .frame(maxWidth: .infinity)
                }
                // Coach list
                else if viewModel.coaches.isEmpty {
                    VStack(spacing: 16) {
                        Text("No coaches found")
                            .font(theme.font(20, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Try selecting a different category")
                            .font(theme.font(15))
                            .foregroundColor(.secondary)
                    }
                    .padding(40)
                    .frame(maxWidth: .infinity)
                }
                else {
                    VStack(spacing: 16) {
                        ForEach(viewModel.coaches) { coach in
                            CoachCard(coach: coach) {
                                if let onCoachTap = onCoachTap {
                                    onCoachTap(coach)
                                } else {
                                    viewModel.startCoach(coach)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 100) // Space for tab bar
        }
        .task {
            if viewModel.coaches.isEmpty && !viewModel.isLoading {
                await viewModel.loadCoaches()
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(theme.font(15, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : theme.accentPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(isSelected ? theme.accentPrimary : theme.accentTint)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

struct CoachCard: View {
    let coach: Coach
    let action: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                // Icon with colored background
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(getIconColor(for: coach.tags.first ?? ""))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: getIconName(for: coach.tags.first ?? ""))
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(coach.title)
                        .font(theme.font(20, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if let firstTag = coach.tags.first {
                        Text(firstTag.uppercased())
                            .font(theme.font(11, weight: .semibold))
                            .foregroundColor(getIconColor(for: firstTag))
                            .tracking(0.5)
                    }
                }
                
                Spacer()
            }
            
            Text(coach.promise)
                .font(theme.font(15))
                .foregroundColor(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            
            Button(action: action) {
                HStack {
                    Text(getActionText(for: coach.tags.first ?? ""))
                        .font(theme.font(15, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.systemGray5))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    private func getIconColor(for tag: String) -> Color {
        switch tag.lowercased() {
        case "focus":
            return Color(hex: "00C7BE") // Teal/Cyan
        case "planning":
            return Color(hex: "FF9500") // Orange
        case "creativity":
            return Color(hex: "AF52DE") // Purple
        case "business", "strategy":
            return Color(hex: "5856D6") // Indigo
        case "wellness", "health":
            return Color(hex: "00C7BE") // Mint/Green
        case "decision":
            return Color(hex: "FF2D55") // Rose
        default:
            return Color(hex: "5856D6") // Default indigo
        }
    }
    
    private func getIconName(for tag: String) -> String {
        switch tag.lowercased() {
        case "focus":
            return "target"
        case "planning":
            return "calendar"
        case "creativity":
            return "lightbulb.fill"
        case "business", "strategy":
            return "chart.line.uptrend.xyaxis"
        case "wellness", "health":
            return "leaf.fill"
        case "decision":
            return "arrow.triangle.branch"
        default:
            return "star.fill"
        }
    }
    
    private func getActionText(for tag: String) -> String {
        switch tag.lowercased() {
        case "focus":
            return "Start Session"
        case "planning":
            return "Start Review"
        case "creativity":
            return "Spark Idea"
        case "business", "strategy":
            return "Open Map"
        default:
            return "Start"
        }
    }
}

struct CoachCardSkeleton: View {
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray5))
                    .frame(width: 56, height: 56)
                
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 20)
                        .frame(maxWidth: 200)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 12)
                        .frame(maxWidth: 80)
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 14)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 14)
                    .frame(maxWidth: 250)
            }
            
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))
                .frame(height: 48)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}
