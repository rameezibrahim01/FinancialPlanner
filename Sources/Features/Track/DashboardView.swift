import SwiftUI
import SwiftData

/// C1 · Dashboard (home) — year-at-a-glance of actuals. Net-saved card plus a
/// 12-month grid of net/spend-ratio cells, each tapping into the monthly
/// breakdown (C2). All figures are derived from transactions + plans.
struct DashboardView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \MonthPlan.month) private var plans: [MonthPlan]
    @Query private var txns: [Transaction]

    private let year = SampleData.year

    // MARK: Derived actuals

    private struct MonthActual {
        var income = 0.0
        var expense = 0.0
        var net: Double { income - expense }
        var ratio: Double { income > 0 ? expense / income : (expense > 0 ? 1 : 0) }
    }

    private var byMonth: [Int: MonthActual] {
        let cal = SampleData.cal()
        var dict: [Int: MonthActual] = [:]
        for t in txns {
            let comps = cal.dateComponents([.year, .month], from: t.date)
            guard comps.year == year, let m = comps.month else { continue }
            var a = dict[m] ?? MonthActual()
            if t.type == .income { a.income += t.amount } else { a.expense += t.amount }
            dict[m] = a
        }
        return dict
    }

    private var planByMonth: [Int: MonthPlan] {
        Dictionary(uniqueKeysWithValues: plans.map { ($0.month, $0) })
    }

    private var totalIncome: Double { byMonth.values.reduce(0) { $0 + $1.income } }
    private var totalExpense: Double { byMonth.values.reduce(0) { $0 + $1.expense } }
    private var netSaved: Double { totalIncome - totalExpense }
    private var savingsRate: Int { totalIncome > 0 ? Int((netSaved / totalIncome * 100).rounded()) : 0 }
    private var onPlan: Bool { netSaved >= 0 }

    private var columns: [GridItem] {
        let count = sizeClass == .regular ? 6 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                header
                netCard
                glance
            }
            .padding(.horizontal, Theme.Spacing.side)
            .padding(.top, 8)
            .padding(.bottom, Theme.Spacing.bottomSafe)
            .readableContent(820)
        }
        .screenBackground()
        .navBarHiddenInCompact()
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ANNUAL · AED")
                    .font(.mono(11, .medium)).kerning(0.5)
                    .foregroundStyle(Theme.Palette.muted)
                Text(String(year))
                    .font(.ui(30, .heavy)).kerning(-0.8)
                    .foregroundStyle(Theme.Palette.ink)
            }
            Spacer()
            Pill(text: onPlan ? "On plan" : "Off plan",
                 bg: onPlan ? Theme.Palette.greenSoft : Theme.Palette.claySoft,
                 fg: onPlan ? Theme.Palette.green : Theme.Palette.clay,
                 dot: onPlan ? Theme.Palette.green : Theme.Palette.clay)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Net saved card

    private var netCard: some View {
        Card(padding: 20, radius: Theme.Radius.largeSummary) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Net saved this year")
                        .font(.ui(14)).foregroundStyle(Theme.Palette.inkSecondary)
                    Spacer()
                    Pill(text: "\(savingsRate)% rate", bg: Theme.Palette.greenSoft3)
                }
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("AED").font(.ui(16, .semibold)).foregroundStyle(Theme.Palette.inkSecondary)
                    Text(Money.plain(netSaved)).tabular()
                        .font(.ui(38, .heavy)).kerning(-1)
                        .foregroundStyle(netSaved >= 0 ? Theme.Palette.green : Theme.Palette.clay)
                }
                Rectangle().fill(Theme.Palette.hairline).frame(height: 1)
                HStack(spacing: 0) {
                    legendCell("Income", totalIncome, dot: Theme.Palette.green)
                    legendCell("Expenses", totalExpense, dot: Theme.Palette.clay)
                }
            }
        }
    }

    private func legendCell(_ label: String, _ value: Double, dot: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(dot).frame(width: 6, height: 6)
                Text(label).font(.ui(12)).foregroundStyle(Theme.Palette.muted)
            }
            Text(Money.plain(value)).tabular()
                .font(.ui(18, .bold)).foregroundStyle(Theme.Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 12-month grid

    private var glance: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("At a glance")
                .font(.ui(15, .bold)).foregroundStyle(Theme.Palette.ink)
                .padding(.horizontal, 4)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(1...12, id: \.self) { m in
                    let a = byMonth[m] ?? MonthActual()
                    if let plan = planByMonth[m] {
                        NavigationLink {
                            MonthlyBreakdownView(plan: plan)
                        } label: {
                            MonthCell(month: m, net: a.net, ratio: a.ratio)
                        }
                        .buttonStyle(.plain)
                    } else {
                        MonthCell(month: m, net: a.net, ratio: a.ratio)
                    }
                }
            }
        }
    }
}

// MARK: - Month cell

private struct MonthCell: View {
    let month: Int
    let net: Double
    let ratio: Double

    private var ratioPercent: Int { Int((ratio * 100).rounded()) }
    private var barColor: Color {
        if ratio > 1 { return Theme.Palette.clay }
        if ratio >= 0.85 { return Theme.Palette.amber }
        return Theme.Palette.green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(MonthPlan.shortNames[month - 1])
                .font(.mono(10, .medium)).kerning(0.4)
                .foregroundStyle(Theme.Palette.faint)
            Text("\(Money.thousands(net, signed: true))k").tabular()
                .font(.ui(17, .heavy))
                .foregroundStyle(net >= 0 ? Theme.Palette.green : Theme.Palette.clay)
            TrackBar(fraction: min(1, ratio), height: 5, fill: barColor)
            Text("\(ratioPercent)% spent")
                .font(.mono(9, .medium))
                .foregroundStyle(Theme.Palette.faint)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .appShadow(.card)
    }
}
