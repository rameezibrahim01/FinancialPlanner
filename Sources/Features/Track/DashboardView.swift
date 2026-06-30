import SwiftUI
import SwiftData

/// V2-2 · Dashboard (home) — "Safe to spend today" is the headline number. A
/// Today/Year toggle keeps the v1 12-month grid reachable. All figures derive
/// from transactions + plan + recurring; nothing new is persisted.
struct DashboardView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage("displayName") private var displayName = "Sara"
    @AppStorage("startingSavings") private var startingSavings = 0.0
    @Query(sort: \MonthPlan.month) private var plans: [MonthPlan]
    @Query private var txns: [Transaction]
    @Query(sort: \Recurring.order) private var recurring: [Recurring]

    @State private var mode: Mode = .today
    enum Mode: String, CaseIterable, Identifiable {
        case today = "Today", year = "Year"
        var id: String { rawValue }
    }

    private let cal = SampleData.cal()
    private var today: Date { SampleData.referenceToday }
    private var curMonth: Int { cal.component(.month, from: today) }
    private var curYear: Int { cal.component(.year, from: today) }
    private var todayDay: Int { cal.component(.day, from: today) }
    private var daysInMonth: Int { cal.range(of: .day, in: .month, for: today)?.count ?? 30 }
    private var daysRemaining: Int { max(1, daysInMonth - todayDay + 1) }

    // MARK: Current-month actuals

    private var monthPlan: MonthPlan? { plans.first { $0.year == curYear && $0.month == curMonth } }
    private var monthBudget: Double { monthPlan?.budgetTotal ?? 0 }

    private var monthTxns: [Transaction] {
        txns.filter {
            cal.component(.year, from: $0.date) == curYear
            && cal.component(.month, from: $0.date) == curMonth
        }
    }
    private var monthIncome: Double { monthTxns.filter { $0.type == .income }.reduce(0) { $0 + $1.amount } }
    private var monthExpense: Double { monthTxns.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount } }
    private var saved: Double { monthIncome - monthExpense }

    /// Recurring charges still to post this month (due day not yet passed).
    private var committedRemaining: Double {
        recurring.filter { $0.dueDay >= todayDay }.reduce(0) { $0 + $1.amount }
    }
    private var safeBase: Double { monthBudget - committedRemaining - monthExpense }
    private var safeToday: Double { max(0, safeBase / Double(daysRemaining)) }
    private var isOver: Bool { safeBase < 0 }
    private var leftThisMonth: Double { monthBudget - monthExpense }
    private var spentFraction: Double { monthBudget > 0 ? min(1, monthExpense / monthBudget) : 0 }
    private var onPlan: Bool { monthExpense <= monthBudget }

    // MARK: Upcoming recurring

    private func daysUntil(_ dueDay: Int) -> Int {
        dueDay >= todayDay ? dueDay - todayDay : (daysInMonth - todayDay) + dueDay
    }
    private var upcoming: [Recurring] {
        recurring.filter { daysUntil($0.dueDay) <= 7 }
            .sorted { daysUntil($0.dueDay) < daysUntil($1.dueDay) }
    }
    private func dueCopy(_ n: Int) -> String {
        switch n { case 0: return "today"; case 1: return "tomorrow"; default: return "in \(n) days" }
    }

    // MARK: Year view (12-month grid)

    private struct MonthActual {
        var income = 0.0, expense = 0.0
        var net: Double { income - expense }
        var ratio: Double { income > 0 ? expense / income : (expense > 0 ? 1 : 0) }
    }
    private var byMonth: [Int: MonthActual] {
        var dict: [Int: MonthActual] = [:]
        for t in txns {
            let c = cal.dateComponents([.year, .month], from: t.date)
            guard c.year == curYear, let m = c.month else { continue }
            var a = dict[m] ?? MonthActual()
            if t.type == .income { a.income += t.amount } else { a.expense += t.amount }
            dict[m] = a
        }
        return dict
    }
    private var planByMonth: [Int: MonthPlan] {
        Dictionary(uniqueKeysWithValues: plans.filter { $0.year == curYear }.map { ($0.month, $0) })
    }
    private var yearIncome: Double { byMonth.values.reduce(0) { $0 + $1.income } }
    private var yearExpense: Double { byMonth.values.reduce(0) { $0 + $1.expense } }
    private var yearNet: Double { yearIncome - yearExpense }
    private var savingsRate: Int { yearIncome > 0 ? Int((yearNet / yearIncome * 100).rounded()) : 0 }

    /// Net saved across all recorded transactions (not just the current year).
    private var allTimeNet: Double {
        txns.reduce(0) { $0 + ($1.type == .income ? $1.amount : -$1.amount) }
    }
    /// What the user actually has: the savings they started with + all-time net.
    private var totalSavings: Double { startingSavings + allTimeNet }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: sizeClass == .regular ? 6 : 3)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                header
                Picker("View", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if mode == .today {
                    safeToSpendCard
                    statTiles
                    upcomingSection
                } else {
                    yearNetCard
                    glance
                }
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
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(MonthPlan.longNames[curMonth - 1].uppercased()) · AED")
                    .font(.mono(11, .medium)).kerning(0.5)
                    .foregroundStyle(Theme.Palette.muted)
                Text("Hello, \(displayName)")
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

    // MARK: Safe to spend hero

    private var safeToSpendCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Safe to spend today")
                .font(.ui(13)).foregroundStyle(Theme.Palette.greenOnDark)
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("AED").font(.ui(16, .semibold)).foregroundStyle(Theme.Palette.greenOnDark)
                Text(Money.plain(safeToday)).tabular()
                    .font(.ui(46, .heavy)).kerning(-1.4).foregroundStyle(.white)
            }
            .padding(.top, 5)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.18))
                    Capsule().fill(isOver ? Theme.Palette.amber : Theme.Palette.greenAccent)
                        .frame(width: max(0, min(1, spentFraction)) * geo.size.width)
                }
            }
            .frame(height: 8)
            .padding(.top, 14)

            HStack {
                Text("\(Money.aed(leftThisMonth)) left this month")
                Spacer()
                Text("\(daysRemaining) \(daysRemaining == 1 ? "day" : "days") to go")
            }
            .font(.ui(12)).foregroundStyle(Theme.Palette.greenOnDark)
            .padding(.top, 9)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.green)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.largeSummary, style: .continuous))
        .appShadow(.greenCard)
    }

    // MARK: Stat tiles

    private var statTiles: some View {
        HStack(spacing: 9) {
            statTile("Income", monthIncome, Theme.Palette.ink)
            statTile("Spent", monthExpense, Theme.Palette.clay)
            statTile("Saved", saved, Theme.Palette.green)
        }
    }

    private func statTile(_ label: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.ui(11)).foregroundStyle(Theme.Palette.muted)
            Text(Money.plain(value)).tabular()
                .font(.ui(17, .heavy)).foregroundStyle(color)
        }
        .padding(.vertical, 13).padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .appShadow(.card)
    }

    // MARK: Upcoming

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Upcoming this week")
                .font(.ui(15, .bold)).foregroundStyle(Theme.Palette.ink)
                .padding(.horizontal, 4)
            Card(padding: 4) {
                VStack(spacing: 0) {
                    if upcoming.isEmpty {
                        Text("Nothing due in the next 7 days.")
                            .font(.ui(13)).foregroundStyle(Theme.Palette.muted)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    }
                    ForEach(Array(upcoming.enumerated()), id: \.element.persistentModelID) { idx, r in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color(hex: r.tintHex)).frame(width: 32, height: 32)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(r.name).font(.ui(14, .semibold)).foregroundStyle(Theme.Palette.ink)
                                Text("\(r.categoryName) · \(dueCopy(daysUntil(r.dueDay)))")
                                    .font(.ui(11)).foregroundStyle(Theme.Palette.faint)
                            }
                            Spacer()
                            Text("−\(Money.plain(r.amount))").tabular()
                                .font(.ui(14, .bold)).foregroundStyle(Theme.Palette.clay)
                        }
                        .padding(.vertical, 11).padding(.horizontal, 11)
                        if idx < upcoming.count - 1 {
                            Rectangle().fill(Theme.Palette.hairlineSoft).frame(height: 1)
                                .padding(.leading, 44)
                        }
                    }
                }
            }
        }
    }

    // MARK: Year net card + grid

    private var yearNetCard: some View {
        Card(padding: 20, radius: Theme.Radius.largeSummary) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Total savings")
                        .font(.ui(14)).foregroundStyle(Theme.Palette.inkSecondary)
                    Spacer()
                    Pill(text: "\(savingsRate)% rate", bg: Theme.Palette.greenSoft3)
                }
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("AED").font(.ui(16, .semibold)).foregroundStyle(Theme.Palette.inkSecondary)
                    Text(Money.plain(totalSavings)).tabular()
                        .font(.ui(38, .heavy)).kerning(-1)
                        .foregroundStyle(totalSavings >= 0 ? Theme.Palette.green : Theme.Palette.clay)
                }
                if startingSavings > 0 {
                    Text("Starting \(Money.plain(startingSavings)) + \(Money.plain(allTimeNet)) saved")
                        .font(.ui(12)).foregroundStyle(Theme.Palette.muted)
                }
                Rectangle().fill(Theme.Palette.hairline).frame(height: 1)
                HStack(spacing: 0) {
                    legendCell("Income", yearIncome, dot: Theme.Palette.green)
                    legendCell("Expenses", yearExpense, dot: Theme.Palette.clay)
                }
                HStack {
                    Text("Net saved this year").font(.ui(12)).foregroundStyle(Theme.Palette.muted)
                    Spacer()
                    Text(Money.aed(yearNet)).tabular()
                        .font(.ui(13, .bold))
                        .foregroundStyle(yearNet >= 0 ? Theme.Palette.green : Theme.Palette.clay)
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
