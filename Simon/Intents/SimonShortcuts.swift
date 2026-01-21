import Foundation
import AppIntents

struct SimonShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckInIntent(),
            phrases: [
                "Check in with \(.applicationName)",
                "Start a check-in with \(.applicationName)",
                "Talk to my coach in \(.applicationName)"
            ],
            shortTitle: "Check-in",
            systemImageName: "bubble.left.and.bubble.right"
        )
        
        AppShortcut(
            intent: FocusSprintIntent(),
            phrases: [
                "Start a focus sprint in \(.applicationName)",
                "Begin focus session in \(.applicationName)",
                "Start working in \(.applicationName)"
            ],
            shortTitle: "Focus Sprint",
            systemImageName: "timer"
        )
        
        AppShortcut(
            intent: LogWinIntent(),
            phrases: [
                "Log a win in \(.applicationName)",
                "Record accomplishment in \(.applicationName)",
                "Celebrate a win in \(.applicationName)"
            ],
            shortTitle: "Log Win",
            systemImageName: "star.fill"
        )
    }
}
