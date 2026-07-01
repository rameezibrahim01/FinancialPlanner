import SwiftUI
import SwiftData

/// B2 · Month Plan editor ★ — set income & per-category budgets for one month.
/// Every category is shown up front with a tap-to-type amount; planned savings
/// and the allocation meter update live. "Apply this to all months" fans the
/// month's budget out across the year so you only set it up once.
struct MonthPlanEditorView: View {
    @Bindable var plan: MonthPlan
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \Category.order) private var categories: [Category]
    @Query private var allPlans: [MonthPlan]
    @State private var editingIncome = false
    @State private var incomeText = ""
    @State private var showApplied = false

    private var budgetTotal: Double { plan.budgetTotal }
    private var savings: Double { plan.plannedSavings }
    private var overAllocated: Bool { savings < 0 }
    /// Bars are drawn relative to the largest category (with a floor so a single
    /// small budget doesn't fill the whole bar).
    private var barScale: Double { max(plan.budgets.map(\.amount).max() ?? 0, 1000) }

    var body: some View {
        ScrollView {
            if sizeClass == .regular {
                // iPad: summary + actions on the left, category budgets on the right.
                HStack(alignment: .top, spacing: Theme.Spacing.section) {
                    VStack(spacing: Theme.Spacing.section) {
                        summaryCard
                        applyButton
                        planVsActualLink
                    }
                    .frame(maxWidth: 340, alignment: .top)
                    VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                        categoriesHeader
                        categoryList
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .padding(.horizontal, Theme.Spacing.side)
                .padding(.bottom, Theme.Spacing.bottomSafe)
                .readableContent(960)
            } else {
                // iPhone: single stacked column.
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    summaryCard
                    categoriesHeader
                    categoryList
                    applyButton
                    planVsActualLink
                }
                .padding(.horizontal, Theme.Spacing.side)
                .padding(.bottom, Theme.Spacing.bottomSafe)
                .readableContent()
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .screenBackground()
        .navigationTitle(Text(verbatim: "\(plan.monthLong) \(plan.year) plan"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    try? context.save()
                    dismiss()
                }
                .font(.ui(15, .bold)).foregroundStyle(Theme.Palette.green)
            }
        }
        .onAppear(perform: ensureAllCategories)
        .alert("Planned income", isPresented: $editingIncome) {
            TextField("Amount", text: $incomeText).keyboardType(.numberPad)
            Button("Cancel", role: .cancel) {}
            Button("Set") {
                if let v = Double(incomeText.filter(\.isNumber)) {
                    plan.plannedIncome = v
                    try? context.save()
                }
            }
        }
        .alert("Applied to all months", isPresented: $showApplied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This month's income and category budgets were copied to every month of \(String(plan.year)).")
        }
    }

    // MARK: Summary card

    private var summaryCard: some View {
        Card(padding: 18, radius: 20) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Planned income").font(.ui(14)).foregroundStyle(Theme.Palette.inkSecondary)
                    Spacer()
                    Button {
                        incomeText = plan.plannedIncome > 0 ? String(Int(plan.plannedIncome)) : ""
                        editingIncome = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(Money.aed(plan.plannedIncome)).tabular()
                                .font(.ui(18, .heavy)).foregroundStyle(Theme.Palette.ink)
                            Image(systemName: "pencil").font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.Palette.green)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Divider().background(Theme.Palette.hairline).padding(.vertical, 14)

                HStack(alignment: .firstTextBaseline) {
                    Text("Planned savings").font(.ui(14)).foregroundStyle(Theme.Palette.inkSecondary)
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(Money.aed(savings)).tabular()
                            .font(.ui(20, .heavy))
                            .foregroundStyle(overAllocated ? Theme.Palette.clay : Theme.Palette.green)
                        Text("\(Int((plan.savingsRate * 100).rounded()))%")
                            .font(.ui(13)).foregroundStyle(Theme.Palette.muted)
                    }
                }
                .padding(.bottom, 14)

                AllocationMeter(budgeted: budgetTotal, savings: savings,
                                income: max(plan.plannedIncome, 1))

                HStack {
                    Text("\(Money.aed(budgetTotal)) budgeted").tabular()
                    Spacer()
                    Text(overAllocated
                         ? "Over by \(Money.aed(-savings))"
                         : "\(Money.aed(savings)) to savings").tabular()
                        .foregroundStyle(overAllocated ? Theme.Palette.clay : Theme.Palette.muted)
                }
                .font(.ui(11))
                .foregroundStyle(Theme.Palette.muted)
                .padding(.top, 8)
            }
        }
    }

    // MARK: Categories

    private var categoriesHeader: some View {
        HStack {
            Text("Category budgets").font(.ui(15, .bold)).foregroundStyle(Theme.Palette.ink)
            Spacer()
            Text("tap an amount to type").font(.ui(11)).foregroundStyle(Theme.Palette.faint)
        }
        .padding(.horizontal, 4)
    }

    private var categoryList: some View {
        VStack(spacing: 16) {
            ForEach(plan.orderedBudgets, id: \.persistentModelID) { budget in
                CategoryBudgetRow(budget: budget, maxAmount: barScale)
            }
        }
    }

    private var applyButton: some View {
        Button(action: applyToAllMonths) {
            Text("Apply this to all months")
                .font(.ui(15, .bold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(14)
                .background(Theme.Palette.green)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                .appShadow(.primaryButton)
        }
        .buttonStyle(.plain)
    }

    private var planVsActualLink: some View {
        NavigationLink {
            PlanVsActualView(plan: plan)
        } label: {
            Text("View plan vs actual")
                .font(.ui(14, .semibold))
                .foregroundStyle(Theme.Palette.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
    }

    // MARK: Actions

    /// Ensures every category has a (possibly zero) budget row so the whole list
    /// is visible for editing — no adding categories one at a time.
    private func ensureAllCategories() {
        let existing = Set(plan.budgets.map(\.categoryName))
        var added = false
        for cat in categories where !existing.contains(cat.name) {
            plan.budgets.append(CategoryBudget(categoryName: cat.name, colorHex: cat.colorHex,
                                               amount: 0, order: cat.order))
            added = true
        }
        if added { try? context.save() }
    }

    /// Copies this month's income + category budgets to every other month of the year.
    private func applyToAllMonths() {
        let template = plan.orderedBudgets.map { ($0.categoryName, $0.colorHex, $0.amount, $0.order) }
        for p in allPlans where p.year == plan.year && p.persistentModelID != plan.persistentModelID {
            for b in p.budgets { context.delete(b) }
            p.budgets = template.map {
                CategoryBudget(categoryName: $0.0, colorHex: $0.1, amount: $0.2, order: $0.3)
            }
            p.plannedIncome = plan.plannedIncome
        }
        try? context.save()
        showApplied = true
    }
}

// MARK: - Allocation meter (budgeted vs savings)

private struct AllocationMeter: View {
    let budgeted: Double
    let savings: Double
    let income: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let budgetedFrac = min(1, budgeted / income)
            let savingsFrac = max(0, savings / income)
            HStack(spacing: 1) {
                Rectangle().fill(savings < 0 ? Theme.Palette.clay : Theme.Palette.amberBudget)
                    .frame(width: max(0, budgetedFrac * w - (savingsFrac > 0 ? 1 : 0)))
                if savingsFrac > 0 {
                    Rectangle().fill(Theme.Palette.green)
                        .frame(width: savingsFrac * w)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 9)
        .background(Theme.Palette.hairline)
        .clipShape(Capsule())
    }
}

// MARK: - Category budget row (tap-to-type amount + proportion bar)

private struct CategoryBudgetRow: View {
    @Bindable var budget: CategoryBudget
    let maxAmount: Double
    @State private var text = ""

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ColorSquare(hex: budget.colorHex, size: 9)
                Text(budget.categoryName).font(.ui(13, .semibold)).foregroundStyle(Theme.Palette.ink)
                Spacer()
                Text("AED").font(.ui(12)).foregroundStyle(Theme.Palette.muted)
                TextField("0", text: $text)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .font(.ui(15, .bold)).foregroundStyle(Theme.Palette.ink)
                    .frame(maxWidth: 90)
                    .onChange(of: text) { _, new in
                        budget.amount = Double(new.filter(\.isNumber)) ?? 0
                    }
            }
            TrackBar(fraction: maxAmount > 0 ? min(1, budget.amount / maxAmount) : 0,
                     height: 6, fill: Color(hex: budget.colorHex))
        }
        .onAppear { text = budget.amount > 0 ? String(Int(budget.amount)) : "" }
    }
}
