//
//  DataStoreChoice.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/1/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  StoreHub.swift
//  PaycheckPlanner
//
//  Provides two SwiftData containers (iCloud + Local) and hands out the right ModelContext.
//

import SwiftUI
import SwiftData

enum DataStoreChoice: String, CaseIterable, Identifiable {
    case iCloud
    case local

    var id: String { rawValue }
    var title: String {
        switch self {
        case .iCloud: return "iCloud (sync across devices)"
        case .local:  return "On This iPhone/iPad"
        }
    }
}

@MainActor
final class StoreHub {
    static let shared = StoreHub()

    // MARK: - Containers
    // IMPORTANT: Keep this model list in sync with your app's models.
    private let models: [any PersistentModel.Type] = [
        IncomeSource.self,
        IncomeSchedule.self,
        Bill.self,
        PaySchedule.self
    ]

    let iCloudContainer: ModelContainer
    let localContainer: ModelContainer

    private init() {
        // iCloud-backed container (uses default CloudKit container for the app)
        iCloudContainer = try! ModelContainer(
            for: models,
            configurations: ModelConfiguration(
                "iCloud",
                cloudKitDatabase: .automatic
            )
        )

        // Local-only container (no CloudKit)
        localContainer = try! ModelContainer(
            for: models,
            configurations: ModelConfiguration(
                "Local",
                cloudKitDatabase: .none
            )
        )
    }

    // MARK: - Context selection
    func context(for choice: DataStoreChoice) -> ModelContext {
        switch choice {
        case .iCloud: return ModelContext(iCloudContainer)
        case .local:  return ModelContext(localContainer)
        }
    }
}
