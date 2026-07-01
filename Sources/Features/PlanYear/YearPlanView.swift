import SwiftUI
import SwiftData

/// B1 · Year Plan — see & set the budget for all 12 months at once.
struct YearPlanView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MonthPlan.month) private var plans: [MonthPlan]

    /// Standalone yearly savings goal used by the summary pill (handoff: 60,000).
    private let yearSavingsGoal: Double = 60000

    private var totalIncome: Double { plans.reduce(0) { $0 + $1.plannedIncome } }
    private var totalBudget: Double { plans.reduce(0) { $0 + $1.budgetTotal } }
    private var totalSavings: Double { totalIncome - totalBudget }
    private var goalPercent: Int {
        yearSavingsGoal > 0 ? Int((totalSavings / yearSavingsGoal * 100).rounded()) : 0
    }

    private var currentMonth: Int { SampleData.cal().component(.month, from: SampleData.referenceToday) }
    private var currentYear: Int { SampleData.cal().component(.year, from: SampleData.referenceToday) }
    private var currentMonthName: String { MonthPlan.longNames[currentMonth - 1] }
    private var hasAnyBudget: Bool { plans.contains { $0.budgetTotal > 0 } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                header
                if !hasAnyBudget, let plan = defaultMonthPlan {
                    NavigationLink { MonthPlanEditorView(plan: plan) } label: { setupHint }
                        .buttonStyle(.plain)
                }
                summaryCard
                tableCard
                footer
            }
            .padding(.horizontal, Theme.Spacing.side)
            .padding(.top, 8)
            .padding(.bottom, Theme.Spacing.bottomSafe)
            .readableContent()
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    RecurringView()
                } label: {
                    Text("Recurring").font(.ui(15, .semibold)).foregroundStyle(Theme.Palette.green)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SavingsGoalsView()
                } label: {
                    Text("Goals").font(.ui(15, .bold)).foregroundStyle(Theme.Palette.green)
                }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PLAN · 2026")
                .font(.mono(11, .medium)).kerning(0.5)
                .foregroundStyle(Theme.Palette.muted)
            Text("Year plan")
                .font(.ui(26, .heavy)).kerning(-0.6)
                .foregroundStyle(Theme.Palette.ink)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Summary card (green)

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Planned to save in 2026")
                    .font(.ui(13)).foregroundStyle(Theme.Palette.greenOnDark)
                Spacer()
                Text("\(goalPercent)% of goal")
                    .font(.ui(12, .bold))
                    .foregroundStyle(Theme.Palette.greenDark)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Theme.Palette.greenAccent)
                    .clipShape(Capsule())
            }
            Text(Money.aed(totalSavings)).tabular()
                .font(.ui(36, .heavy)).kerning(-1)
                .foregroundStyle(.white)

            HStack(spacing: 0) {
                miniStat("Income", totalIncome)
                miniStat("Budget", totalBudget)
                miniStat("Goal", yearSavingsGoal)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.green)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.summary, style: .continuous))
        .appShadow(.greenCard)
    }

    private func miniStat(_ label: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.ui(11)).foregroundStyle(Theme.Palette.greenOnDark2)
            Text(Money.plain(value)).tabular()
                .font(.ui(15, .bold)).foregroundStyle(Theme.Palette.greenOnDark3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Empty-state hint (points to the current month)

    private var setupHint: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Theme.Palette.green).frame(width: 40, height: 40)
                .overlay(Image(systemName: "wand.and.stars")
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 2) {
                Text("Start with \(currentMonthName)")
                    .font(.ui(15, .bold)).foregroundStyle(Theme.Palette.ink)
                Text("Set this month's budget, then copy it to the rest of the year.")
                    .font(.ui(12)).foregroundStyle(Theme.Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Palette.green)
        }
        .padding(16)
        .background(Theme.Palette.greenSoft2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            .stroke(Color(hex: "#cfe0d6"), lineWidth: 1))
    }

    // MARK: Table

    private var tableCard: some View {
        VStack(spacing: 0) {
            tableHeader
            ForEach(Array(plans.enumerated()), id: \.element.persistentModelID) { idx, plan in
                NavigationLink {
                    MonthPlanEditorView(plan: plan)
                } label: {
                    MonthRow(plan: plan,
                             isCurrent: plan.month == currentMonth && plan.year == currentYear)
                }
                .buttonStyle(.plain)
                if idx < plans.count - 1 {
                    Rectangle().fill(Theme.Palette.hairlineSoft).frame(height: 1)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(Theme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .appShadow(.card)
    }

    private var tableHeader: some View {
        VStack(spacing: 4) {
            Text("AED · THOUSANDS")
                .font(.mono(8, .medium)).kerning(0.4)
                .foregroundStyle(Theme.Palette.faint)
                .frame(maxWidth: .infinity, alignment: .trailing)
            HStack(spacing: 0) {
                Text("MON").frame(width: 38, alignment: .leading)
                Text("INCOME").frame(maxWidth: .infinity, alignment: .trailing)
                Text("BUDGET").frame(maxWidth: .infinity, alignment: .trailing)
                Text("SAVE").frame(maxWidth: .infinity, alignment: .trailing)
                Spacer().frame(width: 16)
            }
            .font(.mono(10, .medium)).kerning(0.4)
            .foregroundStyle(Theme.Palette.faint)
        }
        .padding(.top, 12).padding(.bottom, 8)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 12) {
            SecondaryButton(title: "Copy to remaining months", action: copyToAllMonths)
            if let plan = defaultMonthPlan {
                NavigationLink {
                    MonthPlanEditorView(plan: plan)
                } label: {
                    Text(hasAnyBudget ? "Edit a month" : "Set up \(currentMonthName)")
                        .font(.ui(16, .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(16)
                        .background(Theme.Palette.green)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                        .appShadow(.primaryButton)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// The month "Edit a month" jumps to — the current month, else the first.
    private var defaultMonthPlan: MonthPlan? {
        let m = SampleData.cal().component(.month, from: SampleData.referenceToday)
        return plans.first { $0.month == m } ?? plans.first
    }

    /// Applies one month's category budgets (and planned income) to the current
    /// month and every later month — past months are left untouched. The source
    /// is the first month that actually has budgets set, so once you've set up a
    /// single month, this fans it out across the rest of the year.
    private func copyToAllMonths() {
        let currentMonth = SampleData.cal().component(.month, from: SampleData.referenceToday)
        guard let source = plans.first(where: { $0.budgetTotal > 0 })
                ?? plans.first(where: { $0.month == currentMonth })
                ?? plans.first else { return }
        guard source.budgetTotal > 0 else { return }   // nothing to copy yet

        let template = source.orderedBudgets.map { ($0.categoryName, $0.colorHex, $0.amount, $0.order) }
        for plan in plans where plan.year == source.year
            && plan.month >= currentMonth
            && plan.persistentModelID != source.persistentModelID {
            for b in plan.budgets { context.delete(b) }
            plan.budgets = template.map {
                CategoryBudget(categoryName: $0.0, colorHex: $0.1, amount: $0.2, order: $0.3)
            }
            plan.plannedIncome = source.plannedIncome
        }
        try? context.save()
    }
}

// MARK: - Month row

private struct MonthRow: View {
    let plan: MonthPlan
    var isCurrent: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                if isCurrent {
                    Circle().fill(Theme.Palette.green).frame(width: 5, height: 5)
                }
                Text(plan.monthShort)
                    .font(.mono(11, isCurrent ? .bold : .medium))
                    .foregroundStyle(isCurrent ? Theme.Palette.green : Theme.Palette.inkSecondary)
            }
            .frame(width: 38, alignment: .leading)
            Text(Money.thousands(plan.plannedIncome)).tabular()
                .foregroundStyle(Theme.Palette.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(Money.thousands(plan.budgetTotal)).tabular()
                .foregroundStyle(Theme.Palette.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(Money.thousands(plan.plannedSavings, signed: true)).tabular()
                .fontWeight(.bold)
                .foregroundStyle(plan.plannedSavings >= 0 ? Theme.Palette.green : Theme.Palette.clay)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: "#cdd2cb"))
                .frame(width: 16, alignment: .trailing)
        }
        .font(.ui(13))
        .frame(height: 43)
        .contentShape(Rectangle())
    }
}
