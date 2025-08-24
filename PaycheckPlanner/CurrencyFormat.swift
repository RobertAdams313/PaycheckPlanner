//
//  CurrencyFormat.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 8/23/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import Foundation

enum CurrencyFormat {
    static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = .current
        f.maximumFractionDigits = 2
        return f
    }()
}

extension Decimal {
    var currencyString: String {
        CurrencyFormat.formatter.string(from: self as NSDecimalNumber) ?? "$0"
    }
}
