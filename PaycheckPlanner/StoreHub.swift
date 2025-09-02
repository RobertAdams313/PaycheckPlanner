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
//  Created by Rob on 8/24/25.
//  Updated on 9/1/25
//

import Foundation
import SwiftData

/// Central place to build and manage SwiftData containers for the app and previews.
final class StoreHub {

    // MARK: - Singleton
    static let shared = StoreHub()
    private init() {}

    // MARK: - Cached containers (safe, non-throwing, property-style)
    /// iCloud-backed (CloudKit private DB). Falls back to in-memory preview if construction fails.
    lazy var iCloudContainer: ModelContainer = {
        (try? buildICloudContainer()) ?? Self.previewContainer()
    }()

    /// Local-only (no CloudKit). Falls back to in-memory preview if construction fails.
    lazy var localContainer: ModelContainer = {
        (try? buildLocalContainer()) ?? Self.previewContainer()
    }()

    // MARK: - Throwing builders (instance)
    func buildICloudContainer() throws -> ModelContainer {
        try Self.makeContainer(
            models: Self.appModels(),
            inMemory: false,
            cloudKitDatabase: .private("iCloud.com.robadams.PaycheckPlanner") // <- your CK container ID
        )
    }

    func buildLocalContainer() throws -> ModelContainer {
        try Self.makeContainer(
            models: Self.appModels(),
            inMemory: false,
            cloudKitDatabase: .none
        )
    }

    // MARK: - Throwing builders (static conveniences)
    static func iCloudContainer() throws -> ModelContainer {
        try Self.shared.buildICloudContainer()
    }

    static func localContainer() throws -> ModelContainer {
        try Self.shared.buildLocalContainer()
    }

    // MARK: - App/Preview helpers
    static func liveContainer() throws -> ModelContainer {
        try makeContainer(models: appModels(), inMemory: false, cloudKitDatabase: .none)
    }

    static func previewContainer() -> ModelContainer {
        let schema = Schema(appModels())
        let cfg = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return (try? ModelContainer(for: schema, configurations: cfg)) ?? {
            let empty = Schema([])
            let emptyCfg = ModelConfiguration(schema: empty, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            return try! ModelContainer(for: empty, configurations: emptyCfg)
        }()
    }

    // MARK: - Core factory
    /// Build a `ModelContainer` from an **array** of model types (use Schema to avoid variadic issues).
    static func makeContainer(
        models: [any PersistentModel.Type],
        inMemory: Bool = false,
        cloudKitDatabase: ModelConfiguration.CloudKitDatabase = .none
    ) throws -> ModelContainer {

        let schema = Schema(models)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: cloudKitDatabase
        )
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: - Single source of truth for all @Model types
    static func appModels() -> [any PersistentModel.Type] {
        [
            IncomeSource.self,
            IncomeSchedule.self,
            Bill.self,
            PaySchedule.self
        ]
    }
}
