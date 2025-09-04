import Foundation
#if false
func formatCurrency(_ value: Decimal) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.locale = .current
    return f.string(from: value as NSDecimalNumber) ?? "$0"
}
#endif

