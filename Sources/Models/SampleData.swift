import Foundation
import SwiftData

/// Seeds the store on first launch with data that matches the handoff figures:
/// Year Plan totals (income 230,000 / budget 161,300 / save 68,700), March's
/// B2 category breakdown, June's B3 plan-vs-actual, and the B4 goals.
enum SampleData {
    static let year = 2026

    static func cal() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Dubai") ?? .current
        return c
    }

    static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        cal().date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    // Per-month planned income & budget totals (AED). Sums: 230,000 / 161,300.
    static let monthlyIncome: [Double] =
        [18500,18500,18500,21000,18500,18500,18500,18500,18500,18500,18500,24000]
    static let monthlyBudgetTotal: [Double] =
        [13000,13000,13200,14000,13000,12000,13900,13000,13000,13900,13000,16300]

    // The 8 categories with their authoritative accent colors.
    static let categories: [(String, String)] = [
        ("Housing", Theme.CategoryColor.housing),
        ("Groceries", Theme.CategoryColor.groceries),
        ("Shopping", Theme.CategoryColor.shopping),
        ("Transport", Theme.CategoryColor.transport),
        ("Dining", Theme.CategoryColor.dining),
        ("Utilities", Theme.CategoryColor.utilities),
        ("Health", Theme.CategoryColor.health),
        ("Other", Theme.CategoryColor.other),
    ]

    // March's exact B2 breakdown.
    static let marchBudgets: [(String, String, Double)] = [
        ("Housing", Theme.CategoryColor.housing, 5000),
        ("Groceries", Theme.CategoryColor.groceries, 2400),
        ("Shopping", Theme.CategoryColor.shopping, 1500),
        ("Transport", Theme.CategoryColor.transport, 1300),
        ("Dining", Theme.CategoryColor.dining, 1200),
        ("Utilities", Theme.CategoryColor.utilities, 1000),
        ("Health", Theme.CategoryColor.health, 800),
    ]

    // June's exact B3 breakdown (6 categories, Shopping 1,100, no Health).
    static let juneBudgets: [(String, String, Double)] = [
        ("Housing", Theme.CategoryColor.housing, 5000),
        ("Groceries", Theme.CategoryColor.groceries, 2400),
        ("Shopping", Theme.CategoryColor.shopping, 1100),
        ("Transport", Theme.CategoryColor.transport, 1300),
        ("Dining", Theme.CategoryColor.dining, 1200),
        ("Utilities", Theme.CategoryColor.utilities, 1000),
    ]

    // June actuals (transactions) → produces 9,840 / 12,000 spent.
    static let juneActuals: [(String, Double)] = [
        ("Housing", 5000),
        ("Groceries", 1980),
        ("Dining", 1460),
        ("Transport", 640),
        ("Utilities", 760),
        // Shopping 0 — no transaction
    ]

    /// Builds a month's budgets for a target total using March's distribution,
    /// with Housing absorbing the rounding remainder so the sum is exact.
    static func budgets(forTotal total: Double) -> [(String, String, Double)] {
        let baseTotal = 13200.0
        let factor = total / baseTotal
        var result: [(String, String, Double)] = []
        var othersSum = 0.0
        for (name, hex, amt) in marchBudgets where name != "Housing" {
            let scaled = (amt * factor / 50).rounded() * 50
            result.append((name, hex, scaled))
            othersSum += scaled
        }
        let housing = total - othersSum
        result.insert(("Housing", Theme.CategoryColor.housing, housing), at: 0)
        return result
    }

    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<MonthPlan>())) ?? []
        guard existing.isEmpty else { return }

        // Categories
        for (i, (name, hex)) in categories.enumerated() {
            context.insert(Category(name: name, colorHex: hex, order: i))
        }

        // Income sources
        context.insert(IncomeSource(name: "Salary", cadence: "Monthly · 1st",
                                    amount: 18500, recurring: true, tintHex: "#dbeae1"))
        context.insert(IncomeSource(name: "Freelance", cadence: "Avg / month",
                                    amount: 1200, recurring: true, tintHex: "#e6ead7"))

        // Month plans
        for m in 1...12 {
            let income = monthlyIncome[m - 1]
            let total = monthlyBudgetTotal[m - 1]
            let defs: [(String, String, Double)]
            switch m {
            case 3:  defs = marchBudgets
            case 6:  defs = juneBudgets
            default: defs = budgets(forTotal: total)
            }
            let budgetModels = defs.enumerated().map { idx, d in
                CategoryBudget(categoryName: d.0, colorHex: d.1, amount: d.2, order: idx)
            }
            context.insert(MonthPlan(year: year, month: m, plannedIncome: income, budgets: budgetModels))
        }

        // June actual transactions
        for (i, (cat, amt)) in juneActuals.enumerated() {
            context.insert(Transaction(type: .expense, amount: amt, categoryName: cat,
                                       date: date(year, 6, 3 + i),
                                       note: "\(cat) spend"))
        }
        context.insert(Transaction(type: .income, amount: 18500, categoryName: "Salary",
                                   date: date(year, 6, 1), note: "Salary"))

        // Goals
        context.insert(Goal(name: "New car", target: 60000, saved: 38400,
                            deadline: date(year, 12, 31), monthlyContribution: 5000,
                            colorHex: Theme.CategoryColor.housing, order: 0))
        context.insert(Goal(name: "Emergency fund", target: 25000, saved: 22000,
                            deadline: nil, monthlyContribution: 1500,
                            colorHex: Theme.CategoryColor.housing, order: 1))
        context.insert(Goal(name: "Japan trip", target: 15000, saved: 6300,
                            deadline: date(year, 10, 1), monthlyContribution: 1000,
                            colorHex: Theme.CategoryColor.transport, order: 2))

        try? context.save()
    }
}
