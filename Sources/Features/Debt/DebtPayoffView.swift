import SwiftUI
import SwiftData

/// V2-3 · Debt payoff tracker — sits alongside Savings goals. Summary of all
/// debts, per-debt progress, and an Avalanche/Snowball strategy that recomputes
/// payoff order and projected debt-free date via a month-by-month simulation.
struct DebtPayoffView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Debt.order) private var debts: [Debt]
    @AppStorage("debtStrategy") private var strategyRaw = DebtStrategy.avalanche.rawValue
    @State private var showAdd = false

    private var strategy: DebtStrategy { DebtStrategy(rawValue: strategyRaw) ?? .avalanche }

    private var totalRemaining: Double { debts.reduce(0) { $0 + $1.balance } }
    private var totalOpening: Double { debts.reduce(0) { $0 + $1.openingBalance } }
    private var overallPaid: Double { totalOpening > 0 ? max(0, 1 - totalRemaining / totalOpening) : 0 }
    private var monthlyToDebts: Double { debts.reduce(0) { $0 + $1.monthlyPayment } }
    private var result: DebtPayoffResult { DebtPlanner.simulate(debts, strategy: strategy) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                header
                summaryCard
                Text("Your debts").font(.ui(15, .bold)).foregroundStyle(Theme.Palette.ink)
                    .padding(.horizontal, 4)
                debtList
                footer
            }
            .padding(.horizontal, Theme.Spacing.side)
            .padding(.bottom, Theme.Spacing.bottomSafe)
            .readableContent()
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAdd) {
            AddDebtSheet { name, balance, apr, payment, color, tint in
                let order = (debts.map(\.order).max() ?? -1) + 1
                context.insert(Debt(name: name, balance: balance, openingBalance: balance, apr: apr,
                                    monthlyPayment: payment, colorHex: color, tintHex: tint, order: order))
                try? context.save()
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("GOALS · DEBT").font(.mono(11, .medium)).kerning(0.5)
                .foregroundStyle(Theme.Palette.muted)
            Text("Debt payoff").font(.ui(26, .heavy)).kerning(-0.6)
                .foregroundStyle(Theme.Palette.ink)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Summary

    private var summaryCard: some View {
        Card(padding: 20, radius: Theme.Radius.summary) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text("Total remaining").font(.ui(13)).foregroundStyle(Theme.Palette.muted)
                    Spacer()
                    if !debts.isEmpty {
                        Text("Debt-free \(DebtPlanner.dateLabel(monthsFromNow: result.totalMonths))")
                            .font(.ui(12, .bold)).foregroundStyle(Theme.Palette.green)
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(Theme.Palette.greenSoft3).clipShape(Capsule())
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("AED").font(.ui(16, .semibold)).foregroundStyle(Theme.Palette.inkSecondary)
                    Text(Money.plain(totalRemaining)).tabular()
                        .font(.ui(36, .heavy)).kerning(-1).foregroundStyle(Theme.Palette.ink)
                }
                .padding(.top, 6)
                TrackBar(fraction: overallPaid, height: 9, fill: Theme.Palette.green)
                    .padding(.top, 14)
                HStack {
                    Text("\(Int((overallPaid * 100).rounded()))% paid off")
                    Spacer()
                    Text("\(Money.aed(monthlyToDebts))/mo to debts")
                }
                .font(.ui(11)).foregroundStyle(Theme.Palette.muted)
                .padding(.top, 8)
            }
        }
    }

    // MARK: List

    private var debtList: some View {
        VStack(spacing: 11) {
            if debts.isEmpty {
                Card { Text("No debts tracked. Add one to project a payoff date.")
                    .font(.ui(13)).foregroundStyle(Theme.Palette.muted) }
            }
            ForEach(debts, id: \.persistentModelID) { debt in
                DebtCard(debt: debt, payoffMonths: result.payoffMonths[debt.id])
            }
        }
    }

    // MARK: Footer (strategy toggle + add)

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                strategyRaw = (strategy == .avalanche ? DebtStrategy.snowball : .avalanche).rawValue
            } label: {
                Text(strategy.label)
                    .font(.ui(13, .semibold)).foregroundStyle(Theme.Palette.green)
                    .frame(maxWidth: .infinity).padding(14)
                    .background(Theme.Palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                        .stroke(Theme.Palette.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            Button { showAdd = true } label: {
                Text("+ Add debt")
                    .font(.ui(13, .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(14)
                    .background(Theme.Palette.green)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Debt card

private struct DebtCard: View {
    let debt: Debt
    let payoffMonths: Int?

    private var meta: String {
        let apr = debt.apr == 0 ? "0% · interest-free" : "\(DebtPlanner.aprText(debt.apr))% APR"
        if let m = payoffMonths { return "\(apr) · \(m) mo left" }
        return apr
    }
    private var payoffLabel: String {
        guard let m = payoffMonths else { return "—" }
        return "Done \(DebtPlanner.dateLabel(monthsFromNow: m))"
    }

    var body: some View {
        Card(padding: 16, radius: Theme.Radius.card) {
            VStack(spacing: 12) {
                HStack(spacing: 11) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: debt.tintHex)).frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(debt.name).font(.ui(14, .bold)).foregroundStyle(Theme.Palette.ink)
                        Text(meta).font(.ui(11)).foregroundStyle(Theme.Palette.faint)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(Money.plain(debt.balance)).tabular()
                            .font(.ui(15, .heavy)).foregroundStyle(Theme.Palette.ink)
                        Text("\(Money.plain(debt.monthlyPayment))/mo")
                            .font(.ui(10)).foregroundStyle(Theme.Palette.muted)
                    }
                }
                TrackBar(fraction: debt.fill, height: 6,
                         fill: debt.isHighRate ? Theme.Palette.clay : Color(hex: debt.colorHex))
                HStack {
                    Text("\(debt.percentPaid)% paid")
                    Spacer()
                    Text(payoffLabel)
                }
                .font(.ui(11)).foregroundStyle(Theme.Palette.muted)
            }
        }
    }
}

// MARK: - Add debt sheet

private struct AddDebtSheet: View {
    /// (name, balance, apr, monthlyPayment, colorHex, tintHex)
    var onSave: (String, Double, Double, Double, String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var balanceText = ""
    @State private var aprText = ""
    @State private var paymentText = ""

    private var balance: Double { Double(balanceText) ?? 0 }
    private var apr: Double { Double(aprText) ?? 0 }
    private var payment: Double { Double(paymentText) ?? 0 }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && balance > 0 && payment > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Debt") {
                    TextField("Name (e.g. Credit card)", text: $name)
                    HStack { Text("AED").foregroundStyle(Theme.Palette.muted)
                        TextField("Balance", text: $balanceText).keyboardType(.decimalPad) }
                }
                Section("Terms") {
                    HStack { Text("APR %").foregroundStyle(Theme.Palette.muted)
                        TextField("0", text: $aprText).keyboardType(.decimalPad) }
                    HStack { Text("AED").foregroundStyle(Theme.Palette.muted)
                        TextField("Monthly payment", text: $paymentText).keyboardType(.decimalPad) }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Add debt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let high = apr >= 15
                        onSave(name.trimmingCharacters(in: .whitespaces), balance, apr, payment,
                               high ? "#bd5a3c" : Theme.CategoryColor.transport,
                               high ? "#f7e8e1" : "#dde6ea")
                        dismiss()
                    }
                    .fontWeight(.bold).disabled(!canSave)
                }
            }
        }
    }
}

