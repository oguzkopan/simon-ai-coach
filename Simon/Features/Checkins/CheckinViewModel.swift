import Foundation
import SwiftUI
import Combine

@MainActor
class CheckinViewModel: ObservableObject {
    @Published var checkins: [Checkin] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiClient: SimonAPIClient
    
    init(apiClient: SimonAPIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - Load Checkins
    
    func loadCheckins() async {
        isLoading = true
        errorMessage = nil
        
        do {
            checkins = try await apiClient.listCheckins()
        } catch {
            errorMessage = "Failed to load check-ins: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Schedule Checkin
    
    func scheduleCheckin(coachId: String, cadence: CheckinCadence, channel: CheckinChannel) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await apiClient.scheduleCheckin(
                coachId: coachId,
                cadence: cadence,
                channel: channel.rawValue
            )
            
            // Reload checkins after scheduling
            await loadCheckins()
            return true
        } catch {
            errorMessage = "Failed to schedule check-in: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    // MARK: - Update Checkin
    
    func updateCheckin(id: String, updates: [String: Any]) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            try await apiClient.updateCheckin(id: id, updates: updates)
            
            // Reload checkins after update
            await loadCheckins()
            return true
        } catch {
            errorMessage = "Failed to update check-in: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    // MARK: - Delete Checkin
    
    func deleteCheckin(id: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            try await apiClient.deleteCheckin(id: id)
            
            // Remove from local list
            checkins.removeAll { $0.id == id }
            isLoading = false
            return true
        } catch {
            errorMessage = "Failed to delete check-in: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    // MARK: - Toggle Checkin Status
    
    func toggleCheckinStatus(id: String, currentStatus: String) async {
        let newStatus = currentStatus == "active" ? "paused" : "active"
        _ = await updateCheckin(id: id, updates: ["status": newStatus])
    }
}


// MARK: - SimonAPIClient Extension for Checkins

extension SimonAPIClient {
    func listCheckins() async throws -> [Checkin] {
        let url = baseURL.appendingPathComponent("/v1/checkins")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let token = try await AuthenticationManager.shared.idToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Checkin].self, from: data)
    }
    
    func scheduleCheckin(coachId: String, cadence: CheckinCadence, channel: String) async throws -> String {
        let url = baseURL.appendingPathComponent("/v1/checkins")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let token = try await AuthenticationManager.shared.idToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = [
            "coach_id": coachId,
            "channel": channel,
            "cadence": [
                "kind": cadence.kind,
                "hour": cadence.hour,
                "minute": cadence.minute
            ]
        ]
        
        // Add optional fields
        if let weekdays = cadence.weekdays {
            var cadenceDict = body["cadence"] as! [String: Any]
            cadenceDict["weekdays"] = weekdays
            body["cadence"] = cadenceDict
        }
        
        if let cron = cadence.cron {
            var cadenceDict = body["cadence"] as! [String: Any]
            cadenceDict["cron"] = cron
            body["cadence"] = cadenceDict
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["checkin_id"] as? String ?? ""
    }
    
    func updateCheckin(id: String, updates: [String: Any]) async throws {
        let url = baseURL.appendingPathComponent("/v1/checkins/\(id)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let token = try await AuthenticationManager.shared.idToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body = ["updates": updates]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    func deleteCheckin(id: String) async throws {
        let url = baseURL.appendingPathComponent("/v1/checkins/\(id)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let token = try await AuthenticationManager.shared.idToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
}
