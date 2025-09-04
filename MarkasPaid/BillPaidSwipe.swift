//  BillPaidSwipe.swift
//  PaycheckPlanner
//
//  Reusable trailing swipe action (List-only) to toggle a bill's paid state for a given period.
//  Label is icon-only (no "Mark Paid" text).
//

import SwiftUI
import SwiftData

struct BillPaidSwipeModifier: ViewModifier {
    let bill: Bill
    let periodKey: Date
    @Environment(\.modelContext) private var context

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button {
                    let gen = UINotificationFeedbackGenerator()
                    gen.notificationOccurred(.success)
                    withAnimation(.snappy) {
                        _ = MarkAsPaidService.togglePaid(bill, on: periodKey, in: context)
                    }
                } label: {
                    Image(systemName: "checkmark.circle.fill") // icon only
                }
                .labelStyle(.iconOnly) // <- ensures no text is shown
                .tint(.green)
            }
    }
}

extension View {
    /// Attach trailing swipe to toggle paid/unpaid for this bill in a period (works in List rows).
    func billPaidSwipe(bill: Bill, periodKey: Date) -> some View {
        modifier(BillPaidSwipeModifier(bill: bill, periodKey: periodKey))
    }
}
