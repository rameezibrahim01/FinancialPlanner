import SwiftUI
import SwiftData

/// B3 · Plan vs Actual — track this month's spend against its budget, per category.
/// Bars fill to actual/plan; over-budget categories turn clay. The header status
/// derives from total spent vs total budget.
struct PlanVsActualView: View {
    let plan: MonthPlan
    @Query private var txns: [Transaction]

    init(plan: MonthPlan) {
        self.plan = plan
        let cal = SampleData.cal()
        let start = cal.date(from: DateComponents(year: plan.year, month: plan.month, day: 1)) ?? Date()
        let end = cal.date(byAdding: .month, value: 1, to: start) ?? start
        let expense = TxType.expense.rawValue
        _txns = Query(filter: #Predicate<Transaction> {
            $0.date >= start && $0.date < end && $0.typeRaw == expense
        })
    }

    private var actualByCategory: [String: Double] {
        Dictionary(grouping: txns, by: \.categoryName).mapValues { $0.reduce(0) { $0 + $1.amount } }
    }
    private var totalBudget: Double { plan.budgetTotal }
    private var totalSpent: Double { actualByCategory.values.reduce(0, +) }
    private var left: Double { totalBudget - totalSpent }
    private var onTrack: Bool { totalSpent <= totalBudget }
    private var usedPercent: Int { totalBudget > 0 ? Int((totalSpent / totalBudget * 100).rounded()) : 0 }

    private var daysLeft: Int? {
        let cal = SampleData.cal()
        let today = Date()
        let comps = cal.dateComponents([.year, .month], from: today)
        guard comps.year == plan.year, comps.month == plan.month else { return nil }
        let range = cal.range(of: .day, in: .month, for: today)?.count ?? 30
        let day = cal.component(.day, from: today)
        return max(0, range - day)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                progressCard
                categoryList
            }
            .padding(.horizontal, Theme.Spacing.side)
            .padding(.bottom, Theme.Spacing.bottomSafe)
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("\(plan.monthLong) · plan vs actual")
                        .font(.ui(17, .bold)).foregroundStyle(Theme.Palette.ink)
                    Text(statusText)
                        .font(.mono(10, .medium)).kerning(0.4)
                        .foregroundStyle(onTrack ? Theme.Palette.green : Theme.Palette.clay)
                }
            }
        }
    }

    private var statusText: String {
        let head = onTrack ? "ON TRACK" : "OVER"
        if let d = daysLeft { return "\(head) · \(d) DAY\(d == 1 ? "" : "S") LEFT" }
        return head
    }

    // MARK: Progress card

    private var progressCard: some View {
        Card(padding: 20, radius: Theme.Radius.summary) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Spent of budget").font(.ui(14)).foregroundStyle(Theme.Palette.inkSecondary)
                HStack(alignment: .firstTextBaseline) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(Money.plain(totalSpent)).tabular()
                            .font(.ui(32, .heavy)).foregroundStyle(Theme.Palette.ink)
                        Text("/ \(Money.plain(totalBudget))").tabular()
                            .font(.ui(16)).foregroundStyle(Theme.Palette.muted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(left >= 0 ? "Left" : "Over").font(.ui(11)).foregroundStyle(Theme.Palette.muted)
                        Text(Money.plain(abs(left))).tabular()
                            .font(.ui(18, .heavy))
                            .foregroundStyle(left >= 0 ? Theme.Palette.green : Theme.Palette.clay)
                    }
                }
                TrackBar(fraction: totalBudget > 0 ? totalSpent / totalBudget : 0,
                         height: 10,
                         fill: onTrack ? Theme.Palette.green : Theme.Palette.clay)
                Text("\(usedPercent)% of \(plan.monthLong) budget used")
                    .font(.ui(11)).foregroundStyle(Theme.Palette.muted)
            }
        }
    }

    // MARK: Category list

    private var categoryList: some View {
        VStack(spacing: 16) {
            ForEach(plan.orderedBudgets, id: \.persistentModelID) { b in
                let actual = actualByCategory[b.categoryName] ?? 0
                CategoryActualRow(name: b.categoryName, colorHex: b.colorHex,
                                  actual: actual, plan: b.amount)
            }
        }
    }
}

private struct CategoryActualRow: View {
    let name: String
    let colorHex: String
    let actual: Double
    let plan: Double

    private var over: Bool { actual > plan }
    private var frac: Double { plan > 0 ? min(1, actual / plan) : 0 }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ColorSquare(hex: colorHex, size: 9)
                Text(name).font(.ui(13, .semibold)).foregroundStyle(Theme.Palette.ink)
                Spacer()
                HStack(spacing: 4) {
                    Text(Money.plain(actual)).tabular()
                        .font(.ui(13, .bold))
                        .foregroundStyle(over ? Theme.Palette.clay : Theme.Palette.ink)
                    Text("/ \(Money.plain(plan))").tabular()
                        .font(.ui(13)).foregroundStyle(Theme.Palette.faint)
                }
            }
            TrackBar(fraction: frac, height: 6,
                     fill: over ? Theme.Palette.clay : Color(hex: colorHex))
        }
    }
}
