import Foundation
import Combine
import UIKit
import PDFKit

// MARK: - Export Models

enum ExportFormat: String, Codable {
    case markdown
    case pdf
    case text
}

struct ExportRequest: Codable {
    let format: ExportFormat
    let payloadRef: PayloadRef
    let idempotencyKey: String
    
    enum CodingKeys: String, CodingKey {
        case format
        case payloadRef = "payload_ref"
        case idempotencyKey = "idempotency_key"
    }
}

struct PayloadRef: Codable {
    let type: String // "session", "plan", "system"
    let id: String
}

struct ExportResult: Codable {
    let status: String
    let filePath: String?
    
    enum CodingKeys: String, CodingKey {
        case status
        case filePath = "file_path"
    }
}

// MARK: - Export Error

enum ExportError: LocalizedError {
    case sessionNotFound
    case planNotFound
    case exportFailed(String)
    case unsupportedFormat
    
    var errorDescription: String? {
        switch self {
        case .sessionNotFound:
            return "Session not found"
        case .planNotFound:
            return "Plan not found"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .unsupportedFormat:
            return "Unsupported export format"
        }
    }
}

// MARK: - Export Manager

@MainActor
class ExportManager: ObservableObject {
    static let shared = ExportManager(apiClient: SimonAPIClient.shared)
    
    private let apiClient: SimonAPI
    
    init(apiClient: SimonAPI) {
        self.apiClient = apiClient
    }
    
    // MARK: - Session Export
    
    /// Export a session in the specified format
    func exportSession(sessionID: String, format: ExportFormat) async throws -> URL {
        // Fetch session data
        let sessionDetail = try await apiClient.getSession(id: sessionID)
        
        switch format {
        case .markdown:
            return try exportSessionAsMarkdown(sessionDetail: sessionDetail)
        case .pdf:
            return try exportSessionAsPDF(sessionDetail: sessionDetail)
        case .text:
            return try exportSessionAsText(sessionDetail: sessionDetail)
        }
    }
    
    /// Export session as Markdown
    private func exportSessionAsMarkdown(sessionDetail: SessionDetail) throws -> URL {
        var markdown = "# Coaching Session\n\n"
        markdown += "**Date:** \(formatDate(sessionDetail.session.createdAt))\n\n"
        markdown += "**Coach:** \(sessionDetail.session.coachID)\n\n"
        markdown += "---\n\n"
        
        // Add messages
        for message in sessionDetail.messages {
            let role = message.role.capitalized
            markdown += "### \(role)\n\n"
            markdown += "\(message.contentText)\n\n"
        }
        
        // Write to temporary file
        let fileName = "session_\(sessionDetail.session.id)_\(Date().timeIntervalSince1970).md"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        
        return fileURL
    }
    
    /// Export session as PDF
    private func exportSessionAsPDF(sessionDetail: SessionDetail) throws -> URL {
        // Create HTML content
        var html = """
        <html>
        <head>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; padding: 20px; }
                h1 { color: #333; }
                .message { margin: 20px 0; padding: 15px; border-radius: 8px; }
                .user { background-color: #e3f2fd; }
                .assistant { background-color: #f5f5f5; }
                .role { font-weight: bold; margin-bottom: 8px; }
                .content { line-height: 1.6; }
                .metadata { color: #666; font-size: 14px; margin-bottom: 20px; }
            </style>
        </head>
        <body>
            <h1>Coaching Session</h1>
            <div class="metadata">
                <p><strong>Date:</strong> \(formatDate(sessionDetail.session.createdAt))</p>
        """
        
        html += "<p><strong>Coach:</strong> \(sessionDetail.session.coachID)</p>"
        html += "</div><hr>"
        
        // Add messages
        for message in sessionDetail.messages {
            let roleClass = message.role == "user" ? "user" : "assistant"
            html += """
            <div class="message \(roleClass)">
                <div class="role">\(message.role.capitalized)</div>
                <div class="content">\(message.contentText.replacingOccurrences(of: "\n", with: "<br>"))</div>
            </div>
            """
        }
        
        html += "</body></html>"
        
        // Create PDF from HTML
        let printFormatter = UIMarkupTextPrintFormatter(markupText: html)
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(printFormatter, startingAtPageAt: 0)
        
        let pageSize = CGSize(width: 612, height: 792) // US Letter
        let pageMargins = UIEdgeInsets(top: 72, left: 72, bottom: 72, right: 72)
        
        let printableRect = CGRect(
            x: pageMargins.left,
            y: pageMargins.top,
            width: pageSize.width - pageMargins.left - pageMargins.right,
            height: pageSize.height - pageMargins.top - pageMargins.bottom
        )
        
        let paperRect = CGRect(origin: .zero, size: pageSize)
        renderer.setValue(NSValue(cgRect: paperRect), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")
        
        // Generate PDF data
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, paperRect, nil)
        
        for pageIndex in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: pageIndex, in: UIGraphicsGetPDFContextBounds())
        }
        
        UIGraphicsEndPDFContext()
        
        // Write to temporary file
        let fileName = "session_\(sessionDetail.session.id)_\(Date().timeIntervalSince1970).pdf"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try pdfData.write(to: fileURL)
        
        return fileURL
    }
    
    /// Export session as plain text
    private func exportSessionAsText(sessionDetail: SessionDetail) throws -> URL {
        var text = "COACHING SESSION\n"
        text += "================\n\n"
        text += "Date: \(formatDate(sessionDetail.session.createdAt))\n"
        text += "Coach: \(sessionDetail.session.coachID)\n"
        text += "\n" + String(repeating: "-", count: 50) + "\n\n"
        
        // Add messages
        for message in sessionDetail.messages {
            text += "\(message.role.uppercased()):\n"
            text += "\(message.contentText)\n\n"
        }
        
        // Write to temporary file
        let fileName = "session_\(sessionDetail.session.id)_\(Date().timeIntervalSince1970).txt"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try text.write(to: fileURL, atomically: true, encoding: .utf8)
        
        return fileURL
    }
    
    // MARK: - Plan Export
    
    /// Export a plan as Markdown
    func exportPlanAsMarkdown(plan: PlanCardPayload.PlanInfo) throws -> URL {
        var markdown = "# \(plan.title)\n\n"
        markdown += "**Objective:** \(plan.objective)\n\n"
        markdown += "**Horizon:** \(plan.horizon)\n\n"
        
        if !plan.milestones.isEmpty {
            markdown += "## Milestones\n\n"
            for (index, milestone) in plan.milestones.enumerated() {
                markdown += "\(index + 1). **\(milestone.label)**\n"
                if let dueDate = milestone.dueDateHint {
                    markdown += "   - Due: \(dueDate)\n"
                }
                if let metric = milestone.successMetric {
                    markdown += "   - Success: \(metric)\n"
                }
                markdown += "\n"
            }
        }
        
        if !plan.nextActions.isEmpty {
            markdown += "## Next Actions\n\n"
            for (index, action) in plan.nextActions.enumerated() {
                markdown += "\(index + 1). \(action)\n"
            }
        }
        
        // Write to temporary file
        let fileName = "plan_\(Date().timeIntervalSince1970).md"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        
        return fileURL
    }
    
    // MARK: - Share Sheet
    
    /// Present share sheet with the exported file
    func showShareSheet(fileURL: URL, from viewController: UIViewController) {
        let activityVC = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        
        // For iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        viewController.present(activityVC, animated: true)
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
