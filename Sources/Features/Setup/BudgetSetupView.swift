import SwiftUI
import SwiftData

/// Setup step 2 of 2 — set a monthly budget so the app is planning-ready right
/// after onboarding. "Start planning" applies the budget to the current month
/// and every later month; "Skip for now" lets the user do it later on the Plan
/// tab (where the current month is highlighted as the place to start).
struct BudgetSetupView: View {
    var onFinish: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \Category.order) private var categories: [Category]
    @Query private var plans: [MonthPlan]

    private var currentMonth: Int { SampleData.cal().component(.month, from: SampleData.referenceToday) }
    private var currentYear: Int { SampleData.cal().component(.year, from: SampleData.referenceToday) }

    private var thisMonth: MonthPlan? {
        plans.first { $0.year == currentYear && $0.month == currentMonth } ?? plans.first
    }
    private var income: Double { thisMonth?.plannedIncome ?? 0 }
    private var budgetTotal: Double { thisMonth?.budgetTotal ?? 0 }
    private var savings: Double { income - budgetTotal }
    private var savingsRate: Int { income > 0 ? Int((savings / income * 100).rounded()) : 0 }
    private var overAllocated: Bool { savings < 0 }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    header
                    if let plan = thisMonth {
                        incomeCard(plan)
                        if income > 0 {
                            Text("We drafted this from your income — tweak any category, then confirm.")
                                .font(.ui(12)).foregroundStyle(Theme.Palette.muted)
                                .padding(.horizontal, 4)
                        }
                        categoriesHeader
                        VStack(spacing: 12) {
                            ForEach(plan.orderedBudgets, id: \.persistentModelID) { budget in
                                BudgetEntryRow(budget: budget)
                            }
                        }
                    }
                    savingsBar
                }
                .padding(.horizontal, Theme.Spacing.side)
                .padding(.top, 8)
                .padding(.bottom, Theme.Spacing.bottomSafe)
                .readableContent(640)
            }
            .scrollDismissesKeyboard(.immediately)
            footer
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: setup)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SETUP · 2 OF 2").font(.mono(11, .medium)).kerning(0.5)
                .foregroundStyle(Theme.Palette.faint)
            Text("Your monthly budget").font(.ui(26, .heavy)).kerning(-0.6)
                .foregroundStyle(Theme.Palette.ink)
            Text("Set what you plan to spend per category. It applies to \(MonthPlan.longNames[currentMonth - 1]) and later — you can tweak any month afterwards.")
                .font(.ui(14)).foregroundStyle(Theme.Palette.inkSecondary)
        }
        .padding(.horizontal, 4)
    }

    private func incomeCard(_ plan: MonthPlan) -> some View {
        HStack {
            Text("Monthly income").font(.ui(13, .semibold)).foregroundStyle(Theme.Palette.green)
            Spacer()
            Text(Money.aed(plan.plannedIncome)).tabular()
                .font(.ui(18, .heavy)).foregroundStyle(Theme.Palette.green)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Theme.Palette.greenSoft2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private var categoriesHeader: some View {
        HStack {
            Text("Category budgets").font(.ui(15, .bold)).foregroundStyle(Theme.Palette.ink)
            Spacer()
            if income > 0 {
                Button { applySuggestion() } label: {
                    Label("Re-suggest", systemImage: "wand.and.stars")
                        .font(.ui(12, .semibold)).foregroundStyle(Theme.Palette.green)
                }
            } else {
                Text("tap an amount to type").font(.ui(11)).foregroundStyle(Theme.Palette.faint)
            }
        }
        .padding(.horizontal, 4)
    }

    private var savingsBar: some View {
        HStack {
            Text("You'll save").font(.ui(13, .semibold))
                .foregroundStyle(overAllocated ? Theme.Palette.clay : Theme.Palette.green)
            Spacer()
            Text(overAllocated
                 ? "Over by \(Money.aed(-savings))"
                 : "\(Money.aed(savings)) / month · \(savingsRate)%")
                .tabular().font(.ui(16, .heavy))
                .foregroundStyle(overAllocated ? Theme.Palette.clay : Theme.Palette.green)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(overAllocated ? Theme.Palette.claySoft : Theme.Palette.greenSoft2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: "Start planning") { finish(applyBudget: true) }
            Button("Skip for now") { finish(applyBudget: false) }
                .font(.ui(15, .semibold)).foregroundStyle(Theme.Palette.inkSecondary)
        }
        .padding(.horizontal, Theme.Spacing.side)
        .padding(.top, 8)
        .padding(.bottom, Theme.Spacing.bottomSafe)
        .readableContent(640)
        .background(Theme.Palette.page)
    }

    // MARK: Actions

    private func setup() {
        ensureAllCategories()
        // Draft a starting plan from income the first time (nothing set yet).
        if let plan = thisMonth, income > 0, plan.budgets.allSatisfy({ $0.amount == 0 }) {
            applySuggestion()
        }
    }

    /// Shows every category (at 0) on the current month so the whole list is editable.
    private func ensureAllCategories() {
        guard let plan = thisMonth else { return }
        let existing = Set(plan.budgets.map(\.categoryName))
        var added = false
        for cat in categories where !existing.contains(cat.name) {
            plan.budgets.append(CategoryBudget(categoryName: cat.name, colorHex: cat.colorHex,
                                               amount: 0, order: cat.order))
            added = true
        }
        if added { try? context.save() }
    }

    /// Fills every category with a rule-of-thumb amount from the month's income.
    private func applySuggestion() {
        guard let plan = thisMonth, income > 0 else { return }
        for b in plan.budgets {
            b.amount = BudgetSuggestion.amount(income: income, category: b.categoryName)
        }
        try? context.save()
    }

    private func finish(applyBudget: Bool) {
        if applyBudget, let plan = thisMonth {
            let template = plan.orderedBudgets.map { ($0.categoryName, $0.colorHex, $0.amount, $0.order) }
            for p in plans where p.year == currentYear && p.month >= currentMonth
                && p.persistentModelID != plan.persistentModelID {
                for b in p.budgets { context.delete(b) }
                p.budgets = template.map {
                    CategoryBudget(categoryName: $0.0, colorHex: $0.1, amount: $0.2, order: $0.3)
                }
                p.plannedIncome = plan.plannedIncome
            }
            try? context.save()
        }
        onFinish()
    }
}

// MARK: - Budget entry row (tap-to-type)

private struct BudgetEntryRow: View {
    @Bindable var budget: CategoryBudget
    @State private var text = ""

    var body: some View {
        HStack(spacing: 10) {
            ColorSquare(hex: budget.colorHex, size: 12, corner: 4)
            Text(budget.categoryName).font(.ui(14, .semibold)).foregroundStyle(Theme.Palette.ink)
            Spacer()
            Text("AED").font(.ui(12)).foregroundStyle(Theme.Palette.muted)
            TextField("0", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.ui(16, .bold)).foregroundStyle(Theme.Palette.ink)
                .frame(maxWidth: 100)
                .onChange(of: text) { _, new in budget.amount = Double(new.filter(\.isNumber)) ?? 0 }
        }
        .padding(14)
        .background(Theme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .appShadow(.card)
        .onAppear { text = budget.amount > 0 ? String(Int(budget.amount)) : "" }
        // Reflect external changes (draft / re-suggest) without fighting typing.
        .onChange(of: budget.amount) { _, new in
            let parsed = Double(text.filter(\.isNumber)) ?? 0
            if parsed != new { text = new > 0 ? String(Int(new)) : "" }
        }
    }
}
