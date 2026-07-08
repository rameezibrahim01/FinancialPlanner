import SwiftUI
import SwiftData

/// A2 · Income setup — your name, income sources, and starting savings; the
/// baseline for plans. Monthly income (sum of sources) is carried into the
/// current month and every later month.
struct IncomeSetupView: View {
    var onFinish: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \IncomeSource.amount, order: .reverse) private var sources: [IncomeSource]
    @Query private var plans: [MonthPlan]
    @AppStorage("startingSavings") private var startingSavings = 0.0
    @AppStorage("displayName") private var displayName = ""
    @State private var showAdd = false
    @State private var editingSource: IncomeSource?
    @State private var savingsText = ""
    @State private var goToBudget = false

    private var monthlyIncome: Double { sources.reduce(0) { $0 + $1.amount } }
    private var projectedAnnual: Double { monthlyIncome * 12 }
    private var currentMonth: Int { SampleData.cal().component(.month, from: SampleData.referenceToday) }
    private var currentYear: Int { SampleData.cal().component(.year, from: SampleData.referenceToday) }

    /// Carries the latest monthly income into the current month and every later
    /// month, overwriting so edits made here always propagate. Past months stay
    /// at 0 (you weren't planning then).
    private func applyIncome() {
        for plan in plans where plan.year == currentYear && plan.month >= currentMonth {
            plan.plannedIncome = monthlyIncome
        }
        try? context.save()
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    header
                    nameField
                    VStack(spacing: 12) {
                        ForEach(sources, id: \.persistentModelID) { source in
                            Button { editingSource = source } label: {
                                IncomeSourceCard(source: source)
                            }
                            .buttonStyle(.plain)
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
        .navigationDestination(isPresented: $goToBudget) {
            BudgetSetupView(onFinish: onFinish)
        }
        .onAppear { savingsText = startingSavings > 0 ? String(Int(startingSavings)) : "" }
        .sheet(isPresented: $showAdd) {
            IncomeEditorSheet(existing: nil) { fields in
                let tints = ["#dbeae1", "#e6ead7", "#eef6f1", "#eaf2ed"]
                let tint = tints[sources.count % tints.count]
                context.insert(IncomeSource(name: fields.name, cadence: fields.cadence,
                                            amount: fields.amount, recurring: fields.recurring, tintHex: tint))
                try? context.save()
            }
        }
        .sheet(item: $editingSource) { source in
            IncomeEditorSheet(existing: source, onSave: { fields in
                source.name = fields.name
                source.cadence = fields.cadence
                source.amount = fields.amount
                source.recurring = fields.recurring
                try? context.save()
            }, onDelete: {
                context.delete(source)
                try? context.save()
            })
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SETUP · 1 OF 2").font(.mono(11, .medium)).kerning(0.5)
                .foregroundStyle(Theme.Palette.faint)
            Text("Your income").font(.ui(26, .heavy)).kerning(-0.6)
                .foregroundStyle(Theme.Palette.ink)
            Text("Add the income you expect each month. You can change this anytime.")
                .font(.ui(14)).foregroundStyle(Theme.Palette.inkSecondary)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Name

    private var nameField: some View {
        Card(padding: 16, radius: Theme.Radius.card) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Your name").font(.ui(14, .semibold)).foregroundStyle(Theme.Palette.ink)
                    Text("So the app can greet you").font(.ui(11)).foregroundStyle(Theme.Palette.faint)
                }
                Spacer()
                TextField("Optional", text: $displayName)
                    .multilineTextAlignment(.trailing)
                    .font(.ui(16, .semibold)).foregroundStyle(Theme.Palette.ink)
                    .frame(maxWidth: 170)
            }
        }
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
                    TextField("0", text: $savingsText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.ui(16, .bold))
                        .frame(maxWidth: 110)
                        .onChange(of: savingsText) { _, v in
                            startingSavings = Double(v.filter { $0.isNumber || $0 == "." }) ?? 0
                        }
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
        PrimaryButton(title: "Continue") { applyIncome(); goToBudget = true }
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
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "#cdd2cb"))
            }
        }
    }
}

// MARK: - Add / edit income sheet

struct IncomeFields {
    var name: String
    var cadence: String
    var amount: Double
    var recurring: Bool
}

private struct IncomeEditorSheet: View {
    let existing: IncomeSource?
    var onSave: (IncomeFields) -> Void
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var amountText: String
    @State private var monthly: Bool
    @State private var recurring: Bool

    init(existing: IncomeSource?,
         onSave: @escaping (IncomeFields) -> Void,
         onDelete: (() -> Void)? = nil) {
        self.existing = existing
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: existing?.name ?? "")
        _amountText = State(initialValue: existing.map { $0.amount > 0 ? String(Int($0.amount)) : "" } ?? "")
        _monthly = State(initialValue: existing.map { $0.cadence == "Monthly" } ?? true)
        _recurring = State(initialValue: existing?.recurring ?? true)
    }

    private var amount: Double { Double(amountText.filter { $0.isNumber || $0 == "." }) ?? 0 }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0 }
    private var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Source") {
                    TextField("Name (e.g. Salary)", text: $name)
                }
                Section("Amount") {
                    HStack {
                        Text("AED").foregroundStyle(Theme.Palette.muted)
                        TextField("0", text: $amountText).keyboardType(.decimalPad)
                    }
                    Picker("Cadence", selection: $monthly) {
                        Text("Monthly").tag(true)
                        Text("Avg / month").tag(false)
                    }
                    Toggle("Recurring", isOn: $recurring).tint(Theme.Palette.green)
                }
                if isEditing, let onDelete {
                    Section {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Text("Delete income source").frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(isEditing ? "Edit income" : "Add income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(IncomeFields(name: name.trimmingCharacters(in: .whitespaces),
                                            cadence: monthly ? "Monthly" : "Avg / month",
                                            amount: amount, recurring: recurring))
                        dismiss()
                    }
                    .fontWeight(.bold).disabled(!canSave)
                }
            }
        }
    }
}
