//
//  CardKit.swift
//  PaycheckPlanner
//
//  Shared card components used across Plan / Insights / Settings, etc.
//  - Keeps existing API: CardContainer { ... } used in your views
//  - No ScrollView inside cards (safe for List rows)
//  - Lightweight, HIG-friendly material surface with subtle stroke
//

import SwiftUI

// MARK: - Card Surface Container (keeps your existing usage)
/// A material card surface with comfy padding and rounded corners.
/// Safe to place inside List rows (no internal ScrollView).
struct CardContainer<Content: View>: View {
    private let horizontal: CGFloat
    private let vertical: CGFloat
    private let cornerRadius: CGFloat
    private let content: Content

    init(
        horizontal: CGFloat = 12,
        vertical: CGFloat = 8,
        cornerRadius: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.horizontal = horizontal
        self.vertical = vertical
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.07), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - FrostCard (alias – for places you used FrostCard previously)
/// Backward-compatible alias that simply wraps CardContainer.
struct FrostCard<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        CardContainer { content }
    }
}

// MARK: - Card Stack Helpers

/// A vertical stack that spaces cards and keeps them within a max width.
/// Useful on screens that are NOT Lists (e.g., Settings screens using ScrollView).
struct CardStack<Content: View>: View {
    let maxWidth: CGFloat
    private let spacing: CGFloat
    private let content: Content

    init(
        maxWidth: CGFloat = 720,
        spacing: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.maxWidth = maxWidth
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        VStack(spacing: spacing) {
            content
        }
        .frame(maxWidth: maxWidth)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

/// A convenience container for pages that are NOT using List, to provide
/// a grouped background and centered column of cards.
/// Example:
/// ScrollCardPage {
///   CardContainer { ... }
///   CardContainer { ... }
/// }
struct ScrollCardPage<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        ScrollView {
            CardStack { content }
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Press / Hover Feedback

struct PressCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

// MARK: - Utilities

extension View {
    /// Apply a subtle divider inset typically used between card rows.
    func cardRowDividerLeadingInset(_ inset: CGFloat = 4) -> some View {
        self
            .overlay(alignment: .bottomLeading) {
                Divider()
                    .padding(.leading, inset)
                    .opacity(0.9)
            }
    }
}
// MARK: - List Row Helpers

private struct CardListRowModifier: ViewModifier {
    let top: CGFloat
    let leading: CGFloat
    let bottom: CGFloat
    let trailing: CGFloat

    func body(content: Content) -> some View {
        content
            .listRowInsets(EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing))
            .listRowBackground(Color.clear)
    }
}

public extension View {
    /// Standard insets + clear background for card rows inside Lists.
    func cardListRowInsets(
        top: CGFloat = 4,
        leading: CGFloat = 16,
        bottom: CGFloat = 4,
        trailing: CGFloat = 16
    ) -> some View {
        modifier(CardListRowModifier(top: top, leading: leading, bottom: bottom, trailing: trailing))
    }
}
