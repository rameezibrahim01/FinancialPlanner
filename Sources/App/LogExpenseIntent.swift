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

    @Parameter(title: "Amount", requestValueDialog: "How much?")
    var amount: Double

    @Parameter(title: "Type", default: .expense)
    var kind: TransactionKindAppEnum

    @Parameter(title: "Category", requestValueDialog: "Which category?")
    var category: CategoryEntity

    @Parameter(title: "Note")
    var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$kind) of \(\.$amount) in \(\.$category)") {
            \.$note
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = AppModelContainer.shared.mainContext

        let resolved: String
        if kind == .income {
            // Income isn't tied to the expense category list — keep what was said.
            let typed = category.name.trimmingCharacters(in: .whitespaces)
            resolved = typed.isEmpty ? "Income" : typed
        } else {
            // Match an existing category (name or keyword), else create it.
            resolved = ExpenseCategoryResolver.resolveOrCreate(category.name)
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

// MARK: - Category as an App Intent entity

/// A selectable category for Siri / Shortcuts. Its id is the (unique) name, so a
/// spoken/typed value that isn't a real category yet can still be carried
/// through and created on the way in.
struct CategoryEntity: AppEntity, Identifiable {
    var id: String
    var name: String

    init(name: String) { self.id = name; self.name = name }

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Category")
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    static var defaultQuery = CategoryQuery()
}

/// Backs the category picker (existing categories) and resolves spoken text —
/// matching an existing category, or offering to add the typed one.
struct CategoryQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [CategoryEntity] {
        identifiers.map { CategoryEntity(name: $0) }
    }

    @MainActor
    func suggestedEntities() async throws -> [CategoryEntity] {
        ExpenseCategoryResolver.allNames().map { CategoryEntity(name: $0) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [CategoryEntity] {
        var results: [CategoryEntity] = []
        if let match = ExpenseCategoryResolver.matchExisting(string) {
            results.append(CategoryEntity(name: match))
        }
        // Offer the raw text too, so a genuinely new category can be added.
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty,
           !results.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            results.append(CategoryEntity(name: trimmed))
        }
        return results.isEmpty ? try await suggestedEntities() : results
    }
}

// MARK: - Category resolution

/// Turns arbitrary spoken/typed text into a real category — by exact match,
/// keyword ("coffee" → Dining), or by creating a new one.
enum ExpenseCategoryResolver {
    /// Common words mapped to a canonical category (used only when that category
    /// actually exists in the store).
    static let keywords: [String: [String]] = [
        "Groceries": ["grocery", "groceries", "supermarket", "market", "carrefour", "lulu", "spinneys"],
        "Dining": ["coffee", "cafe", "restaurant", "lunch", "dinner", "food", "eat", "starbucks"],
        "Transport": ["taxi", "uber", "careem", "fuel", "petrol", "gas", "metro", "bus", "parking"],
        "Shopping": ["shopping", "clothes", "amazon", "noon", "mall"],
        "Utilities": ["electric", "electricity", "water", "dewa", "internet", "utility", "utilities"],
        "Health": ["pharmacy", "doctor", "clinic", "hospital", "medicine", "gym"],
        "Housing": ["rent", "housing", "mortgage"],
        "Subscriptions": ["netflix", "spotify", "subscription", "icloud", "youtube"],
        "School": ["school", "tuition", "fees", "books", "education"],
    ]

    @MainActor
    static func allNames() -> [String] {
        let ctx = AppModelContainer.shared.mainContext
        let cats = (try? ctx.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.order)]))) ?? []
        return cats.map(\.name)
    }

    /// An existing category name matching `text` (exact, substring, or keyword),
    /// or nil.
    @MainActor
    static func matchExisting(_ text: String) -> String? {
        let q = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return nil }
        let ctx = AppModelContainer.shared.mainContext
        let cats = (try? ctx.fetch(FetchDescriptor<Category>())) ?? []
        let names = cats.map(\.name)

        if let exact = names.first(where: { $0.lowercased() == q }) { return exact }
        if let part = names.first(where: { q.contains($0.lowercased()) || $0.lowercased().contains(q) }) {
            return part
        }
        for (cat, words) in keywords where names.contains(cat) {
            if words.contains(where: { q.contains($0) }) { return cat }
        }
        return nil
    }

    /// An existing category name for `text`, creating a new category if needed.
    @MainActor
    static func resolveOrCreate(_ text: String) -> String {
        if let match = matchExisting(text) { return match }
        let ctx = AppModelContainer.shared.mainContext
        let cats = (try? ctx.fetch(FetchDescriptor<Category>())) ?? []
        let name = text.trimmingCharacters(in: .whitespaces).capitalized
        guard !name.isEmpty else { return "Other" }
        if let existing = cats.first(where: { $0.name.lowercased() == name.lowercased() }) {
            return existing.name
        }
        let palette = CategoryManagerView.palette
        let order = (cats.map(\.order).max() ?? -1) + 1
        let color = palette[cats.count % palette.count]
        ctx.insert(Category(name: name, colorHex: color, order: order))
        try? ctx.save()
        return name
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
                "Add an expense in \(.applicationName)",
                "Add an expense to \(.applicationName)",
                "Record an expense in \(.applicationName)",
                "New expense in \(.applicationName)",
            ],
            shortTitle: "Log Expense",
            systemImageName: "plus.circle.fill"
        )
    }
}
