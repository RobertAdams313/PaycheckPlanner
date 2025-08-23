//
//  LiquidGlassToggleModifier.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI

/// App-wide key for the effect toggle
public let kLiquidGlassEnabledKey = "liquidGlassEnabled"

/// Apply this modifier to any root view.
/// It only renders on iOS 26+ and when the toggle is ON.
struct LiquidGlassToggleModifier: ViewModifier {
    @AppStorage(kLiquidGlassEnabledKey) private var enabled: Bool = true
    func body(content: Content) -> some View {
        content.background(
            Group {
                if #available(iOS 26, *), enabled {
                    LiquidGlassBackground()
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        )
    }
}

extension View {
    /// Adds the Liquid Glass background behind the current view when available and enabled.
    func liquidGlassIfEnabled() -> some View { modifier(LiquidGlassToggleModifier()) }
}

struct LiquidGlassBackground: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AnimatedBubbles(reduceMotion: reduceMotion)
                .blur(radius: 40)
                .blendMode(.plusLighter)
                .opacity(scheme == .dark ? 0.35 : 0.28)

            Rectangle().fill(.ultraThinMaterial)
                .opacity(scheme == .dark ? 0.85 : 0.95)
        }
        .compositingGroup()
    }
}

/// Lightweight animated blobs using Canvas + TimelineView.
/// Respects Reduce Motion; very conservative for performance.
private struct AnimatedBubbles: View {
    var reduceMotion: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let count = 6
                let R = min(size.width, size.height) * 0.35
                let radius = max(120, min(size.width, size.height) * 0.22)
                let speed = reduceMotion ? 0.0 : 0.12

                for i in 0..<count {
                    let phase = (Double(i) * .pi * 2.0 / Double(count))
                    let x = size.width  * 0.5 + CGFloat(cos(t * speed + phase)) * R
                    let y = size.height * 0.5 + CGFloat(sin(t * (speed * 0.85) + phase * 0.9)) * R

                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    let path = Path(ellipseIn: rect)

                    let c1 = Color(red: 0.95, green: 0.20, blue: 0.25, opacity: 0.35)
                    let c2 = Color(red: 0.95, green: 0.40, blue: 0.55, opacity: 0.20)

                    ctx.addFilter(.alphaThreshold(min: 0.15, color: .clear))
                    ctx.addFilter(.blur(radius: 30))
                    ctx.fill(
                        path,
                        with: .linearGradient(
                            .init(colors: [c1, c2]),
                            startPoint: CGPoint(x: rect.minX, y: rect.minY),
                            endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                        )
                    )
                }
            }
        }
    }
}
