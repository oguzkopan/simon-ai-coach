//
//  STopBar.swift
//  Simon
//
//  Created on 2026-01-19.
//

import SwiftUI
import Combine

struct STopBar<Leading: View, Trailing: View>: View {
    let title: String
    let leading: Leading
    let trailing: Trailing
    
    @EnvironmentObject private var theme: ThemeStore
    
    init(
        title: String,
        @ViewBuilder leading: () -> Leading = { EmptyView() },
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.leading = leading()
        self.trailing = trailing()
    }
    
    var body: some View {
        HStack {
            leading
                .frame(width: ThemeTokens.minTapTarget, height: ThemeTokens.minTapTarget)
            
            Spacer()
            
            Text(title)
                .font(theme.sectionHeaderFont)
            
            Spacer()
            
            trailing
                .frame(width: ThemeTokens.minTapTarget, height: ThemeTokens.minTapTarget)
        }
        .padding(.horizontal, ThemeTokens.spacing16)
        .frame(height: ThemeTokens.minTapTarget)
    }
}
