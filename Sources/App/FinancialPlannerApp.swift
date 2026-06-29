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
            RootView()
        }
        .modelContainer(container)
    }
}

/// Roots the app at the Plan-the-year flow (the lane implemented first).
struct RootView: View {
    var body: some View {
        NavigationStack {
            YearPlanView()
        }
        .tint(Theme.Palette.green)
    }
}
