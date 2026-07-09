import SwiftUI
import SwiftData

/// C2 · Monthly breakdown — detail of one month: net card with an income/spent
/// split bar, a "Where it went" category list, and a recent-transactions list.
struct MonthlyBreakdownView: View {
    let plan: MonthPlan
    @Query private var txns: [Transaction]
    @Query(sort: \Category.order) private var categories: [Category]
    @State private var editingTxn: Transaction?

    init(plan: MonthPlan) {
        self.plan = plan
        let cal = SampleData.cal()
        let start = cal.date(from: DateComponents(year: plan.year, month: plan.month, day: 1)) ?? Date()
        let end = cal.date(byAdding: .month, value: 1, to: start) ?? start
        _txns = Query(filter: #Predicate<Transaction> { $0.date >= start && $0.date < end },
                      sort: \Transaction.date, order: .reverse)
    }

    // MARK: Derived

    private var incomeTotal: Double { txns.filter { $0.type == .income }.reduce(0) { $0 + $1.amount } }
    private var expenseTotal: Double { txns.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount } }
    private var net: Double { incomeTotal - expenseTotal }
    private var overBudget: Bool { expenseTotal > plan.budgetTotal }

    private var spendByCategory: [(name: String, amount: Double)] {
        let grouped = Dictionary(grouping: txns.filter { $0.type == .expense }, by: \.categoryName)
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        return grouped.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    private var maxCategory: Double { spendByCategory.first?.amount ?? 0 }

    private func color(for name: String) -> String {
        if let c = categories.first(where: { $0.name == name }) { return c.colorHex }
        if name == "Salary" { return Theme.CategoryColor.housing }   // green
        return Theme.CategoryColor.other
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                netCard
                planVsActualLink
                categorySection
                recentSection
            }
            .padding(.horizontal, Theme.Spacing.side)
            .padding(.bottom, Theme.Spacing.bottomSafe)
            .readableContent()
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingTxn) { txn in
            AddTransactionView(editing: txn)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("\(plan.monthLong) \(String(plan.year))")
                        .font(.ui(17, .bold)).foregroundStyle(Theme.Palette.ink)
                    if overBudget {
                        Text("OVER BUDGET")
                            .font(.mono(10, .medium)).kerning(0.4)
                            .foregroundStyle(Theme.Palette.clay)
                    }
                }
            }
        }
    }

    // MARK: Plan vs actual entry

    private var planVsActualLink: some View {
        NavigationLink {
            PlanVsActualView(plan: plan)
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.Palette.greenSoft).frame(width: 36, height: 36)
                    .overlay(Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.Palette.green))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Plan vs actual").font(.ui(14, .bold)).foregroundStyle(Theme.Palette.ink)
                    Text("How your spending compares to plan")
                        .font(.ui(11)).foregroundStyle(Theme.Palette.faint)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "#cdd2cb"))
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Theme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .appShadow(.card)
        }
        .buttonStyle(.plain)
    }

    // MARK: Net card

    private var netCard: some View {
        Card(padding: 20, radius: Theme.Radius.summary) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Net this month").font(.ui(14)).foregroundStyle(Theme.Palette.inkSecondary)
                    Spacer()
                    Text("\(net >= 0 ? "+" : "−")\(Money.plain(abs(net)))").tabular()
                        .font(.ui(22, .heavy))
                        .foregroundStyle(net >= 0 ? Theme.Palette.green : Theme.Palette.clay)
                }
                SplitBar(incomeShare: incomeTotal + expenseTotal > 0
                         ? incomeTotal / (incomeTotal + expenseTotal) : 0.5)
                HStack(spacing: 0) {
                    legendCell("Income", incomeTotal, dot: Theme.Palette.green)
                    legendCell("Spent", expenseTotal, dot: Theme.Palette.clay)
                }
            }
        }
    }

    private func legendCell(_ label: String, _ value: Double, dot: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(dot).frame(width: 6, height: 6)
            Text(label).font(.ui(12)).foregroundStyle(Theme.Palette.muted)
            Text(Money.plain(value)).tabular()
                .font(.ui(14, .bold)).foregroundStyle(Theme.Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Where it went

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Where it went")
                .font(.ui(15, .bold)).foregroundStyle(Theme.Palette.ink)
                .padding(.horizontal, 4)
            if spendByCategory.isEmpty {
                Text("No spending recorded yet.")
                    .font(.ui(13)).foregroundStyle(Theme.Palette.muted)
                    .padding(.horizontal, 4)
            } else {
                ForEach(spendByCategory, id: \.name) { row in
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            ColorSquare(hex: color(for: row.name), size: 9)
                            Text(row.name).font(.ui(13, .semibold)).foregroundStyle(Theme.Palette.ink)
                            Spacer()
                            Text(Money.plain(row.amount)).tabular()
                                .font(.ui(13, .bold)).foregroundStyle(Theme.Palette.ink)
                        }
                        TrackBar(fraction: maxCategory > 0 ? row.amount / maxCategory : 0,
                                 height: 6, fill: Color(hex: color(for: row.name)))
                    }
                }
            }
        }
    }

    // MARK: Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent")
                .font(.ui(15, .bold)).foregroundStyle(Theme.Palette.ink)
                .padding(.horizontal, 4)
            Card(padding: 6) {
                VStack(spacing: 0) {
                    ForEach(Array(txns.enumerated()), id: \.element.persistentModelID) { idx, t in
                        Button { editingTxn = t } label: {
                            RecentRow(txn: t, colorHex: color(for: t.categoryName))
                        }
                        .buttonStyle(.plain)
                        if idx < txns.count - 1 {
                            Rectangle().fill(Theme.Palette.hairlineSoft).frame(height: 1)
                                .padding(.leading, 50)
                        }
                    }
                    if txns.isEmpty {
                        Text("No transactions this month.")
                            .font(.ui(13)).foregroundStyle(Theme.Palette.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                }
            }
        }
    }
}

