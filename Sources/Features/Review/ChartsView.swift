import SwiftUI
import SwiftData

/// D1 · Charts & trends — visualize cash flow over the year: average/best/worst
/// stat cards, a net-by-month bar chart, and a top-categories breakdown. All
/// figures derive from transactions + plans.
struct ChartsView: View {
    @Query(sort: \MonthPlan.month) private var plans: [MonthPlan]
    @Query private var txns: [Transaction]
    @Query(sort: \Category.order) private var categories: [Category]

    private let year = SampleData.year

    // MARK: Derived

    /// Net (income − expense) per month index 1...12.
    private var netByMonth: [Int: Double] {
        let cal = SampleData.cal()
        var inc: [Int: Double] = [:], exp: [Int: Double] = [:]
        for t in txns {
            let c = cal.dateComponents([.year, .month], from: t.date)
            guard c.year == year, let m = c.month else { continue }
            if t.type == .income { inc[m, default: 0] += t.amount } else { exp[m, default: 0] += t.amount }
        }
        var net: [Int: Double] = [:]
        for m in 1...12 { net[m] = (inc[m] ?? 0) - (exp[m] ?? 0) }
        return net
    }

    private var months: [(m: Int, net: Double)] { (1...12).map { ($0, netByMonth[$0] ?? 0) } }
    private var avgNet: Double { months.reduce(0) { $0 + $1.net } / 12 }
    private var best: (m: Int, net: Double)? { months.max { $0.net < $1.net } }
    private var worst: (m: Int, net: Double)? { months.min { $0.net < $1.net } }

    private var expenseByCategory: [(name: String, amount: Double)] {
        let grouped = Dictionary(grouping: txns.filter { $0.type == .expense }, by: \.categoryName)
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        return grouped.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }
    private var totalExpense: Double { expenseByCategory.reduce(0) { $0 + $1.amount } }

    private func color(for name: String) -> String {
        categories.first(where: { $0.name == name })?.colorHex ?? Theme.CategoryColor.other
    }

    private let cardColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                header
                statCards
                netChart
                topCategories
            }
            .padding(.horizontal, Theme.Spacing.side)
            .padding(.top, 8)
            .padding(.bottom, Theme.Spacing.bottomSafe)
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("REVIEW · AED").font(.mono(11, .medium)).kerning(0.5)
                .foregroundStyle(Theme.Palette.muted)
            Text("Charts & trends").font(.ui(26, .heavy)).kerning(-0.6)
                .foregroundStyle(Theme.Palette.ink)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Stat cards

    private var statCards: some View {
        LazyVGrid(columns: cardColumns, spacing: 10) {
            statCard("Avg / month", Money.thousands(avgNet, signed: true) + "k", Theme.Palette.ink)
            if let best {
                statCard("Best \(MonthPlan.shortNames[best.m - 1].capitalized)",
                         Money.thousands(best.net, signed: true) + "k", Theme.Palette.green)
            }
            if let worst {
                statCard("Worst \(MonthPlan.shortNames[worst.m - 1].capitalized)",
                         Money.thousands(worst.net, signed: true) + "k",
                         worst.net < 0 ? Theme.Palette.clay : Theme.Palette.green)
            }
        }
    }

    private func statCard(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.ui(11)).foregroundStyle(Theme.Palette.muted).lineLimit(1)
            Text(value).tabular().font(.ui(17, .heavy)).foregroundStyle(color)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
        .appShadow(.card)
    }

    // MARK: Net-by-month chart

    private var netChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Net by month").font(.ui(15, .bold)).foregroundStyle(Theme.Palette.ink)
            let maxAbs = max(1, months.map { abs($0.net) }.max() ?? 1)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(months, id: \.m) { item in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(item.net < 0 ? Theme.Palette.clay : Theme.Palette.green)
                            .frame(height: max(3, abs(item.net) / maxAbs * 118))
                        Text(String(MonthPlan.shortNames[item.m - 1].prefix(1)))
                            .font(.mono(9, .medium)).foregroundStyle(Theme.Palette.faint)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 140, alignment: .bottom)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .appShadow(.card)
    }

    // MARK: Top categories

    private var topCategories: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Top categories").font(.ui(15, .bold)).foregroundStyle(Theme.Palette.ink)
                .padding(.horizontal, 4)
            let maxCat = expenseByCategory.first?.amount ?? 1
            ForEach(expenseByCategory.prefix(6), id: \.name) { row in
                let pct = totalExpense > 0 ? Int((row.amount / totalExpense * 100).rounded()) : 0
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ColorSquare(hex: color(for: row.name), size: 9)
                        Text(row.name).font(.ui(13, .semibold)).foregroundStyle(Theme.Palette.ink)
                        Spacer()
                        HStack(spacing: 6) {
                            Text(Money.plain(row.amount)).tabular()
                                .font(.ui(13, .bold)).foregroundStyle(Theme.Palette.ink)
                            Text("· \(pct)%").font(.ui(12)).foregroundStyle(Theme.Palette.faint)
                        }
                    }
                    TrackBar(fraction: maxCat > 0 ? row.amount / maxCat : 0,
                             height: 6, fill: Color(hex: color(for: row.name)))
                }
            }
        }
    }
}
