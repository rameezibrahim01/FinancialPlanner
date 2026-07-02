import SwiftUI
import SwiftData

/// V2-1 · Recurring bills & subscriptions — define predictable spend once so it
/// drives the month's committed total, the Safe-to-spend math (V2-2) and the
/// Upcoming list. Annual/quarterly items are amortized into a monthly equivalent.
struct RecurringView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Recurring.order) private var items: [Recurring]
    @State private var showAdd = false
    @State private var editingItem: Recurring?

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
            RecurringEditorSheet(existing: nil) { fields in
                let order = (items.map(\.order).max() ?? -1) + 1
                context.insert(Recurring(name: fields.name, amount: fields.amount,
                                         categoryName: fields.category, colorHex: fields.color,
                                         tintHex: fields.tint, cadence: fields.cadence,
                                         dueDay: fields.dueDay, autoPost: fields.autoPost, order: order))
                try? context.save()
                // Post it immediately if it's already due this month — otherwise it
                // wouldn't appear until the next app launch.
                AutoPost.run(context)
            }
        }
        .sheet(item: $editingItem) { item in
            RecurringEditorSheet(existing: item, onSave: { fields in
                item.name = fields.name
                item.amount = fields.amount
                item.categoryName = fields.category
                item.colorHex = fields.color
                item.tintHex = fields.tint
                item.cadenceRaw = fields.cadence.rawValue
                item.dueDay = fields.dueDay
                item.autoPost = fields.autoPost
                try? context.save()
                AutoPost.run(context)
            }, onDelete: {
                context.delete(item)
                try? context.save()
            })
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
            Text("TAP TO EDIT").font(.mono(10, .medium)).kerning(0.4).foregroundStyle(Theme.Palette.faint)
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
                    Button {
                        editingItem = r
                    } label: {
                        RecurringRow(item: r)
                    }
                    .buttonStyle(.plain)
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
                .fill(Color(hex: item.colorHex).opacity(0.18))
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
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: "#cdd2cb"))
        }
        .padding(.vertical, 10).padding(.horizontal, 11)
        .contentShape(Rectangle())
    }
}

// MARK: - Add / edit recurring sheet

/// The values collected by the editor, handed back to the caller to insert or
/// apply to an existing item.
struct RecurringFields {
    var name: String
    var amount: Double
    var category: String
    var color: String
    var tint: String
    var cadence: RecurringCadence
    var dueDay: Int
    var autoPost: Bool
}

private struct RecurringEditorSheet: View {
    /// Existing item to edit, or nil to add a new one.
    let existing: Recurring?
    var onSave: (RecurringFields) -> Void
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    /// Same canonical category store the planning and expense screens use, so a
    /// bill can only be filed under a category that actually exists elsewhere.
    @Query(sort: \Category.order) private var categories: [Category]
    @State private var name: String
    @State private var amountText: String
    @State private var category: String
    @State private var cadence: RecurringCadence
    @State private var dueDay: Int
    @State private var autoPost: Bool

    init(existing: Recurring?,
         onSave: @escaping (RecurringFields) -> Void,
         onDelete: (() -> Void)? = nil) {
        self.existing = existing
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: existing?.name ?? "")
        _amountText = State(initialValue: existing.map { $0.amount > 0 ? String(Int($0.amount)) : "" } ?? "")
        _category = State(initialValue: existing?.categoryName ?? "")
        _cadence = State(initialValue: existing?.cadence ?? .monthly)
        _dueDay = State(initialValue: existing?.dueDay ?? 1)
        _autoPost = State(initialValue: existing?.autoPost ?? true)
    }

    private var amount: Double { Double(amountText.filter { $0.isNumber || $0 == "." }) ?? 0 }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0 && !category.isEmpty
    }
    private var isEditing: Bool { existing != nil }

    /// Keeps a valid category selected — the query is empty on the first render,
    /// and a new bill starts with none chosen.
    private func syncCategory() {
        if !categories.contains(where: { $0.name == category }) {
            category = categories.first?.name ?? ""
        }
    }

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
                        ForEach(categories) { Text($0.name).tag($0.name) }
                    }
                    Picker("Cadence", selection: $cadence) {
                        ForEach(RecurringCadence.allCases, id: \.self) {
                            Text($0.label.capitalized).tag($0)
                        }
                    }
                    Stepper("Due day: \(Recurring.ordinal(dueDay))", value: $dueDay, in: 1...28)
                    Toggle("Auto-post each month", isOn: $autoPost).tint(Theme.Palette.green)
                }
                if isEditing, let onDelete {
                    Section {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Text("Delete bill").frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(isEditing ? "Edit recurring" : "Add recurring")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: syncCategory)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        // Accent comes from the chosen category; the row tints it
                        // down for display, so color and tint carry the same hex.
                        let hex = categories.first { $0.name == category }?.colorHex
                            ?? existing?.colorHex ?? Theme.CategoryColor.other
                        onSave(RecurringFields(name: name.trimmingCharacters(in: .whitespaces),
                                               amount: amount, category: category, color: hex, tint: hex,
                                               cadence: cadence, dueDay: dueDay, autoPost: autoPost))
                        dismiss()
                    }
                    .fontWeight(.bold).disabled(!canSave)
                }
            }
        }
    }
}
