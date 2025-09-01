//
//  CategoryPicker.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/1/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  CategoryPicker.swift
//  PaycheckPlanner
//
//  Lightweight category selector that binds to a String.
//  - Presets with SF Symbols
//  - Custom entry fallback
//

import SwiftUI

struct CategoryPicker: View {
    @Binding var category: String

    // Preset categories (order matters)
    private let presets: [(name: String, icon: String)] = [
        ("Housing", "house.fill"),
        ("Utilities", "bolt.fill"),
        ("Internet", "wifi"),
        ("Phone", "phone.fill"),
        ("Transportation", "car.fill"),
        ("Insurance", "shield.fill"),
        ("Food", "cart.fill"),
        ("Subscriptions", "play.rectangle.on.rectangle.fill"),
        ("Entertainment", "sparkles.tv"),
        ("Health", "cross.case.fill"),
        ("Debt", "creditcard.fill"),
        ("Savings", "banknote.fill"),
        ("Education", "book.fill"),
        ("Pets", "pawprint.fill"),
        ("Personal", "person.fill"),
        ("Gifts", "gift.fill"),
        ("Misc", "tray.full.fill")
    ]

    @State private var isCustom: Bool = false
    @State private var customText: String = ""

    init(category: Binding<String>) {
        self._category = category
        // Initialize state from the bound value
        let initial = category.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let presetNames = Self.defaultPresetNames
        _isCustom = State(initialValue: initial.isEmpty || !presetNames.contains(initial))
        _customText = State(initialValue: initial)
    }

    var body: some View {
        Section {
            if isCustom {
                HStack {
                    Label("Category", systemImage: "tag.fill")
                    Spacer()
                    // Free-form entry
                }
                TextField("Custom category", text: $customText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .onChange(of: customText) { newValue in
                        category = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    }

                // Offer a quick way back to the preset list
                Button {
                    // if current custom text matches a preset, flip back and keep it selected
                    if Self.defaultPresetNames.contains(customText) {
                        isCustom = false
                        category = customText
                    } else {
                        isCustom = false
                    }
                } label: {
                    Label("Choose from list…", systemImage: "list.bullet")
                }
            } else {
                // Summary row that navigates to preset list
                NavigationLink {
                    PresetList(
                        presets: presets,
                        selection: $category,
                        onChooseCustom: {
                            isCustom = true
                            // keep whatever user had typed as starting value
                            customText = category
                        }
                    )
                    .navigationTitle("Category")
                } label: {
                    HStack {
                        Label("Category", systemImage: "tag.fill")
                        Spacer()
                        Text(category.isEmpty ? "Uncategorized" : category)
                            .foregroundStyle(.secondary)
                    }
                }

                // Also allow jumping straight to custom entry
                Button {
                    isCustom = true
                    customText = category
                } label: {
                    Label("Custom…", systemImage: "square.and.pencil")
                }
            }
        }
    }

    private static var defaultPresetNames: Set<String> {
        Set([
            "Housing","Utilities","Internet","Phone","Transportation",
            "Insurance","Food","Subscriptions","Entertainment","Health",
            "Debt","Savings","Education","Pets","Personal","Gifts","Misc"
        ])
    }

    // MARK: - Inner list

    private struct PresetList: View {
        let presets: [(name: String, icon: String)]
        @Binding var selection: String
        let onChooseCustom: () -> Void

        var body: some View {
            List {
                Section {
                    ForEach(presets, id: \.name) { item in
                        Button {
                            selection = item.name
                        } label: {
                            HStack {
                                Image(systemName: item.icon)
                                    .frame(width: 20)
                                    .foregroundStyle(.secondary)
                                Text(item.name)
                                Spacer()
                                if selection == item.name {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        onChooseCustom()
                    } label: {
                        Label("Custom…", systemImage: "square.and.pencil")
                    }
                }
            }
        }
    }
}
