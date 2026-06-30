import SwiftUI
import SwiftData

@main
struct FinancialPlannerApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Category.self, IncomeSource.self, CategoryBudget.self,
                MonthPlan.self, Transaction.self, Goal.self,
                Recurring.self, Debt.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        SampleData.seedIfNeeded(container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            AppEntryView()
                // The design is a fixed light palette (the one dark surface, the
                // lock screen, is hardcoded). Pin the app to light so system
                // controls don't flip in dark mode. Also set via Info.plist's
                // UIUserInterfaceStyle for UIKit-presented surfaces.
                .preferredColorScheme(.light)
        }
        .modelContainer(container)
    }
}
