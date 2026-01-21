import Foundation
import AppIntents

struct LogWinIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Win"
    
    static var description = IntentDescription("Quickly log a win or accomplishment")
    
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: "What did you accomplish?")
    var accomplishment: String?
    
    func perform() async throws -> some IntentResult {
        // Post notification to log win
        NotificationCenter.default.post(
            name: NSNotification.Name("LogWin"),
            object: nil,
            userInfo: ["accomplishment": accomplishment ?? ""]
        )
        
        return .result()
    }
}
