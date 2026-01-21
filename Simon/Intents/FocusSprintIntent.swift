import Foundation
import AppIntents

struct FocusSprintIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Focus Sprint"
    
    static var description = IntentDescription("Start a focused work session with your coach")
    
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: "Duration (minutes)", default: 25)
    var duration: Int
    
    func perform() async throws -> some IntentResult {
        // Post notification to start focus sprint
        NotificationCenter.default.post(
            name: NSNotification.Name("StartFocusSprint"),
            object: nil,
            userInfo: ["duration": duration]
        )
        
        return .result()
    }
}
