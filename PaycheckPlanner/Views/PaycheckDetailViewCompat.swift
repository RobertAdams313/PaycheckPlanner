//
//  PaycheckDetailViewCompat.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/4/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  PaycheckDetailView+Compat.swift
//  PaycheckPlanner
//
//  Shims to preserve older call sites like PaycheckDetailView(breakdown:)
//  while the canonical initializer is PaycheckDetailView(payday:)
//

import SwiftUI

extension PaycheckDetailView {
    /// Back-compat for older code that passed a CombinedBreakdown.
    init(breakdown: CombinedBreakdown) {
        self.init(payday: breakdown.period.payday)
    }

    /// Handy overload if some callers pass a CombinedPeriod instead.
    init(period: CombinedPeriod) {
        self.init(payday: period.payday)
    }
}
