import SwiftUI
import SwiftData

/// B2 · Month Plan editor ★ — set income & per-category budgets for one month.
/// "Planned savings" = income − sum(budgets) updates live; the allocation meter
/// follows, and over-allocation (savings < 0) surfaces as a clay warning.
struct MonthPlanEditorView: View {
    @Bindable var plan: MonthPlan
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editingIncome = false
    @State private var incomeText = ""

    private var budgetTotal: Double { plan.budgetTotal }
    private var savings: Double { plan.plannedSavings }
    private var overAllocated: Bool { savings < 0 }
    /// Slider fills are drawn relative to the largest category (handoff: Housing
    /// 100%, Groceries 48%, …), so the bars stay proportional as budgets change.
    private var sliderScale: Double { max(plan.budgets.map(\.amount).max() ?? 1, 1) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                summaryCard
                categoriesHeader
                VStack(spacing: 18) {
                    ForEach(plan.orderedBudgets, id: \.persistentModelID) { budget in
                        CategoryBudgetRow(budget: budget, scale: sliderScale) {
                            try? context.save()
                        }
                    }
                }
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
            .padding(.horizontal, Theme.Spacing.side)
            .padding(.bottom, Theme.Spacing.bottomSafe)
            .readableContent()
        }
        .screenBackground()
        .navigationTitle(Text(verbatim: "\(plan.monthLong) \(plan.year) plan"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    try? context.save()
                    dismiss()
                }
                .font(.ui(15, .bold)).foregroundStyle(Theme.Palette.green)
            }
        }
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
    }

    // MARK: Summary card

    private var summaryCard: some View {
        Card(padding: 18, radius: 20) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Planned income").font(.ui(14)).foregroundStyle(Theme.Palette.inkSecondary)
                    Spacer()
                    Button {
                        incomeText = String(Int(plan.plannedIncome))
                        editingIncome = true
                    } label: {
                        Text(Money.aed(plan.plannedIncome)).tabular()
                            .font(.ui(18, .heavy)).foregroundStyle(Theme.Palette.ink)
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

    private var categoriesHeader: some View {
        HStack {
            Text("Category budgets").font(.ui(15, .bold)).foregroundStyle(Theme.Palette.ink)
            Spacer()
            Button {
                addCategory()
            } label: {
                Text("+ Add").font(.ui(12, .semibold)).foregroundStyle(Theme.Palette.green)
            }
        }
        .padding(.horizontal, 4)
    }

    private func addCategory() {
        let used = Set(plan.budgets.map(\.categoryName))
        let next = SampleData.categories.first { !used.contains($0.0) }
        guard let next else { return }
        let order = (plan.budgets.map(\.order).max() ?? -1) + 1
        plan.budgets.append(CategoryBudget(categoryName: next.0, colorHex: next.1, amount: 0, order: order))
        try? context.save()
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

// MARK: - Category budget row with slider

private struct CategoryBudgetRow: View {
    @Bindable var budget: CategoryBudget
    let scale: Double
    var onChange: () -> Void

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                ColorSquare(hex: budget.colorHex, size: 9)
                Text(budget.categoryName).font(.ui(13, .semibold)).foregroundStyle(Theme.Palette.ink)
                Spacer()
                Text(Money.plain(budget.amount)).tabular()
                    .font(.ui(14, .bold)).foregroundStyle(Theme.Palette.ink)
            }
            BudgetSlider(value: $budget.amount, maxValue: scale, colorHex: budget.colorHex,
                         onChange: onChange)
        }
    }
}

// MARK: - Custom draggable slider

private struct BudgetSlider: View {
    @Binding var value: Double
    let maxValue: Double
    let colorHex: String
    var onChange: () -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let frac = maxValue > 0 ? min(1, max(0, value / maxValue)) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Palette.hairline).frame(height: 6)
                Capsule().fill(Color(hex: colorHex))
                    .frame(width: frac * w, height: 6)
                Circle().fill(.white)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Color(hex: colorHex), lineWidth: 2))
                    .appShadow(.card)
                    .offset(x: frac * w - 8)
            }
            .frame(height: 16)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let p = min(1, max(0, g.location.x / w))
                        value = (p * maxValue / 50).rounded() * 50
                    }
                    .onEnded { _ in onChange() }
            )
        }
        .frame(height: 16)
    }
}
