import SwiftData

/// The single on-disk SwiftData container, shared by the app UI and the App
/// Intents (Siri / Shortcuts / Action Button). Because the intents live in the
/// same target, they run in the app's process and write to this same store, so a
/// quick-logged transaction shows up in the UI on next launch.
enum AppModelContainer {
    static let shared: ModelContainer = {
        do {
            return try ModelContainer(
                for: Category.self, IncomeSource.self, CategoryBudget.self,
                MonthPlan.self, Transaction.self, Goal.self,
                Recurring.self, Debt.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
}
