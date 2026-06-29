import SwiftUI
import SwiftData

/// D2 · Year in review & settings — year summary stat grid, a data/settings
/// list, and an "Export backup file" action that serializes all on-device data
/// to a JSON file the user can save or share (no network).
struct SettingsView: View {
    @Query(sort: \MonthPlan.month) private var plans: [MonthPlan]
    @Query private var txns: [Transaction]
    @Query(sort: \Category.order) private var categories: [Category]
    @Query(sort: \Goal.order) private var goals: [Goal]

    private let year = SampleData.year
    private let yearSavingsGoal: Double = 60000

    @State private var remindersOn = true
    @State private var rollOverOn = true
    @State private var backupURL: URL?

    // MARK: Derived

    private var totalIncome: Double { txns.filter { $0.type == .income }.reduce(0) { $0 + $1.amount } }
    private var totalExpense: Double { txns.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount } }
    private var netSaved: Double { totalIncome - totalExpense }
    private var savingsRate: Int { totalIncome > 0 ? Int((netSaved / totalIncome * 100).rounded()) : 0 }

    private var expenseByCategory: [(name: String, amount: Double)] {
        Dictionary(grouping: txns.filter { $0.type == .expense }, by: \.categoryName)
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
            .sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }
    private var biggestCost: (name: String, amount: Double)? { expenseByCategory.first }
    private var biggestCostPct: Int {
        guard let b = biggestCost, totalExpense > 0 else { return 0 }
        return Int((b.amount / totalExpense * 100).rounded())
    }

    private func expense(in plan: MonthPlan) -> Double {
        let cal = SampleData.cal()
        return txns.filter {
            $0.type == .expense
            && cal.component(.year, from: $0.date) == plan.year
            && cal.component(.month, from: $0.date) == plan.month
        }.reduce(0) { $0 + $1.amount }
    }
    private var monthsOnBudget: Int { plans.filter { expense(in: $0) <= $0.budgetTotal }.count }

    private let statColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                header
                statGrid
                settingsList
                exportButton
            }
            .padding(.horizontal, Theme.Spacing.side)
            .padding(.top, 8)
            .padding(.bottom, Theme.Spacing.bottomSafe)
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .task { backupURL = try? Backup.write(plans: plans, txns: txns, goals: goals, year: year) }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("REVIEW · 2026").font(.mono(11, .medium)).kerning(0.5)
                .foregroundStyle(Theme.Palette.muted)
            Text("Year in review").font(.ui(26, .heavy)).kerning(-0.6)
                .foregroundStyle(Theme.Palette.ink)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Stat grid (2×2)

    private var statGrid: some View {
        LazyVGrid(columns: statColumns, spacing: 10) {
            // Total saved — green highlight card with white text.
            VStack(alignment: .leading, spacing: 6) {
                Text("Total saved").font(.ui(12)).foregroundStyle(Theme.Palette.greenOnDark)
                Text(Money.aed(netSaved)).tabular()
                    .font(.ui(22, .heavy)).foregroundStyle(.white)
                Text("vs \(Money.plain(yearSavingsGoal)) planned")
                    .font(.ui(11)).foregroundStyle(Theme.Palette.greenOnDark2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .background(Theme.Palette.green)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .appShadow(.greenCard)

            statCard("Savings rate", "\(savingsRate)%", sub: "of income")
            statCard("Biggest cost", biggestCost?.name ?? "—",
                     sub: biggestCost != nil ? "\(biggestCostPct)% · \(Money.plain(biggestCost!.amount))" : "")
            statCard("Months on budget", "\(monthsOnBudget) of 12",
                     sub: monthsOnBudget == 12 ? "all clear" : "\(12 - monthsOnBudget) over")
        }
    }

    private func statCard(_ label: String, _ value: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.ui(12)).foregroundStyle(Theme.Palette.muted)
            Text(value).font(.ui(22, .heavy)).foregroundStyle(Theme.Palette.ink).lineLimit(1)
            Text(sub).font(.ui(11)).foregroundStyle(Theme.Palette.faint).lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(Theme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .appShadow(.card)
    }

    // MARK: Data & settings list

    private var settingsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Data & settings").font(.ui(15, .bold)).foregroundStyle(Theme.Palette.ink)
                .padding(.horizontal, 4)
            Card(padding: 4, radius: Theme.Radius.card) {
                VStack(spacing: 0) {
                    valueRow("Currency", "AED", tint: Theme.Palette.greenSoft, icon: "coloncurrencysign.circle")
                    divider
                    toggleRow("Monthly reminders", isOn: $remindersOn, tint: Theme.Palette.greenSoft2, icon: "bell")
                    divider
                    valueRow("Local backup", "Daily", tint: Theme.Palette.greenSoft3, icon: "externaldrive")
                    divider
                    valueRow("Categories", "\(categories.count)", tint: Theme.Palette.claySoft, icon: "square.grid.2x2")
                    divider
                    toggleRow("Roll over balance", isOn: $rollOverOn, tint: Theme.Palette.greenSoft, icon: "arrow.triangle.2.circlepath")
                }
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.Palette.hairlineSoft).frame(height: 1).padding(.leading, 50)
    }

    private func rowIcon(_ tint: Color, _ icon: String) -> some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(tint)
            .frame(width: 30, height: 30)
            .overlay(Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Palette.green))
    }

    private func valueRow(_ name: String, _ value: String, tint: Color, icon: String) -> some View {
        HStack(spacing: 12) {
            rowIcon(tint, icon)
            Text(name).font(.ui(14, .semibold)).foregroundStyle(Theme.Palette.ink)
            Spacer()
            Text(value).font(.ui(14)).foregroundStyle(Theme.Palette.muted)
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: "#cdd2cb"))
        }
        .padding(.vertical, 10).padding(.horizontal, 10)
    }

    private func toggleRow(_ name: String, isOn: Binding<Bool>, tint: Color, icon: String) -> some View {
        HStack(spacing: 12) {
            rowIcon(tint, icon)
            Text(name).font(.ui(14, .semibold)).foregroundStyle(Theme.Palette.ink)
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(Theme.Palette.green)
        }
        .padding(.vertical, 10).padding(.horizontal, 10)
    }

    // MARK: Export

    @ViewBuilder private var exportButton: some View {
        if let backupURL {
            ShareLink(item: backupURL) {
                Text("Export backup file")
                    .font(.ui(16, .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(16)
                    .background(Theme.Palette.green)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                    .appShadow(.primaryButton)
            }
        } else {
            Text("Preparing backup…")
                .font(.ui(14)).foregroundStyle(Theme.Palette.muted)
                .frame(maxWidth: .infinity).padding(16)
        }
    }
}

// MARK: - Backup serialization (offline JSON snapshot)

enum Backup {
    struct Snapshot: Codable {
        struct Tx: Codable { var type: String; var amount: Double; var category: String; var date: Date; var note: String }
        struct Budget: Codable { var category: String; var amount: Double }
        struct Plan: Codable { var year: Int; var month: Int; var plannedIncome: Double; var budgets: [Budget] }
        struct GoalSnap: Codable { var name: String; var target: Double; var saved: Double; var monthlyContribution: Double }
        var exportedYear: Int
        var transactions: [Tx]
        var plans: [Plan]
        var goals: [GoalSnap]
    }

    /// Serializes all data to a JSON file in the temp directory and returns its URL.
    static func write(plans: [MonthPlan], txns: [Transaction], goals: [Goal], year: Int) throws -> URL {
        let snapshot = Snapshot(
            exportedYear: year,
            transactions: txns.map {
                .init(type: $0.type.rawValue, amount: $0.amount, category: $0.categoryName,
                      date: $0.date, note: $0.note)
            },
            plans: plans.map { p in
                .init(year: p.year, month: p.month, plannedIncome: p.plannedIncome,
                      budgets: p.orderedBudgets.map { .init(category: $0.categoryName, amount: $0.amount) })
            },
            goals: goals.map {
                .init(name: $0.name, target: $0.target, saved: $0.saved,
                      monthlyContribution: $0.monthlyContribution)
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FinancialPlanner-\(year)-backup.json")
        try data.write(to: url, options: .atomic)
        return url
    }
}
