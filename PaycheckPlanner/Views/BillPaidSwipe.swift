//
//  BillPaidSwipe.swift
//  PaycheckPlanner
//
//  Reusable swipe action to toggle a bill's paid state for a given period.
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
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    _ = MarkAsPaidService.togglePaid(bill, periodKey: periodKey, in: context)
                } label: {
                    Label("Mark Paid", systemImage: "checkmark.circle.fill")
                }
                .tint(.green)
            }
    }
}

extension View {
    /// Attach trailing swipe to toggle paid/unpaid for this bill and period.
    func billPaidSwipe(bill: Bill, periodKey: Date) -> some View {
        modifier(BillPaidSwipeModifier(bill: bill, periodKey: periodKey))
    }
}
