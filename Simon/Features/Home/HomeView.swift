import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @EnvironmentObject private var theme: ThemeStore
    
    init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Browse")
                            .font(theme.font(28, weight: .bold))
                        Text("Pick a coach and start instantly.")
                            .font(theme.font(15))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
                    // Filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.categories, id: \.self) { category in
                                FilterChip(
                                    title: category,
                                    isSelected: viewModel.selectedCategory == category || (viewModel.selectedCategory == nil && category == "All"),
                                    action: { viewModel.selectCategory(category) }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Loading state
                    if viewModel.isLoading {
                        ForEach(0..<3, id: \.self) { _ in
                            CoachCardSkeleton()
                                .padding(.horizontal, 16)
                        }
                    }
                    // Error state
                    else if let errorMessage = viewModel.errorMessage {
                        VStack(spacing: 12) {
                            Text("Failed to load coaches")
                                .font(theme.font(17, weight: .semibold))
                            Text(errorMessage)
                                .font(theme.font(13))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Retry") {
                                Task {
                                    await viewModel.loadCoaches()
                                }
                            }
                            .font(theme.font(15, weight: .semibold))
                            .foregroundColor(theme.accentPrimary)
                        }
                        .padding(32)
                        .frame(maxWidth: .infinity)
                    }
                    // Coach list
                    else {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.coaches) { coach in
                                CoachCard(coach: coach) {
                                    viewModel.startCoach(coach)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.showSearch = true }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(theme.accentPrimary)
                    }
                }
            }
        }
        .task {
            if viewModel.coaches.isEmpty {
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
                .font(theme.font(13))
                .foregroundColor(isSelected ? .white : theme.accentPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? theme.accentPrimary : theme.accentTint)
                .cornerRadius(10)
        }
    }
}

struct CoachCard: View {
    let coach: Coach
    let action: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                // Icon
                Circle()
                    .fill(theme.accentTint)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(coach.title.prefix(1)))
                            .font(theme.font(15, weight: .semibold))
                            .foregroundColor(theme.accentPrimary)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(coach.title)
                        .font(theme.font(17, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(coach.promise)
                        .font(theme.font(15))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        ForEach(coach.tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(theme.font(11))
                                .foregroundColor(theme.accentPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(theme.accentTint)
                                .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        Text("Start")
                            .font(theme.font(13, weight: .semibold))
                            .foregroundColor(theme.accentPrimary)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

struct CoachCardSkeleton: View {
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 16)
                    .frame(maxWidth: 200)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 14)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 14)
                    .frame(maxWidth: 250)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}
