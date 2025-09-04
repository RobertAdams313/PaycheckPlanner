//  PaidChip.swift
//  PaycheckPlanner
//
//  Icon-only toggle chip used in BillsView rows.
//

import SwiftUI

struct PaidChip: View {
    let isPaid: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: isPaid ? "checkmark.circle.fill" : "circle")
                .imageScale(.large)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isPaid ? .green : .secondary) // ShapeStyle, not Color.tertiary
                .accessibilityLabel(isPaid ? "Mark Unpaid" : "Mark Paid")
        }
        .buttonStyle(.plain)
        .contentTransition(.symbolEffect(.replace))
    }
}
