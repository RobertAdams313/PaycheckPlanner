//
//  SplashOverlay.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI

/// Short-lived overlay showing your app icon after launch.
/// (This complements the static Launch Screen storyboard.)
struct SplashOverlay: View {
    @State private var visible = true

    var body: some View {
        ZStack {
            if visible {
                Color(.systemBackground).ignoresSafeArea()
                Image("AppMark") // Add this image to your asset catalog
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .shadow(radius: 8)
                    .transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 650_000_000)
            withAnimation(.easeOut(duration: 0.25)) { visible = false }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
