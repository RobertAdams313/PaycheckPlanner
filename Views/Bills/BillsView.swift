//
//  BillsView.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import SwiftData

struct BillsView: View {
    @State private var showingAddBill = false

    var body: some View {
        NavigationStack {
            BillsListView()
                .navigationTitle("Bills")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showingAddBill = true } label: {
                            Label("Add", systemImage: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingAddBill) { BillEditorView() }
        }
    }
}
