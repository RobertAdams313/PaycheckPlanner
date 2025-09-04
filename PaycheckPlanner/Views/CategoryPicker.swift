//
//  CategoryPicker.swift
//  PaycheckPlanner
//
//  HIG-compliant: Menu for quick picks (short), Sheet for full list.
//  Presets + Recents with checkmarks; “Custom…” opens a focused entry.
//  Recents persisted via @AppStorage. iOS 17-safe onChange.
//
import SwiftUI

struct CategoryPicker: View {
    @Binding var category: String

    // MARK: Presets (order matters; short, familiar names)
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
    private static let presetNames = Set([
        "Housing","Utilities","Internet","Phone","Transportation",
        "Insurance","Food","Subscriptions","Entertainment","Health",
        "Debt","Savings","Education","Pets","Personal","Gifts","Misc"
    ])

    // MARK: State
    @State private var showListSheet = false
    @State private var showCustomSheet = false
    @State private var customText: String = ""
    @State private var searchText: String = ""

    // Persist recent custom categories (top N)
    @AppStorage("pp_category_recents") private var recentsBlob: Data = Data()
    private let recentsLimit = 8
    private let quickRecentsLimit = 4 // HIG: keep menus short

    init(category: Binding<String>) {
        self._category = category
        _customText = State(initialValue: category.wrappedValue)
    }

    // MARK: Body

    var body: some View {
        Section {
            Menu {
                // Quick Recents (short list)
                if !recents.isEmpty {
                    Section("Recents") {
                        ForEach(Array(recents.prefix(quickRecentsLimit)), id: \.self) { item in
                            Button {
                                pick(item)
                            } label: {
                                HStack {
                                    Image(systemName: "clock.fill")
                                    Text(item)
                                    if category == item { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    }
                }

                // Full chooser
                Button {
                    searchText = ""
                    showListSheet = true
                } label: {
                    Label("Choose from List…", systemImage: "list.bullet")
                }

                // Custom launcher
                Button {
                    customText = category
                    showCustomSheet = true
                } label: {
                    Label("Custom…", systemImage: "square.and.pencil")
                }
            } label: {
                HStack {
                    Label("Category", systemImage: "tag.fill")
                    Spacer()
                    Text(category.isEmpty ? "Uncategorized" : category)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .contentShape(Rectangle())
            }
            .menuIndicator(.visible)

        }
        // Full selector sheet (Recents + Presets)
        .sheet(isPresented: $showListSheet) {
            NavigationStack {
                List {
                    if !recents.isEmpty {
                        Section("Recents") {
                            ForEach(recents, id: \.self) { item in
                                SelectRow(
                                    name: item,
                                    icon: "clock.fill",
                                    selected: category == item
                                ) { pickAndDismiss(item) }
                            }
                            // HIG: destructive action inside section, not the menu
                            Button(role: .destructive) { clearRecents() } label: {
                                Label("Clear Recents", systemImage: "trash")
                            }
                        }
                    }

                    Section("Common Categories") {
                        ForEach(filteredPresets, id: \.name) { p in
                            SelectRow(
                                name: p.name,
                                icon: p.icon,
                                selected: category == p.name
                            ) { pickAndDismiss(p.name) }
                        }
                    }

                    Section("Custom") {
                        Button {
                            customText = category
                            showCustomSheet = true
                        } label: {
                            Label("Add Custom…", systemImage: "plus")
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search categories")
                .navigationTitle("Category")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showListSheet = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .scrollDismissesKeyboard(.interactively)
        }

        // Custom entry sheet
        .sheet(isPresented: $showCustomSheet) {
            NavigationStack {
                Form {
                    Section("Custom Category") {
                        TextField("Enter category", text: $customText)
                            .modifier(NameAutoCapModifier(text: $customText))
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit { saveCustomAndDismiss() }
                    }
                }
                .navigationTitle("Custom Category")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showCustomSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveCustomAndDismiss() }
                            .disabled(customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: Derived

    private var filteredPresets: [(name: String, icon: String)] {
        guard !searchText.isEmpty else { return presets }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return presets.filter { $0.name.lowercased().contains(q) }
    }

    private var recents: [String] {
        guard !recentsBlob.isEmpty else { return [] }
        return (try? JSONDecoder().decode([String].self, from: recentsBlob)) ?? []
    }

    // MARK: Actions

    private func pick(_ name: String) {
        category = name
        if !Self.presetNames.contains(name) { addRecent(name) }
    }

    private func pickAndDismiss(_ name: String) {
        pick(name)
        showListSheet = false
    }

    private func saveCustomAndDismiss() {
        let trimmed = customText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        category = trimmed
        addRecent(trimmed)
        showCustomSheet = false
        showListSheet = false
    }

    // MARK: Recents storage

    private func saveRecents(_ items: [String]) {
        if let data = try? JSONEncoder().encode(items) {
            recentsBlob = data
        }
    }

    private func addRecent(_ item: String) {
        let key = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !Self.presetNames.contains(key) else { return }
        var list = recents
        list.removeAll { $0.caseInsensitiveCompare(key) == .orderedSame }
        list.insert(key, at: 0)
        if list.count > recentsLimit { list = Array(list.prefix(recentsLimit)) }
        saveRecents(list)
    }

    private func clearRecents() { saveRecents([]) }
}

// MARK: - Row

private struct SelectRow: View {
    let name: String
    let icon: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(name)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
    }
}
