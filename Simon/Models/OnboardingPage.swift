import Foundation

struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

extension OnboardingPage {
    static let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "brain.head.profile",
            title: "Get guidance at the right moment",
            description: "An intelligent system designed to help builders create better, without the noise."
        ),
        OnboardingPage(
            icon: "person.bubble",
            title: "Chat with expert coaches",
            description: "Browse specialized coaches or create your own. Get instant guidance tailored to your needs."
        ),
        OnboardingPage(
            icon: "lightbulb.fill",
            title: "Capture moments of clarity",
            description: "Need help right now? Use Moment to get quick guidance or work through what's on your mind."
        ),
        OnboardingPage(
            icon: "pin.fill",
            title: "Build systems that stick",
            description: "Pin valuable insights as systems with checklists, schedules, and metrics to track your progress."
        )
    ]
}
