//
//  SyncStatus.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 8/23/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


// SyncStatus.swift
import Foundation

enum SyncStatus {
    static var signedIniCloud: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    static func readableStatus(isEnabled: Bool) -> String {
        if !isEnabled { return "Off (Local only)" }
        if !signedIniCloud { return "On (iCloud not signed in)" }
        return "On (iCloud available)"
    }
}
