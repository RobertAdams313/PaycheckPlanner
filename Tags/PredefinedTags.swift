//
//  TagDef.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import Foundation

struct TagDef: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let emoji: String
    let keywords: [String]
}

enum PredefinedTags {
    static let all: [TagDef] = [
        .init(name: "Housing",       emoji: "🏠", keywords: ["rent","mortgage","landlord","hoa"]),
        .init(name: "Utilities",     emoji: "🔌", keywords: ["electric","gas","water","internet","wifi","cable","utility"]),
        .init(name: "Phone",         emoji: "📱", keywords: ["phone","verizon","att","t-mobile","mobile","cell"]),
        .init(name: "Transportation",emoji: "🚗", keywords: ["car","auto","uber","lyft","fuel","gasoline","metro","transit","toll","parking","insurance (auto)"]),
        .init(name: "Insurance",     emoji: "🛡️", keywords: ["insurance","premium","geico","state farm","progressive","allstate"]),
        .init(name: "Food",          emoji: "🛒", keywords: ["grocery","supermarket","whole foods","trader joe","food","restaurant","doordash","ubereats","grubhub"]),
        .init(name: "Debt",          emoji: "💳", keywords: ["credit","loan","student","debt","payoff","minimum"]),
        .init(name: "Health",        emoji: "💊", keywords: ["medical","doctor","dentist","pharmacy","rx","health"]),
        .init(name: "Subscriptions", emoji: "🎬", keywords: ["netflix","spotify","hulu","max","prime","apple tv","icloud","subscription","subscr"]),
        .init(name: "Pets",          emoji: "🐾", keywords: ["pet","vet","chewy","dog","cat"]),
        .init(name: "Savings",       emoji: "💼", keywords: ["savings","investment","invest","ira","roth","brokerage"]),
        .init(name: "Taxes",         emoji: "🧾", keywords: ["tax","irs","state tax","property tax"]),
        .init(name: "Education",     emoji: "🎓", keywords: ["tuition","school","course","udemy","coursera"]),
        .init(name: "Entertainment", emoji: "🎮", keywords: ["game","steam","xbox","playstation","movie","concert","ticket"]),
        .init(name: "Travel",        emoji: "✈️", keywords: ["flight","hotel","airbnb","booking","travel","rental car"]),
        .init(name: "Misc",          emoji: "🧰", keywords: [])
    ]

    static func classify(name: String, fallback: String = "Misc") -> TagDef {
        let lower = name.lowercased()
        for tag in all where !tag.keywords.isEmpty {
            if tag.keywords.contains(where: { lower.contains($0) }) {
                return tag
            }
        }
        return all.first(where: { $0.name == fallback }) ?? .init(name: fallback, emoji: "🧰", keywords: [])
    }
}

extension Bill {
    /// Prefer manual category when set; else classify by name for Insights
    var insightsTag: TagDef {
        if !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let manual = PredefinedTags.all.first(where: { $0.name.caseInsensitiveCompare(category) == .orderedSame }) {
            return manual
        }
        return PredefinedTags.classify(name: name)
    }
}
