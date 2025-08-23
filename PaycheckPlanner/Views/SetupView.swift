//
//  SetupView.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 8/23/25.
//


import SwiftUI
import SwiftData

struct SetupView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 56))
                .padding(.bottom, 8)

            Text("Set up your pay schedule")
                .font(.title2).bold()

            Text("We’ll use this to determine which bills fall into each paycheck.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button {
                let s = PaySchedule()
                context.insert(s)
            } label: {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
        }
        .padding()
    }
}
