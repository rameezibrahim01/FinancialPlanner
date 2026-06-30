import Foundation
import SwiftData

// MARK: - Category

@Model
final class Category {
    @Attribute(.unique) var name: String
    var colorHex: String
    var order: Int

    init(name: String, colorHex: String, order: Int) {
        self.name = name
        self.colorHex = colorHex
        self.order = order
    }
}

// MARK: - Income source

@Model
final class IncomeSource {
    var name: String
    var cadence: String       // "Monthly · 1st", "Avg / month"
    var amount: Double
    var recurring: Bool
    var tintHex: String

    init(name: String, cadence: String, amount: Double, recurring: Bool, tintHex: String) {
        self.name = name
        self.cadence = cadence
        self.amount = amount
        self.recurring = recurring
        self.tintHex = tintHex
    }
}

// MARK: - Category budget (one per category, per month plan)

@Model
final class CategoryBudget {
    var categoryName: String
    var colorHex: String
    var amount: Double
    var order: Int
    var plan: MonthPlan?

    init(categoryName: String, colorHex: String, amount: Double, order: Int) {
        self.categoryName = categoryName
        self.colorHex = colorHex
        self.amount = amount
        self.order = order
    }
}

// MARK: - Month plan

@Model
final class MonthPlan {
    var year: Int
    var month: Int            // 1...12
    var plannedIncome: Double
    @Relationship(deleteRule: .cascade, inverse: \CategoryBudget.plan)
    var budgets: [CategoryBudget]

    init(year: Int, month: Int, plannedIncome: Double, budgets: [CategoryBudget] = []) {
        self.year = year
        self.month = month
        self.plannedIncome = plannedIncome
        self.budgets = budgets
    }

    var budgetTotal: Double { budgets.reduce(0) { $0 + $1.amount } }
    var plannedSavings: Double { plannedIncome - budgetTotal }
    var savingsRate: Double { plannedIncome > 0 ? plannedSavings / plannedIncome : 0 }

    var orderedBudgets: [CategoryBudget] { budgets.sorted { $0.order < $1.order } }

    var monthShort: String { Self.shortNames[month - 1] }
    var monthLong: String { Self.longNames[month - 1] }

    static let shortNames = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]
    static let longNames = ["January","February","March","April","May","June",
                            "July","August","September","October","November","December"]
}

// MARK: - Transaction (source of truth for actuals)

enum TxType: String, Codable {
    case income, expense
}

@Model
final class Transaction {
    var id: UUID
    var typeRaw: String
    var amount: Double
    var categoryName: String
    var date: Date
    var note: String

    init(type: TxType, amount: Double, categoryName: String, date: Date, note: String = "") {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.amount = amount
        self.categoryName = categoryName
        self.date = date
        self.note = note
    }

    var type: TxType { TxType(rawValue: typeRaw) ?? .expense }
}

// MARK: - Recurring bill / subscription (V2-1)

enum RecurringCadence: String, Codable, CaseIterable {
    case monthly, quarterly, annual

    var label: String {
        switch self {
        case .monthly: return "monthly"
        case .quarterly: return "quarterly"
        case .annual: return "annual"
        }
    }
    /// Months between charges — used to amortize into a monthly equivalent.
    var months: Double {
        switch self {
        case .monthly: return 1
        case .quarterly: return 3
        case .annual: return 12
        }
    }
}

@Model
final class Recurring {
    var id: UUID
    var name: String
    var amount: Double
    var categoryName: String
    var colorHex: String
    var tintHex: String
    var cadenceRaw: String
    var dueDay: Int           // 1...28
    var autoPost: Bool
    var order: Int

    init(name: String, amount: Double, categoryName: String, colorHex: String,
         tintHex: String, cadence: RecurringCadence, dueDay: Int, autoPost: Bool, order: Int) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.categoryName = categoryName
        self.colorHex = colorHex
        self.tintHex = tintHex
        self.cadenceRaw = cadence.rawValue
        self.dueDay = dueDay
        self.autoPost = autoPost
        self.order = order
    }

    var cadence: RecurringCadence { RecurringCadence(rawValue: cadenceRaw) ?? .monthly }
    /// Amount spread across a month for budgeting (annual/quarterly amortized).
    var monthlyEquivalent: Double { amount / cadence.months }
    /// English ordinal for the due day, e.g. "1st", "22nd".
    var dueLabel: String { Self.ordinal(dueDay) }

    static func ordinal(_ n: Int) -> String {
        let ones = n % 10, tens = (n / 10) % 10
        let suffix: String
        if tens == 1 { suffix = "th" }
        else { switch ones { case 1: suffix = "st"; case 2: suffix = "nd"; case 3: suffix = "rd"; default: suffix = "th" } }
        return "\(n)\(suffix)"
    }
}

// MARK: - Debt (V2-3)

@Model
final class Debt {
    var id: UUID
    var name: String
    var balance: Double
    var openingBalance: Double
    var apr: Double           // annual percentage rate, e.g. 21 for 21%
    var monthlyPayment: Double
    var colorHex: String
    var tintHex: String
    var order: Int

    init(name: String, balance: Double, openingBalance: Double, apr: Double,
         monthlyPayment: Double, colorHex: String, tintHex: String, order: Int) {
        self.id = UUID()
        self.name = name
        self.balance = balance
        self.openingBalance = openingBalance
        self.apr = apr
        self.monthlyPayment = monthlyPayment
        self.colorHex = colorHex
        self.tintHex = tintHex
        self.order = order
    }

    var fill: Double { openingBalance > 0 ? max(0, min(1, 1 - balance / openingBalance)) : 0 }
    var percentPaid: Int { Int((fill * 100).rounded()) }
    /// High-rate debts are surfaced in clay.
    var isHighRate: Bool { apr >= 15 }
}

// MARK: - Savings goal

@Model
final class Goal {
    var name: String
    var target: Double
    var saved: Double
    var deadline: Date?
    var monthlyContribution: Double
    var colorHex: String
    var order: Int

    init(name: String, target: Double, saved: Double, deadline: Date?,
         monthlyContribution: Double, colorHex: String, order: Int) {
        self.name = name
        self.target = target
        self.saved = saved
        self.deadline = deadline
        self.monthlyContribution = monthlyContribution
        self.colorHex = colorHex
        self.order = order
    }

    var fill: Double { target > 0 ? min(1, saved / target) : 0 }
    var percentFunded: Int { Int((fill * 100).rounded()) }
}