// MARK: - Split bar (income vs spent)

private struct SplitBar: View {
    let incomeShare: Double   // 0...1

    var body: some View {
        GeometryReader { geo in
            let w = max(0, geo.size.width - 2)
            HStack(spacing: 2) {
                Capsule().fill(Theme.Palette.green)
                    .frame(width: max(0, min(1, incomeShare)) * w)
                Capsule().fill(Theme.Palette.clay)
                    .frame(width: max(0, min(1, 1 - incomeShare)) * w)
            }
        }
        .frame(height: 10)
    }
}

// MARK: - Recent transaction row

private struct RecentRow: View {
    let txn: Transaction
    let colorHex: String

    private var title: String { txn.note.isEmpty ? txn.categoryName : txn.note }
    private var subtitle: String {
        let f = DateFormatter()
        f.calendar = SampleData.cal()
        f.dateFormat = "MMM d"
        return "\(f.string(from: txn.date)) · \(txn.categoryName)"
    }
    private var initial: String { String(txn.categoryName.prefix(1)).uppercased() }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: colorHex).opacity(0.16))
                .frame(width: 34, height: 34)
                .overlay(
                    Text(initial)
                        .font(.ui(13, .bold))
                        .foregroundStyle(Color(hex: colorHex))
                )
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).font(.ui(14, .semibold)).foregroundStyle(Theme.Palette.ink)
                    if txn.autoPosted {
                        Text("AUTO").font(.mono(8, .medium)).kerning(0.3)
                            .foregroundStyle(Theme.Palette.green)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Theme.Palette.greenSoft).clipShape(Capsule())
                    }
                }
                Text(subtitle).font(.ui(11)).foregroundStyle(Theme.Palette.faint)
            }
            Spacer()
            Text("\(txn.type == .income ? "+" : "−")\(Money.plain(txn.amount))").tabular()
                .font(.ui(14, .bold))
                .foregroundStyle(txn.type == .income ? Theme.Palette.green : Theme.Palette.clay)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
    }
}
