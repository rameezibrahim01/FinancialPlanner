import Foundation
import SwiftData
import WidgetKit

/// Computes the Today "safe to spend" numbers and writes them to the App Group
/// so the widget can render them, then asks WidgetKit to refresh. Mirrors the
/// discretionary model in DashboardView (fixed recurring bills are reserved and
/// excluded from the daily figure).
enum WidgetSnapshotWriter {
    @MainActor
    static func update(_ context: ModelContext) {
        let cal = SampleData.cal()
        let today = SampleData.referenceToday
        let year = cal.component(.year, from: today)
        let month = cal.component(.month, from: today)
        let day = cal.component(.day, from: today)
        let daysInMonth = cal.range(of: .day, in: .month, for: today)?.count ?? 30
        let daysRemaining = max(1, daysInMonth - day + 1)

        let plans = (try? context.fetch(FetchDescriptor<MonthPlan>())) ?? []
        let txns = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let recurring = (try? context.fetch(FetchDescriptor<Recurring>())) ?? []

        let monthBudget = plans.first { $0.year == year && $0.month == month }?.budgetTotal ?? 0
        let committed = recurring.filter { $0.autoPost && $0.cadence == .monthly }.reduce(0) { $0 + $1.amount }
        let discretionaryBudget = max(0, monthBudget - committed)

        func inMonth(_ t: Transaction) -> Bool {
            cal.component(.year, from: t.date) == year && cal.component(.month, from: t.date) == month
        }
        let discretionary = txns.filter { $0.type == .expense && !$0.autoPosted && inMonth($0) }
        let discretionarySpent = discretionary.reduce(0) { $0 + $1.amount }
        let spentToday = discretionary.filter { cal.isDate($0.date, inSameDayAs: today) }
            .reduce(0) { $0 + $1.amount }
        let beforeToday = discretionarySpent - spentToday

        let todayAllowance = max(0, (discretionaryBudget - beforeToday) / Double(daysRemaining))
        let safeToday = max(0, todayAllowance - spentToday)
        let left = discretionaryBudget - discretionarySpent

        let snapshot = WidgetSnapshot(
            safeToday: safeToday,
            spentToday: spentToday,
            discretionaryLeft: left,
            daysRemaining: daysRemaining,
            monthName: MonthPlan.longNames[month - 1],
            isOver: left < 0,
            overAmount: max(0, -left),
            hasBudget: monthBudget > 0,
            updatedAt: Date()
        )
        PlannerWidgetShared.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
