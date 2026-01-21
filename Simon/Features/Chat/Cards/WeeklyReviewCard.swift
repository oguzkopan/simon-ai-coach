import SwiftUI

// MARK: - Models

struct WeeklyReview {
    let wins: [String]
    let misses: [String]
    let rootCauses: [String]
    let nextWeekFocus: [String]
    let commitments: [Commitment]
}

struct Commitment: Identifiable {
    let id: String
    let text: String
    let createdAt: Date
    let status: String
    
    init(id: String = UUID().uuidString, text: String, createdAt: Date = Date(), status: String = "active") {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.status = status
    }
}

// MARK: - View

struct WeeklyReviewCard: View {
    let review: WeeklyReview
    
    var body: some View {
        SCard {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                header
                
                // Wins
                if !review.wins.isEmpty {
                    reviewSection(
                        title: "Wins",
                        icon: "star.fill",
                        color: .green,
                        items: review.wins
                    )
                }
                
                // Misses
                if !review.misses.isEmpty {
                    reviewSection(
                        title: "Misses",
                        icon: "xmark.circle",
                        color: .orange,
                        items: review.misses
                    )
                }
                
                // Root Causes
                if !review.rootCauses.isEmpty {
                    reviewSection(
                        title: "Root Causes",
                        icon: "magnifyingglass",
                        color: .blue,
                        items: review.rootCauses
                    )
                }
                
                // Next Week Focus
                if !review.nextWeekFocus.isEmpty {
                    reviewSection(
                        title: "Next Week Focus",
                        icon: "arrow.forward.circle.fill",
                        color: .purple,
                        items: review.nextWeekFocus
                    )
                }
                
                // Commitments
                if !review.commitments.isEmpty {
                    commitmentsSection
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Image(systemName: "calendar.badge.checkmark")
                .font(.title2)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Weekly Review")
                    .font(.headline)
                
                Text(Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Review Section
    
    private func reviewSection(title: String, icon: String, color: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(item)
                            .font(.body)
                    }
                }
            }
        }
    }
    
    // MARK: - Commitments Section
    
    private var commitmentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(.accentColor)
                Text("Commitments")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(review.commitments) { commitment in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.accentColor)
                        Text(commitment.text)
                            .font(.body)
                    }
                    .padding(12)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
}
