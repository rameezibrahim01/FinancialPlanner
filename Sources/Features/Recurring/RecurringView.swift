import SwiftUI
import SwiftData

/// V2-1 · Recurring bills & subscriptions — define predictable spend once so it
/// drives the month's committed total, the Safe-to-spend math (V2-2) and the
/// Upcoming list. Annual/quarterly items are amortized into a monthly equivalent.
struct RecurringView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Recurring.order) private var items: [Recurring]
    @State private var showAdd = false

    private var monthlyTotal: Double { items.reduce(0) { $0 + $1.monthlyEquivalent } }
    private var annualCommitted: Double { monthlyTotal * 12 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                header
                summaryCard
                listHeader
                listCard
                DashedAddTile(title: "+ Add recurring bill") { showAdd = true }
            }
            .padding(.horizontal, Theme.Spacing.side)
            .padding(.bottom, Theme.Spacing.bottomSafe)
            .readableContent()
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAdd) {
            AddRecurringSheet { name, amount, cat, color, tint, cadence, dueDay, autoPost in
                let order = (items.map(\.order).max() ?? -1) + 1
                context.insert(Recurring(name: name, amount: amount, categoryName: cat,
                                         colorHex: color, tintHex: tint, cadence: cadence,
                                         dueDay: dueDay, autoPost: autoPost, order: order))
                try? context.save()
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("PLAN · AUTOMATED").font(.mono(11, .medium)).kerning(0.5)
                .foregroundStyle(Theme.Palette.muted)
            Text("Recurring").font(.ui(26, .heavy)).kerning(-0.6)
                .foregroundStyle(Theme.Palette.ink)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Summary card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top) {
                Text("Posts automatically every month")
                    .font(.ui(13)).foregroundStyle(Theme.Palette.greenOnDark)
                Spacer()
                Text("\(items.count) active")
                    .font(.ui(12, .bold)).foregroundStyle(Theme.Palette.greenDark)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Theme.Palette.greenAccent).clipShape(Capsule())
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("AED").font(.ui(15, .semibold)).foregroundStyle(Theme.Palette.greenOnDark)
                Text(Money.plain(monthlyTotal)).tabular()
                    .font(.ui(36, .heavy)).kerning(-1).foregroundStyle(.white)
                Text("/ month").font(.ui(14, .semibold)).foregroundStyle(Theme.Palette.greenOnDark)
            }
            Text("\(Money.aed(annualCommitted)) of your annual plan is already committed")
                .font(.ui(12)).foregroundStyle(Theme.Palette.greenOnDark2)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.green)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.summary, style: .continuous))
        .appShadow(.greenCard)
    }

    // MARK: List

    private var listHeader: some View {
        HStack {
            Text("Bills & subscriptions").font(.ui(15, .bold)).foregroundStyle(Theme.Palette.ink)
            Spacer()
            Text("DUE DATE").font(.mono(10, .medium)).kerning(0.4).foregroundStyle(Theme.Palette.faint)
        }
        .padding(.horizontal, 4)
    }

    private var listCard: some View {
        Card(padding: 4) {
            VStack(spacing: 0) {
                if items.isEmpty {
                    Text("No recurring bills yet.")
                        .font(.ui(13)).foregroundStyle(Theme.Palette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                }
                ForEach(Array(items.enumerated()), id: \.element.persistentModelID) { idx, r in
                    RecurringRow(item: r)
                    if idx < items.count - 1 {
                        Rectangle().fill(Theme.Palette.hairlineSoft).frame(height: 1)
                            .padding(.leading, 46)
                    }
                }
            }
        }
    }
}

// MARK: - Row

private struct RecurringRow: View {
    let item: Recurring

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: item.tintHex))
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).font(.ui(14, .semibold)).foregroundStyle(Theme.Palette.ink)
                Text("\(item.categoryName) · \(item.cadence.label)")
                    .font(.ui(11)).foregroundStyle(Theme.Palette.faint)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(Money.plain(item.amount)).tabular()
                    .font(.ui(14, .bold)).foregroundStyle(Theme.Palette.ink)
                Text(item.dueLabel).font(.ui(10, .semibold)).foregroundStyle(Theme.Palette.green)
            }
        }
        .padding(.vertical, 10).padding(.horizontal, 11)
    }
}

// MARK: - Add recurring sheet

private struct AddRecurringSheet: View {
    /// (name, amount, category, colorHex, tintHex, cadence, dueDay, autoPost)
    var onSave: (String, Double, String, String, String, RecurringCadence, Int, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amountText = ""
    @State private var category = "Housing"
    @State private var cadence: RecurringCadence = .monthly
    @State private var dueDay = 1
    @State private var autoPost = true

    // name, colorHex, tintHex
    private let categories: [(String, String, String)] = [
        ("Housing", Theme.CategoryColor.housing, "#dbeae1"),
        ("Groceries", Theme.CategoryColor.groceries, "#e6ead7"),
        ("Transport", Theme.CategoryColor.transport, "#dde6ea"),
        ("Utilities", Theme.CategoryColor.utilities, "#e1e6e2"),
        ("Health", Theme.CategoryColor.health, "#efe0e6"),
        ("Subscriptions", "#8b6b3f", "#ece1d2"),
        ("Other", Theme.CategoryColor.other, "#e6e6df"),
    ]

    private var amount: Double { Double(amountText) ?? 0 }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bill") {
                    TextField("Name (e.g. Netflix)", text: $name)
                    HStack {
                        Text("AED").foregroundStyle(Theme.Palette.muted)
                        TextField("0", text: $amountText).keyboardType(.decimalPad)
                    }
                }
                Section("Details") {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.0) { Text($0.0).tag($0.0) }
                    }
                    Picker("Cadence", selection: $cadence) {
                        ForEach(RecurringCadence.allCases, id: \.self) {
                            Text($0.label.capitalized).tag($0)
                        }
                    }
                    Stepper("Due day: \(Recurring.ordinal(dueDay))", value: $dueDay, in: 1...28)
                    Toggle("Auto-post each month", isOn: $autoPost).tint(Theme.Palette.green)
                }
            }
            .navigationTitle("Add recurring")
            .navigationBarTitleDisplayMode(.inline)
            .amountKeyboardDismissal()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let c = categories.first { $0.0 == category } ?? categories[0]
                        onSave(name.trimmingCharacters(in: .whitespaces), amount,
                               c.0, c.1, c.2, cadence, dueDay, autoPost)
                        dismiss()
                    }
                    .fontWeight(.bold).disabled(!canSave)
                }
            }
        }
    }
}
