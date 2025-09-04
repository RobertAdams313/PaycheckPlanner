//
//  Haptics.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/2/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  Haptics.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 9/2/25.
//

import UIKit

enum Haptics {
    static func tap() {
        guard AppPreferences.hapticsEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        gen.impactOccurred()
    }

    static func success() {
        guard AppPreferences.hapticsEnabled else { return }
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.success)
    }

    static func warning() {
        guard AppPreferences.hapticsEnabled else { return }
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.warning)
    }

    static func error() {
        guard AppPreferences.hapticsEnabled else { return }
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.error)
    }
}
