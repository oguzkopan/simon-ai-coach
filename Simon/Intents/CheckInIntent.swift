import Foundation
import AppIntents

struct CheckInIntent: AppIntent {
    static var title: LocalizedStringResource = "Check-in with Coach"
    
    static var description = IntentDescription("Start a quick coaching check-in session")
    
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        // Post notification to open check-in
        NotificationCenter.default.post(
            name: NSNotification.Name("OpenCheckIn"),
            object: nil
        )
        
        return .result()
    }
}
