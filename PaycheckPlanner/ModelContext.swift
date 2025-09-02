//
//  ModelContext.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/1/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  ModelContext+Background.swift
//  PaycheckPlanner
//
//  Background helpers for SwiftData fetches/logging.
//

import Foundation
import SwiftData

extension ModelContext {
    /// Run a block on a detached background thread with a fresh ModelContext
    /// created from this context’s container. Use for non-UI work (probes, exports).
    ///
    /// - Note: `ModelContext.container` is a *throwing* getter, so this API is `throws`.
    ///         Call as: `try await context.background { bg in ... }`
    func background<T>(_ work: @escaping (ModelContext) throws -> T) async throws -> T {
        let container = try self.container
        return try await Task.detached(priority: .utility) {
            let bg = ModelContext(container)
            bg.autosaveEnabled = false
            return try work(bg)
        }.value
    }

    /// Convenience overload for non-throwing work closures.
    /// Lets you avoid `try` if your work doesn’t throw (you still need `try` for the container).
    func background<T>(_ work: @escaping (ModelContext) -> T) async throws -> T {
        let container = try self.container
        return await Task.detached(priority: .utility) {
            let bg = ModelContext(container)
            bg.autosaveEnabled = false
            return work(bg)
        }.value
    }
}
