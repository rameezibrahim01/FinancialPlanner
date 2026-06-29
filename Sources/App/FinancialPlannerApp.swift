import SwiftUI
import SwiftData

@main
struct FinancialPlannerApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Category.self, IncomeSource.self, CategoryBudget.self,
                MonthPlan.self, Transaction.self, Goal.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        SampleData.seedIfNeeded(container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }
}
