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
    func background<T>(_ work: @escaping (ModelContext) throws -> T) async rethrows -> T {
        let container = self.container
        return try await Task.detached(priority: .utility) {
            let bg = ModelContext(container)
            bg.autosaveEnabled = false
            return try work(bg)
        }.value
    }
}