// MARK: - Payoff simulation

enum DebtStrategy: String, CaseIterable {
    case avalanche, snowball
    var label: String { self == .avalanche ? "Avalanche" : "Snowball" }
}

struct DebtPayoffResult {
    var payoffMonths: [UUID: Int]   // months-from-now each debt is cleared
    var totalMonths: Int            // overall debt-free month
}

enum DebtPlanner {
    /// Month-by-month simulation: accrue interest, pay each debt its minimum,
    /// then roll any freed payment into the highest-priority remaining debt
    /// (highest APR for avalanche, smallest balance for snowball).
    static func simulate(_ debts: [Debt], strategy: DebtStrategy) -> DebtPayoffResult {
        guard !debts.isEmpty else { return DebtPayoffResult(payoffMonths: [:], totalMonths: 0) }
        var balance: [UUID: Double] = [:]
        for d in debts { balance[d.id] = d.balance }
        let rate: [UUID: Double] = Dictionary(uniqueKeysWithValues: debts.map { ($0.id, $0.apr / 100 / 12) })
        let minPay: [UUID: Double] = Dictionary(uniqueKeysWithValues: debts.map { ($0.id, $0.monthlyPayment) })
        let pool = debts.reduce(0) { $0 + $1.monthlyPayment }
        var payoff: [UUID: Int] = [:]

        func priority() -> [UUID] {
            let active = debts.filter { (balance[$0.id] ?? 0) > 0.005 }
            switch strategy {
            case .avalanche: return active.sorted { $0.apr > $1.apr }.map(\.id)
            case .snowball:  return active.sorted { (balance[$0.id] ?? 0) < (balance[$1.id] ?? 0) }.map(\.id)
            }
        }

        var month = 0
        while balance.values.contains(where: { $0 > 0.005 }) && month < 600 {
            month += 1
            for d in debts where (balance[d.id] ?? 0) > 0 {
                balance[d.id]! += balance[d.id]! * (rate[d.id] ?? 0)
            }
            var available = pool
            for d in debts where (balance[d.id] ?? 0) > 0 {
                let pay = min(minPay[d.id] ?? 0, balance[d.id]!)
                balance[d.id]! -= pay
                available -= pay
            }
            if available > 0 {
                for id in priority() {
                    guard available > 0.005 else { break }
                    let bal = balance[id] ?? 0
                    guard bal > 0 else { continue }
                    let pay = min(available, bal)
                    balance[id]! -= pay
                    available -= pay
                }
            }
            for d in debts where payoff[d.id] == nil && (balance[d.id] ?? 0) <= 0.005 {
                payoff[d.id] = month
            }
        }
        return DebtPayoffResult(payoffMonths: payoff, totalMonths: payoff.values.max() ?? 0)
    }

    static func dateLabel(monthsFromNow n: Int) -> String {
        let cal = SampleData.cal()
        let base = SampleData.referenceToday
        let date = cal.date(byAdding: .month, value: n, to: base) ?? base
        let f = DateFormatter(); f.calendar = cal; f.dateFormat = "MMM yyyy"
        return f.string(from: date)
    }

    static func aprText(_ apr: Double) -> String {
        apr == apr.rounded() ? "\(Int(apr))" : String(format: "%.1f", apr)
    }
}
