//
//  ErrorHandler.swift
//  Simon
//
//  Created on Day 19-21: Polish + Edge Cases
//

import Foundation
import Combine

enum AppError: LocalizedError {
    case network(NetworkError)
    case api(APIError)
    case auth(AuthenticationError)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .network(let error):
            return error.localizedDescription
        case .api(let error):
            return error.localizedDescription
        case .auth(let error):
            return error.localizedDescription
        case .unknown(let error):
            return error.localizedDescription
        }
    }
    
    var userMessage: String {
        switch self {
        case .network(.offline):
            return "No internet connection. Please check your network."
        case .network(.timeout):
            return "Request timed out. Please try again."
        case .api(.proRequired):
            return "This feature requires Simon Pro."
        case .api(.httpError(429)):
            return "Too many requests. Please wait a moment."
        case .api(.httpError(let code)) where code == 401:
            return "Session expired. Please sign in again."
        case .api(.httpError(let code)) where code >= 500:
            return "Server error. Please try again later."
        case .auth(.notSignedIn):
            return "Please sign in to continue."
        case .auth(.invalidToken):
            return "Session expired. Please sign in again."
        default:
            return "Something went wrong. Please try again."
        }
    }
    
    var shouldShowPaywall: Bool {
        if case .api(.proRequired) = self {
            return true
        }
        return false
    }
    
    var shouldReauthenticate: Bool {
        switch self {
        case .api(.httpError(401)):
            return true
        case .auth(.notSignedIn), .auth(.invalidToken):
            return true
        default:
            return false
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .network(.timeout), .network(.offline):
            return true
        case .api(.httpError(let code)) where code >= 500:
            return true
        default:
            return false
        }
    }
}

enum NetworkError: LocalizedError {
    case offline
    case timeout
    case connectionLost
    
    var errorDescription: String? {
        switch self {
        case .offline:
            return "No internet connection"
        case .timeout:
            return "Request timed out"
        case .connectionLost:
            return "Connection lost"
        }
    }
}

@MainActor
final class ErrorHandler: ObservableObject {
    @Published var currentError: AppError?
    @Published var showPaywall: Bool = false
    @Published var shouldReauthenticate: Bool = false
    
    func handle(_ error: Error) {
        let appError = mapError(error)
        currentError = appError
        
        if appError.shouldShowPaywall {
            showPaywall = true
        }
        
        if appError.shouldReauthenticate {
            shouldReauthenticate = true
        }
        
        // Log error for debugging
        print("Error handled: \(appError.localizedDescription)")
    }
    
    private func mapError(_ error: Error) -> AppError {
        if let apiError = error as? APIError {
            return .api(apiError)
        } else if let authError = error as? AuthenticationError {
            return .auth(authError)
        } else if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .network(.offline)
            case .timedOut:
                return .network(.timeout)
            default:
                return .unknown(error)
            }
        } else {
            return .unknown(error)
        }
    }
    
    func clear() {
        currentError = nil
        showPaywall = false
        shouldReauthenticate = false
    }
}
