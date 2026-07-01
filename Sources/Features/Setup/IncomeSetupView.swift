import SwiftUI
import SwiftData

/// A2 · Income setup — add recurring income sources; baseline for plans. The
/// projected annual income is the sum of every source's amount × 12.
struct IncomeSetupView: View {
    var onFinish: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \IncomeSource.amount, order: .reverse) private var sources: [IncomeSource]
    @Query private var plans: [MonthPlan]
    @AppStorage("startingSavings") private var startingSavings = 0.0
    @State private var showAdd = false

    private var monthlyIncome: Double { sources.reduce(0) { $0 + $1.amount } }
    private var projectedAnnual: Double { monthlyIncome * 12 }

    /// Carries the monthly income total into every month's plan so the planning
    /// screen is populated after setup. Only fills months not already set, so it
    /// never clobbers income the user (or demo data) has already entered.
    private func finishSetup() {
        for plan in plans where plan.plannedIncome == 0 {
            plan.plannedIncome = monthlyIncome
        }
        try? context.save()
        onFinish()
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    header
                    VStack(spacing: 12) {
                        ForEach(sources, id: \.persistentModelID) { source in
                            IncomeSourceCard(source: source)
                        }
                        DashedAddTile(title: "+ Add income source") { showAdd = true }
                    }
                    savingsField
                    summaryBar
                }
                .padding(.horizontal, Theme.Spacing.side)
                .padding(.top, 8)
                .padding(.bottom, Theme.Spacing.bottomSafe)
                .readableContent(640)
            }
            .scrollDismissesKeyboard(.immediately)
            footer
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAdd) {
            AddIncomeSheet { name, cadence, amount, recurring in
                let tints = ["#dbeae1", "#e6ead7", "#eef6f1", "#eaf2ed"]
                let tint = tints[sources.count % tints.count]
                context.insert(IncomeSource(name: name, cadence: cadence, amount: amount,
                                            recurring: recurring, tintHex: tint))
                try? context.save()
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SETUP").font(.mono(11, .medium)).kerning(0.5)
                .foregroundStyle(Theme.Palette.faint)
            Text("Your income").font(.ui(26, .heavy)).kerning(-0.6)
                .foregroundStyle(Theme.Palette.ink)
            Text("Add the income you expect each month. You can change this anytime.")
                .font(.ui(14)).foregroundStyle(Theme.Palette.inkSecondary)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Current savings

    private var savingsField: some View {
        Card(padding: 16, radius: Theme.Radius.card) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Current savings").font(.ui(14, .semibold)).foregroundStyle(Theme.Palette.ink)
                    Text("What you've already put aside").font(.ui(11)).foregroundStyle(Theme.Palette.faint)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("AED").font(.ui(13)).foregroundStyle(Theme.Palette.muted)
                    TextField("0", value: $startingSavings, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.ui(16, .bold))
                        .frame(maxWidth: 110)
                }
            }
        }
    }

    // MARK: Projected-income summary bar

    private var summaryBar: some View {
        HStack {
            Text("Projected annual income")
                .font(.ui(13, .semibold)).foregroundStyle(Theme.Palette.green)
            Spacer()
            Text(Money.aed(projectedAnnual)).tabular()
                .font(.ui(20, .heavy)).foregroundStyle(Theme.Palette.green)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Theme.Palette.greenSoft2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    // MARK: Footer

    private var footer: some View {
        PrimaryButton(title: "Continue to planning", action: finishSetup)
            .padding(.horizontal, Theme.Spacing.side)
            .padding(.top, 8)
            .padding(.bottom, Theme.Spacing.bottomSafe)
            .readableContent(640)
            .background(Theme.Palette.page)
    }
}

// MARK: - Income source card

private struct IncomeSourceCard: View {
    let source: IncomeSource

    var body: some View {
        Card(padding: 15, radius: Theme.Radius.card) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color(hex: source.tintHex))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: "banknote")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.Palette.green)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.name).font(.ui(15, .bold)).foregroundStyle(Theme.Palette.ink)
                    Text(source.cadence).font(.ui(12)).foregroundStyle(Theme.Palette.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Money.aed(source.amount)).tabular()
                        .font(.ui(16, .heavy)).foregroundStyle(Theme.Palette.ink)
                    if source.recurring {
                        Text("recurring").font(.ui(11, .semibold)).foregroundStyle(Theme.Palette.green)
                    }
                }
            }
        }
    }
}

// MARK: - Add income sheet

private struct AddIncomeSheet: View {
    /// (name, cadence, amount, recurring)
    var onSave: (String, String, Double, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amountText = ""
    @State private var monthly = true
    @State private var recurring = true

    private var amount: Double { Double(amountText) ?? 0 }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Source") {
                    TextField("Name (e.g. Salary)", text: $name)
                }
                Section("Amount") {
                    HStack {
                        Text("AED").foregroundStyle(Theme.Palette.muted)
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                    }
                    Picker("Cadence", selection: $monthly) {
                        Text("Monthly").tag(true)
                        Text("Avg / month").tag(false)
                    }
                    Toggle("Recurring", isOn: $recurring)
                        .tint(Theme.Palette.green)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Add income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(name.trimmingCharacters(in: .whitespaces),
                               monthly ? "Monthly" : "Avg / month", amount, recurring)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(!canSave)
                }
            }
        }
    }
}
