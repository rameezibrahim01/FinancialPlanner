import Foundation
import SwiftData
import UIKit

/// Offline backup / export engine (V2-4). Serializes all on-device state to a
/// `.planner` JSON file, exports transactions as CSV and a year report as PDF,
/// and restores state from a chosen backup file. No network is ever used.
enum Backup {

    // MARK: Snapshot model

    struct Snapshot: Codable {
        struct Tx: Codable { var type: String; var amount: Double; var category: String; var date: Date; var note: String }
        struct Budget: Codable { var category: String; var colorHex: String; var amount: Double; var order: Int }
        struct Plan: Codable { var year: Int; var month: Int; var plannedIncome: Double; var budgets: [Budget] }
        struct GoalSnap: Codable { var name: String; var target: Double; var saved: Double; var deadline: Date?; var monthlyContribution: Double; var colorHex: String; var order: Int }
        struct RecurringSnap: Codable { var name: String; var amount: Double; var category: String; var colorHex: String; var tintHex: String; var cadence: String; var dueDay: Int; var autoPost: Bool; var order: Int }
        struct DebtSnap: Codable { var name: String; var balance: Double; var openingBalance: Double; var apr: Double; var monthlyPayment: Double; var colorHex: String; var tintHex: String; var order: Int }

        var exportedYear: Int
        var transactions: [Tx]
        var plans: [Plan]
        var goals: [GoalSnap]
        var recurring: [RecurringSnap]
        var debts: [DebtSnap]
    }

    static func makeSnapshot(plans: [MonthPlan], txns: [Transaction], goals: [Goal],
                             recurring: [Recurring], debts: [Debt], year: Int) -> Snapshot {
        Snapshot(
            exportedYear: year,
            transactions: txns.map {
                .init(type: $0.type.rawValue, amount: $0.amount, category: $0.categoryName,
                      date: $0.date, note: $0.note)
            },
            plans: plans.map { p in
                .init(year: p.year, month: p.month, plannedIncome: p.plannedIncome,
                      budgets: p.orderedBudgets.map {
                          .init(category: $0.categoryName, colorHex: $0.colorHex, amount: $0.amount, order: $0.order)
                      })
            },
            goals: goals.map {
                .init(name: $0.name, target: $0.target, saved: $0.saved, deadline: $0.deadline,
                      monthlyContribution: $0.monthlyContribution, colorHex: $0.colorHex, order: $0.order)
            },
            recurring: recurring.map {
                .init(name: $0.name, amount: $0.amount, category: $0.categoryName, colorHex: $0.colorHex,
                      tintHex: $0.tintHex, cadence: $0.cadenceRaw, dueDay: $0.dueDay, autoPost: $0.autoPost, order: $0.order)
            },
            debts: debts.map {
                .init(name: $0.name, balance: $0.balance, openingBalance: $0.openingBalance, apr: $0.apr,
                      monthlyPayment: $0.monthlyPayment, colorHex: $0.colorHex, tintHex: $0.tintHex, order: $0.order)
            }
        )
    }

    private static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    // MARK: Backup file (.planner)

