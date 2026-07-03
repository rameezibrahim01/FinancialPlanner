import SwiftUI
import SwiftData

/// V2-2 · Dashboard (home) — "Safe to spend today" is the headline number. A
/// Today/Year toggle keeps the v1 12-month grid reachable. All figures derive
/// from transactions + plan + recurring; nothing new is persisted.
struct DashboardView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage("displayName") private var displayName = ""
    @AppStorage("startingSavings") private var startingSavings = 0.0
    @Query(sort: \MonthPlan.month) private var plans: [MonthPlan]
    @Query private var txns: [Transaction]
    @Query(sort: \Recurring.order) private var recurring: [Recurring]
    @Query(sort: \Category.order) private var categories: [Category]

    @State private var mode: Mode = .today
    @State private var showAdd = false
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
    private var leftThisMonth: Double { monthBudget - monthExpense }
    private var spentFraction: Double { monthBudget > 0 ? min(1, monthExpense / monthBudget) : 0 }
    private var onPlan: Bool { monthExpense <= monthBudget }

    /// The month's budget is exhausted (committed + spent exceed it).
    private var isOver: Bool { safeBase < 0 }
    private var overAmount: Double { max(0, -safeBase) }

    /// Spent so far today, and everything spent earlier this month.
    private var spentToday: Double {
        txns.filter { $0.type == .expense && cal.isDate($0.date, inSameDayAs: today) }
            .reduce(0) { $0 + $1.amount }
    }
    private var expenseBeforeToday: Double { monthExpense - spentToday }
    /// Today's slice of the remaining plan — budget minus still-to-post
    /// commitments and everything spent before today, spread over days left.
    private var todayAllowance: Double {
        max(0, (monthBudget - committedRemaining - expenseBeforeToday) / Double(daysRemaining))
    }
    /// Headline: what's left of today's allowance after today's spend.
    private var safeToday: Double { max(0, todayAllowance - spentToday) }
    private var todaySpentFraction: Double {
        todayAllowance > 0 ? min(1, spentToday / todayAllowance) : (spentToday > 0 ? 1 : 0)
    }

    /// Pace: how far through the month we are, and whether spending is ahead of it.
    private var monthElapsed: Double { min(1, Double(todayDay) / Double(daysInMonth)) }
    private var aheadOfPace: Bool { monthBudget > 0 && spentFraction > monthElapsed + 0.02 }
    private var paceCaption: String {
        if isOver { return "Over your plan" }
        if monthBudget <= 0 { return "No budget set" }
        return aheadOfPace ? "Ahead of pace" : "On pace"
    }

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

    // MARK: Empty state & recent activity

    /// No budget planned for this month yet — the safe-to-spend math is
    /// meaningless, so we show a setup nudge instead of a wall of zeros.
    private var needsBudget: Bool { monthBudget <= 0 }

    /// The five most recent transactions, newest first.
    private var recentTxns: [Transaction] {
        Array(txns.sorted { $0.date > $1.date }.prefix(5))
    }

    /// Accent color for a transaction's category (falls back to a neutral gray).
    private func color(for name: String) -> String {
        if let c = categories.first(where: { $0.name == name }) { return c.colorHex }
        if name == "Salary" { return Theme.CategoryColor.housing }
        return Theme.CategoryColor.other
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = cal
        f.dateFormat = "d MMM"
        return f.string(from: date)
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
                    if needsBudget {
                        setupHint
                        logButton
                    } else {
                        safeToSpendCard
                        logButton
                        statTiles
                        upcomingSection
                    }
                    if !recentTxns.isEmpty {
                        recentSection
                    }
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
        .sheet(isPresented: $showAdd) {
            AddTransactionView()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(MonthPlan.longNames[curMonth - 1].uppercased()) · AED")
                    .font(.mono(11, .medium)).kerning(0.5)
                    .foregroundStyle(Theme.Palette.muted)
                Text(displayName.isEmpty ? "Welcome back" : "Hello, \(displayName)")
                    .font(.ui(30, .heavy)).kerning(-0.8)
                    .foregroundStyle(Theme.Palette.ink)
            }
            Spacer()
            if !needsBudget {
                Pill(text: onPlan ? "On plan" : "Off plan",
                     bg: onPlan ? Theme.Palette.greenSoft : Theme.Palette.claySoft,
                     fg: onPlan ? Theme.Palette.green : Theme.Palette.clay,
                     dot: onPlan ? Theme.Palette.green : Theme.Palette.clay)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: Empty-state setup hint

    private var setupHint: some View {
        Group {
            if let plan = monthPlan {
                NavigationLink {
                    MonthPlanEditorView(plan: plan)
                } label: { setupHintCard }
                .buttonStyle(.plain)
            } else {
                setupHintCard
            }
        }
    }

    private var setupHintCard: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.Palette.green).frame(width: 44, height: 44)
                .overlay(Image(systemName: "wand.and.stars")
                    .font(.system(size: 19, weight: .semibold)).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 3) {
                Text("Set up \(MonthPlan.longNames[curMonth - 1])")
                    .font(.ui(16, .bold)).foregroundStyle(Theme.Palette.ink)
                Text("Add this month's income and budget to unlock your daily safe-to-spend.")
                    .font(.ui(12)).foregroundStyle(Theme.Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Palette.green)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Theme.Palette.greenSoft2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.largeSummary, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.largeSummary, style: .continuous)
            .stroke(Color(hex: "#cfe0d6"), lineWidth: 1))
    }

    // MARK: Recent activity

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent activity")
                .font(.ui(15, .bold)).foregroundStyle(Theme.Palette.ink)
                .padding(.horizontal, 4)
            Card(padding: 4) {
                VStack(spacing: 0) {
                    ForEach(Array(recentTxns.enumerated()), id: \.element.persistentModelID) { idx, t in
                        recentRow(t)
                        if idx < recentTxns.count - 1 {
                            Rectangle().fill(Theme.Palette.hairlineSoft).frame(height: 1)
                                .padding(.leading, 44)
                        }
                    }
                }
            }
        }
    }

    private func recentRow(_ t: Transaction) -> some View {
        let income = t.type == .income
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(hex: color(for: t.categoryName)).opacity(0.18))
                .frame(width: 32, height: 32)
                .overlay(Circle().fill(Color(hex: color(for: t.categoryName))).frame(width: 9, height: 9))
            VStack(alignment: .leading, spacing: 1) {
                Text(t.note.isEmpty ? t.categoryName : t.note)
                    .font(.ui(14, .semibold)).foregroundStyle(Theme.Palette.ink).lineLimit(1)
                Text("\(dayLabel(t.date)) · \(t.categoryName)")
                    .font(.ui(11)).foregroundStyle(Theme.Palette.faint)
            }
            Spacer()
            Text("\(income ? "+" : "−")\(Money.plain(t.amount))").tabular()
                .font(.ui(14, .bold))
                .foregroundStyle(income ? Theme.Palette.green : Theme.Palette.clay)
        }
        .padding(.vertical, 11).padding(.horizontal, 11)
    }

    // MARK: Safe to spend hero

    private var heroSubtle: Color { isOver ? Color.white.opacity(0.82) : Theme.Palette.greenOnDark }

    private var safeToSpendCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(isOver ? "Over budget this month" : "Safe to spend today")
                .font(.ui(13)).foregroundStyle(heroSubtle)
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("AED").font(.ui(16, .semibold)).foregroundStyle(heroSubtle)
                Text(Money.plain(isOver ? overAmount : safeToday)).tabular()
                    .font(.ui(46, .heavy)).kerning(-1.4).foregroundStyle(.white)
            }
            .padding(.top, 5)

            // Pace meter: budget used (fill) vs month elapsed (tick).
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.18))
                    Capsule().fill(barFill)
                        .frame(width: max(0, min(1, spentFraction)) * w)
                    if monthBudget > 0 {
                        Rectangle().fill(Color.white.opacity(0.7))
                            .frame(width: 2, height: 8)
                            .offset(x: min(1, monthElapsed) * w - 1)
                    }
                }
            }
            .frame(height: 8)
            .padding(.top, 14)

            HStack {
                Text(paceCaption)
                Spacer()
                Text("\(daysRemaining) \(daysRemaining == 1 ? "day" : "days") to go")
            }
            .font(.ui(12, .semibold)).foregroundStyle(heroSubtle)
            .padding(.top, 9)

            HStack {
                Text(isOver
                     ? "Spent \(Money.aed(monthExpense)) of \(Money.plain(monthBudget))"
                     : "Spent today \(Money.aed(spentToday)) of \(Money.plain(todayAllowance))")
                Spacer()
                Text("\(Money.aed(leftThisMonth)) left")
            }
            .font(.ui(12)).foregroundStyle(heroSubtle)
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isOver ? Theme.Palette.clay : Theme.Palette.green)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.largeSummary, style: .continuous))
        .appShadow(isOver ? .card : .greenCard)
    }

    /// Fill color for the pace meter: white when over, amber when ahead of pace,
    /// green otherwise.
    private var barFill: Color {
        if isOver { return Color.white.opacity(0.85) }
        return aheadOfPace ? Theme.Palette.amber : Theme.Palette.greenAccent
    }

    // MARK: Log expense CTA

    private var logButton: some View {
        Button { showAdd = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill").font(.system(size: 18, weight: .semibold))
                Text("Log expense").font(.ui(16, .bold))
            }
            .foregroundStyle(Theme.Palette.green)
            .frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(Theme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                .stroke(Theme.Palette.greenSoft, lineWidth: 1))
            .appShadow(.card)
        }
        .buttonStyle(.plain)
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
