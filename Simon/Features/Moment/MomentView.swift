//
//  MomentView.swift
//  Simon
//
//  Created on Day 12-14: Moment + Router Agent
//

import SwiftUI

struct MomentView: View {
    @StateObject private var vm: MomentViewModel
    @EnvironmentObject private var theme: ThemeStore
    
    init(vm: MomentViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Need guidance right now?")
                            .font(theme.font(28, weight: .bold))
                        
                        Text("Pick a template or describe what's on your mind.")
                            .font(theme.font(15))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
                    // Freeform Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Or just tell me what's up")
                            .font(theme.font(17, weight: .semibold))
                            .padding(.horizontal, 16)
                        
                        VStack(spacing: 0) {
                            TextEditor(text: $vm.freeformInput)
                                .font(theme.font(15))
                                .frame(minHeight: 100)
                                .padding(12)
                                .scrollContentBackground(.hidden)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            
                            if !vm.freeformInput.isEmpty {
                                Button(action: { vm.startFreeform() }) {
                                    HStack {
                                        Spacer()
                                        if vm.isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        } else {
                                            Text("Start")
                                                .font(theme.font(17, weight: .semibold))
                                        }
                                        Spacer()
                                    }
                                    .frame(height: 52)
                                    .background(theme.accentPrimary)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .disabled(vm.isLoading)
                                .padding(.top, 12)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(height: 1)
                        
                        Text("or")
                            .font(theme.font(13))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                        
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 16)
                    
                    // Templates
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick templates")
                            .font(theme.font(17, weight: .semibold))
                            .padding(.horizontal, 16)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(vm.templates) { template in
                                TemplateCard(
                                    template: template,
                                    isLoading: vm.isLoading && vm.selectedTemplate?.id == template.id
                                ) {
                                    vm.startTemplate(template)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Error message
                    if let errorMessage = vm.errorMessage {
                        Text(errorMessage)
                            .font(theme.font(13))
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                    }
                    
                    // Usage info
                    if !vm.isPro {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                            
                            Text("\(vm.remainingMoments) moments left today")
                                .font(theme.font(13))
                            
                            Spacer()
                            
                            Button("Upgrade") {
                                vm.showPaywall = true
                            }
                            .font(theme.font(13, weight: .semibold))
                            .foregroundColor(theme.accentPrimary)
                        }
                        .padding(12)
                        .background(theme.accentTint)
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Moment")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $vm.showPaywall) {
            PaywallView()
        }
        .navigationDestination(isPresented: $vm.navigateToChat) {
            if let sessionId = vm.createdSessionId,
               let coachName = vm.createdCoachName {
                ChatView(viewModel: vm.createChatViewModel(sessionId: sessionId, coachName: coachName))
            }
        }
        .task {
            await vm.loadRemainingMoments()
        }
    }
}

struct TemplateCard: View {
    let template: MomentTemplate
    let isLoading: Bool
    let action: () -> Void
    
    @EnvironmentObject private var theme: ThemeStore
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: template.icon)
                    .font(.system(size: 24))
                    .foregroundColor(theme.accentPrimary)
                    .frame(width: 32, height: 32)
                
                Text(template.title)
                    .font(theme.font(15, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Text(template.description)
                    .font(theme.font(13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: theme.accentPrimary))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}
