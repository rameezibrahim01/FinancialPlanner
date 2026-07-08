import Foundation

/// A starting-point budget drafted from monthly income: splits it across the
/// canonical categories by rule-of-thumb percentages (leaving ~22% to save),
/// rounded to the nearest 50. Categories without a default get 0. It's only a
/// draft — the user edits and confirms.
enum BudgetSuggestion {
    /// Share of income per canonical category (percent). Sums to ~78%, so the
    /// rest is planned savings.
    static let sharePct: [String: Double] = [
        "Housing": 25,
        "Groceries": 12,
        "Transport": 8,
        "Dining": 7,
        "Utilities": 6,
        "Shopping": 5,
        "School": 5,
        "Health": 4,
        "Other": 4,
        "Subscriptions": 2,
    ]

    /// Suggested amount for one category given the month's income.
    static func amount(income: Double, category: String) -> Double {
        guard income > 0, let pct = sharePct[category] else { return 0 }
        return ((income * pct / 100) / 50).rounded() * 50
    }
}
