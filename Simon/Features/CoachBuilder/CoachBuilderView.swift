//
//  CoachBuilderView.swift
//  Simon
//
//  Created on 2026-01-19.
//

import SwiftUI

struct CoachBuilderView: View {
    @StateObject private var vm: CoachBuilderViewModel
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    
    init(vm: CoachBuilderViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                ProgressView(value: Double(vm.currentStep + 1), total: Double(vm.totalSteps))
                    .tint(theme.accentPrimary)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                
                // Step content
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        stepContent
                    }
                    .padding(16)
                }
                
                // Navigation buttons
                VStack(spacing: 12) {
                    if let errorMessage = vm.errorMessage {
                        Text(errorMessage)
                            .font(theme.font(13))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    HStack(spacing: 12) {
                        if vm.currentStep > 0 {
                            Button(action: { vm.previousStep() }) {
                                Text("Back")
                                    .font(theme.font(17, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                            }
                            .buttonStyle(.bordered)
                            .tint(theme.accentPrimary)
                        }
                        
                        if vm.isLastStep {
                            Button(action: { Task { await vm.save() } }) {
                                if vm.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Save")
                                        .font(theme.font(17, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(theme.accentPrimary)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .disabled(!vm.canProceed || vm.isLoading)
                            
                            Button(action: { Task { await vm.publish() } }) {
                                if vm.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    HStack(spacing: 4) {
                                        Text("Publish")
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 12))
                                    }
                                    .font(theme.font(17, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(theme.accentMuted)
                            .foregroundColor(theme.accentPrimary)
                            .cornerRadius(12)
                            .disabled(!vm.canProceed || vm.isLoading)
                        } else {
                            Button(action: { vm.nextStep() }) {
                                Text("Next")
                                    .font(theme.font(17, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                            }
                            .background(theme.accentPrimary)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .disabled(!vm.canProceed)
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Create Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $vm.showPaywall) {
            PaywallView()
        }
    }
    
    @ViewBuilder
    private var stepContent: some View {
        switch vm.currentStep {
        case 0:
            step1NameAndPromise
        case 1:
            step2StyleAndTone
        case 2:
            step3Framework
        case 3:
            step4Guardrails
        default:
            EmptyView()
        }
    }
    
    private var step1NameAndPromise: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Name your coach")
                .font(theme.font(28, weight: .bold))
            
            Text("Give it a clear name and promise")
                .font(theme.font(15))
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(theme.font(13, weight: .semibold))
                    .foregroundColor(.secondary)
                
                TextField("e.g., Focus Sprint Coach", text: $vm.draft.name)
                    .font(theme.font(15))
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Promise")
                    .font(theme.font(13, weight: .semibold))
                    .foregroundColor(.secondary)
                
                TextField("What will this coach help with?", text: $vm.draft.promise, axis: .vertical)
                    .font(theme.font(15))
                    .lineLimit(2...3)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
        }
    }
    
    private var step2StyleAndTone: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose a style")
                    .font(theme.font(28, weight: .bold))
                
                Text("How should your coach communicate?")
                    .font(theme.font(15))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                ForEach(CoachDraft.CoachStyle.allCases, id: \.self) { style in
                    Button(action: { vm.draft.style = style }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(style.displayName)
                                    .font(theme.font(17, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text(style.description)
                                    .font(theme.font(13))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: vm.draft.style == style ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(vm.draft.style == style ? theme.accentPrimary : .secondary)
                                .font(.system(size: 24))
                        }
                        .padding(16)
                        .background(vm.draft.style == style ? theme.accentTint : Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(vm.draft.style == style ? theme.accentPrimary : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Tone")
                    .font(theme.font(17, weight: .semibold))
                
                HStack {
                    Text("Gentle")
                        .font(theme.font(13))
                        .foregroundColor(.secondary)
                    
                    Slider(value: $vm.draft.tone, in: 0...1)
                        .tint(theme.accentPrimary)
                    
                    Text("Intense")
                        .font(theme.font(13))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var step3Framework: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Pick a framework")
                    .font(theme.font(28, weight: .bold))
                
                Text("What structure should guide the coaching?")
                    .font(theme.font(15))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                ForEach(CoachDraft.CoachFramework.allCases, id: \.self) { framework in
                    Button(action: { vm.draft.framework = framework }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(framework.displayName)
                                    .font(theme.font(17, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text(framework.description)
                                    .font(theme.font(13))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: vm.draft.framework == framework ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(vm.draft.framework == framework ? theme.accentPrimary : .secondary)
                                .font(.system(size: 24))
                        }
                        .padding(16)
                        .background(vm.draft.framework == framework ? theme.accentTint : Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(vm.draft.framework == framework ? theme.accentPrimary : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var step4Guardrails: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Set guardrails")
                    .font(theme.font(28, weight: .bold))
                
                Text("Optional rules to guide behavior")
                    .font(theme.font(15))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                ForEach(CoachDraft.Guardrail.allCases, id: \.self) { guardrail in
                    Button(action: { vm.toggleGuardrail(guardrail) }) {
                        HStack {
                            Text(guardrail.displayName)
                                .font(theme.font(15))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: vm.draft.guardrails.contains(guardrail) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(vm.draft.guardrails.contains(guardrail) ? theme.accentPrimary : .secondary)
                                .font(.system(size: 24))
                        }
                        .padding(12)
                        .background(vm.draft.guardrails.contains(guardrail) ? theme.accentTint : Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