    @discardableResult
    static func writePlanner(plans: [MonthPlan], txns: [Transaction], goals: [Goal],
                             recurring: [Recurring], debts: [Debt], year: Int) throws -> URL {
        let snap = makeSnapshot(plans: plans, txns: txns, goals: goals, recurring: recurring, debts: debts, year: year)
        let data = try encoder().encode(snap)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FinancialPlanner-\(year).planner")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: CSV export

    static func writeCSV(txns: [Transaction]) throws -> URL {
        let df = DateFormatter()
        df.calendar = SampleData.cal()
        df.dateFormat = "yyyy-MM-dd"
        var rows = ["Date,Type,Category,Amount,Note"]
        for t in txns.sorted(by: { $0.date < $1.date }) {
            let note = "\"" + t.note.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            rows.append("\(df.string(from: t.date)),\(t.type.rawValue),\(t.categoryName),\(String(format: "%.2f", t.amount)),\(note)")
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FinancialPlanner-transactions.csv")
        try rows.joined(separator: "\n").data(using: .utf8)!.write(to: url, options: .atomic)
        return url
    }

    // MARK: PDF year report

    static func writePDF(plans: [MonthPlan], txns: [Transaction], year: Int) throws -> URL {
        let income = txns.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let expense = txns.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        let net = income - expense
        let byCat = Dictionary(grouping: txns.filter { $0.type == .expense }, by: \.categoryName)
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
            .sorted { $0.value > $1.value }

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FinancialPlanner-\(year)-report.pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        try renderer.writePDF(to: url) { ctx in
            ctx.beginPage()
            let ink = UIColor(red: 0.08, green: 0.13, blue: 0.10, alpha: 1)
            let muted = UIColor(red: 0.54, green: 0.57, blue: 0.55, alpha: 1)
            var y: CGFloat = 56
            func draw(_ s: String, _ size: CGFloat, _ weight: UIFont.Weight, _ color: UIColor, indent: CGFloat = 56) {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color
                ]
                s.draw(at: CGPoint(x: indent, y: y), withAttributes: attrs)
            }
            draw("Financial Planner — \(year)", 26, .heavy, ink); y += 36
            draw("Year report · all amounts in AED", 12, .regular, muted); y += 40
            draw("Income", 13, .semibold, muted); draw(Money.plain(income), 18, .bold, ink, indent: 240); y += 28
            draw("Expenses", 13, .semibold, muted); draw(Money.plain(expense), 18, .bold, ink, indent: 240); y += 28
            draw("Net saved", 13, .semibold, muted); draw(Money.plain(net), 18, .heavy, ink, indent: 240); y += 44
            draw("Top categories", 15, .bold, ink); y += 28
            for (name, amt) in byCat.prefix(10) {
                draw(name, 12, .regular, ink, indent: 70)
                draw(Money.plain(amt), 12, .semibold, ink, indent: 240)
                y += 22
            }
        }
        return url
    }

    // MARK: Restore (replaces all state)

    @MainActor
    static func restore(from data: Data, into context: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snap = try decoder.decode(Snapshot.self, from: data)

        try deleteAll(MonthPlan.self, context)        // cascades CategoryBudget
        try deleteAll(CategoryBudget.self, context)
        try deleteAll(Transaction.self, context)
        try deleteAll(Goal.self, context)
        try deleteAll(Recurring.self, context)
        try deleteAll(Debt.self, context)

        for p in snap.plans {
            let budgets = p.budgets.map {
                CategoryBudget(categoryName: $0.category, colorHex: $0.colorHex, amount: $0.amount, order: $0.order)
            }
            context.insert(MonthPlan(year: p.year, month: p.month, plannedIncome: p.plannedIncome, budgets: budgets))
        }
        for t in snap.transactions {
            context.insert(Transaction(type: TxType(rawValue: t.type) ?? .expense, amount: t.amount,
                                       categoryName: t.category, date: t.date, note: t.note))
        }
        for g in snap.goals {
            context.insert(Goal(name: g.name, target: g.target, saved: g.saved, deadline: g.deadline,
                                monthlyContribution: g.monthlyContribution, colorHex: g.colorHex, order: g.order))
        }
        for r in snap.recurring {
            context.insert(Recurring(name: r.name, amount: r.amount, categoryName: r.category, colorHex: r.colorHex,
                                     tintHex: r.tintHex, cadence: RecurringCadence(rawValue: r.cadence) ?? .monthly,
                                     dueDay: r.dueDay, autoPost: r.autoPost, order: r.order))
        }
        for d in snap.debts {
            context.insert(Debt(name: d.name, balance: d.balance, openingBalance: d.openingBalance, apr: d.apr,
                                monthlyPayment: d.monthlyPayment, colorHex: d.colorHex, tintHex: d.tintHex, order: d.order))
        }
        try context.save()
    }

    @MainActor
    private static func deleteAll<T: PersistentModel>(_ type: T.Type, _ context: ModelContext) throws {
        for item in try context.fetch(FetchDescriptor<T>()) { context.delete(item) }
    }
}
