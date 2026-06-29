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
