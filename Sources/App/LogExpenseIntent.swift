import AppIntents
import SwiftData
import Foundation

/// Quick "Log Expense" — records a transaction from Siri, Shortcuts, Spotlight
/// or the Action Button without opening the app. Writes to the same store as the
/// UI via `AppModelContainer.shared`, so it appears in the app on next launch.
struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Expense"
    static var description = IntentDescription("Quickly record an expense or income in Planner.")
    static var openAppWhenRun = false

    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "Type", default: .expense)
    var kind: TransactionKindAppEnum

    @Parameter(title: "Category", optionsProvider: CategoryOptionsProvider())
    var category: String?

    @Parameter(title: "Note")
    var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$kind) of \(\.$amount)") {
            \.$category
            \.$note
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = AppModelContainer.shared.mainContext

        // Match the spoken/typed category to a real one (case-insensitive);
        // otherwise fall back to a sensible default.
        let cats = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let typed = category?.trimmingCharacters(in: .whitespaces) ?? ""
        let resolved: String
        if let match = cats.first(where: { $0.name.lowercased() == typed.lowercased() }), !typed.isEmpty {
            resolved = match.name
        } else if !typed.isEmpty {
            resolved = typed                       // keep what the user said
        } else {
            resolved = kind == .income ? "Income" : "Other"
        }

        let txn = Transaction(
            type: kind == .income ? .income : .expense,
            amount: amount,
            categoryName: resolved,
            date: Date(),
            note: note?.trimmingCharacters(in: .whitespaces) ?? ""
        )
        context.insert(txn)
        try context.save()

        let verb = kind == .income ? "income" : "expense"
        return .result(dialog: "Logged AED \(Money.plain(amount)) \(verb) in \(resolved).")
    }
}

/// Expense vs income for the intent's Type parameter.
enum TransactionKindAppEnum: String, AppEnum {
    case expense, income

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Type")
    static var caseDisplayRepresentations: [TransactionKindAppEnum: DisplayRepresentation] = [
        .expense: "Expense",
        .income: "Income",
    ]
}

/// Suggests the user's existing categories when picking one in Shortcuts / Siri.
struct CategoryOptionsProvider: DynamicOptionsProvider {
    @MainActor
    func results() async throws -> [String] {
        let context = AppModelContainer.shared.mainContext
        let cats = (try? context.fetch(
            FetchDescriptor<Category>(sortBy: [SortDescriptor(\.order)]))) ?? []
        return cats.map(\.name)
    }
}

/// Exposes the intent to Siri / Spotlight with spoken phrases, and auto-adds it
/// to the Shortcuts app.
struct PlannerAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: [
                "Log an expense in \(.applicationName)",
                "Log expense in \(.applicationName)",
                "Add an expense to \(.applicationName)",
            ],
            shortTitle: "Log Expense",
            systemImageName: "plus.circle.fill"
        )
    }
}
