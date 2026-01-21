//
//  SToast.swift
//  Simon
//
//  Created on Day 19-21: Polish + Edge Cases
//

import SwiftUI
import Combine

enum ToastType {
    case success
    case error
    case info
    case warning
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .info: return .blue
        case .warning: return .orange
        }
    }
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let type: ToastType
    let message: String
    let duration: TimeInterval
    
    init(type: ToastType, message: String, duration: TimeInterval = 3.0) {
        self.type = type
        self.message = message
        self.duration = duration
    }
}

struct SToast: View {
    let toast: ToastMessage
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.type.icon)
                .font(.system(size: 20))
                .foregroundColor(toast.type.color)
            
            Text(toast.message)
                .font(theme.font(15))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Toast Modifier

struct ToastModifier: ViewModifier {
    @Binding var toast: ToastMessage?
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if let toast = toast {
                VStack {
                    Spacer()
                    
                    SToast(toast: toast)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    self.toast = nil
                                }
                            }
                        }
                    
                    Spacer()
                        .frame(height: 16)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: toast)
            }
        }
    }
}

extension View {
    func toast(_ toast: Binding<ToastMessage?>) -> some View {
        modifier(ToastModifier(toast: toast))
    }
}

// MARK: - Toast Manager

@MainActor
class ToastManager: ObservableObject {
    @Published var currentToast: ToastMessage?
    
    func show(_ type: ToastType, message: String, duration: TimeInterval = 3.0) {
        currentToast = ToastMessage(type: type, message: message, duration: duration)
    }
    
    func showSuccess(_ message: String) {
        show(.success, message: message)
    }
    
    func showError(_ message: String) {
        show(.error, message: message)
    }
    
    func showInfo(_ message: String) {
        show(.info, message: message)
    }
    
    func showWarning(_ message: String) {
        show(.warning, message: message)
    }
}
