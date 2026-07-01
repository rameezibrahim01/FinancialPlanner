import Foundation
import SwiftData

/// Bootstraps the store with the minimum the app needs to function — the
/// canonical categories and 12 (empty) month plans — plus shared date helpers.
/// No demo/sample content: a fresh install starts clean and the user builds
/// everything through onboarding.
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

    /// The date the Track / Safe-to-spend screens treat as "today". Uses the real
    /// date when the device clock is in the plan year, otherwise falls back to
    /// mid-year so "current month" logic stays sensible.
    static var referenceToday: Date {
        let now = Date()
        if cal().component(.year, from: now) == year { return now }
        return date(year, 6, 15)
    }

    /// The canonical categories with their authoritative accent colors.
    static let categories: [(String, String)] = [
        ("Housing", Theme.CategoryColor.housing),
        ("Groceries", Theme.CategoryColor.groceries),
        ("Shopping", Theme.CategoryColor.shopping),
        ("Transport", Theme.CategoryColor.transport),
        ("Dining", Theme.CategoryColor.dining),
        ("Utilities", Theme.CategoryColor.utilities),
        ("Health", Theme.CategoryColor.health),
        ("School", Theme.CategoryColor.school),
        ("Other", Theme.CategoryColor.other),
    ]

    /// Bootstraps the essential scaffolding on first launch: the canonical
    /// categories and 12 empty month plans (there's no in-app "create plan" flow
    /// yet). The app is pre-release with no persisted user data to migrate, so
    /// this only ever runs against an empty store — one guard covers everything.
    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<MonthPlan>())) ?? []
        guard existing.isEmpty else { return }

        for (i, entry) in categories.enumerated() {
            context.insert(Category(name: entry.0, colorHex: entry.1, order: i))
        }
        for m in 1...12 {
            context.insert(MonthPlan(year: year, month: m, plannedIncome: 0, budgets: []))
        }
        try? context.save()
    }
}
