import SwiftUI
import SwiftData

/// D2 · Year in review & settings — year summary stat grid, a data/settings
/// list, and an "Export backup file" action that serializes all on-device data
/// to a JSON file the user can save or share (no network).
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MonthPlan.month) private var plans: [MonthPlan]
    @Query private var txns: [Transaction]
    @Query(sort: \Category.order) private var categories: [Category]

    private let yearSavingsGoal: Double = 60000

    @State private var remindersOn = true
    @State private var rollOverOn = true
    @AppStorage("appLock") private var appLock = false
    @AppStorage("lockTimeout") private var lockTimeout = 0   // minutes; 0 = immediately
    @AppStorage("startingSavings") private var startingSavings = 0.0
    @State private var showClearConfirm = false

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
                securitySection
                developerSection
            }
            .padding(.horizontal, Theme.Spacing.side)
            .padding(.top, 8)
            .padding(.bottom, Theme.Spacing.bottomSafe)
            .readableContent()
        }
        .screenBackground()
        .scrollDismissesKeyboard(.immediately)
        .navBarHiddenInCompact()
        .alert("Clear all data?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear everything", role: .destructive) { clearAllData() }
        } message: {
            Text("Wipes all plans, transactions, goals, recurring, debts and settings, and restarts onboarding. This can't be undone.")
        }
    }

    // MARK: Developer (temporary — for testing)

    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Developer").font(.ui(15, .bold)).foregroundStyle(Theme.Palette.ink)
                .padding(.horizontal, 4)
            Button {
                showClearConfirm = true
            } label: {
                Text("Clear all data")
                    .font(.ui(16, .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(16)
                    .background(Theme.Palette.clay)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
            }
            .buttonStyle(.plain)
            Text("Testing only — resets the app to a fresh install and restarts onboarding.")
                .font(.ui(11)).foregroundStyle(Theme.Palette.muted).padding(.horizontal, 4)
        }
    }

    /// Wipes every model + persisted preference, then re-seeds the essential
    /// scaffolding so the app restarts at onboarding, as if freshly installed.
    private func clearAllData() {
        try? context.delete(model: Transaction.self)
        try? context.delete(model: CategoryBudget.self)
        try? context.delete(model: MonthPlan.self)
        try? context.delete(model: Goal.self)
        try? context.delete(model: Recurring.self)
        try? context.delete(model: Debt.self)
        try? context.delete(model: IncomeSource.self)
        try? context.delete(model: Category.self)
        try? context.save()

        for key in ["hasCompletedOnboarding", "displayName", "startingSavings",
                    "appLock", "lockTimeout", "autoBackup", "lastBackupAt",
                    "pendingTab", "debtStrategy"] {
            UserDefaults.standard.removeObject(forKey: key)
        }

        SampleData.seedIfNeeded(context)
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
                    startingSavingsRow
                    divider
                    valueRow("Currency", "AED", tint: Theme.Palette.greenSoft, icon: "coloncurrencysign.circle")
                    divider
                    toggleRow("Monthly reminders", isOn: $remindersOn, tint: Theme.Palette.greenSoft2, icon: "bell")
                    divider
                    NavigationLink {
                        BackupView()
                    } label: {
                        valueRow("Backup & data", "", tint: Theme.Palette.greenSoft3, icon: "externaldrive")
                    }
                    .buttonStyle(.plain)
                    divider
                    valueRow("Categories", "\(categories.count)", tint: Theme.Palette.claySoft, icon: "square.grid.2x2")
                    divider
                    toggleRow("Roll over balance", isOn: $rollOverOn, tint: Theme.Palette.greenSoft, icon: "arrow.triangle.2.circlepath")
                }
            }
        }
    }

    // MARK: Security (V2-5)

    private var timeoutLabel: String {
        lockTimeout == 0 ? "Immediately" : "After \(lockTimeout) min"
    }

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Security").font(.ui(15, .bold)).foregroundStyle(Theme.Palette.ink)
                .padding(.horizontal, 4)
            Card(padding: 4, radius: Theme.Radius.card) {
                VStack(spacing: 0) {
                    toggleRow("App Lock (Face ID)", isOn: $appLock,
                              tint: Theme.Palette.greenSoft, icon: "faceid")
                    if appLock {
                        divider
                        HStack(spacing: 12) {
                            rowIcon(Theme.Palette.greenSoft2, "lock.rotation")
                            Text("Auto-lock").font(.ui(14, .semibold)).foregroundStyle(Theme.Palette.ink)
                            Spacer()
                            Menu {
                                Button("Immediately") { lockTimeout = 0 }
                                Button("After 1 minute") { lockTimeout = 1 }
                                Button("After 5 minutes") { lockTimeout = 5 }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(timeoutLabel).font(.ui(14)).foregroundStyle(Theme.Palette.muted)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Theme.Palette.faint)
                                }
                            }
                        }
                        .padding(.vertical, 10).padding(.horizontal, 10)
                    }
                }
            }
        }
    }

    private var startingSavingsRow: some View {
        HStack(spacing: 12) {
            rowIcon(Theme.Palette.greenSoft, "banknote")
            Text("Starting savings").font(.ui(14, .semibold)).foregroundStyle(Theme.Palette.ink)
            Spacer()
            Text("AED").font(.ui(13)).foregroundStyle(Theme.Palette.muted)
            TextField("0", value: $startingSavings, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.ui(14, .semibold))
                .frame(maxWidth: 110)
        }
        .padding(.vertical, 10).padding(.horizontal, 10)
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

}
