import SwiftUI
import SwiftData

/// C3 · Add / edit transaction — enter or amend an income/expense. Segmented
/// Expense|Income control recolors the amount; category is single-select; the
/// custom numeric keypad edits the amount. Save persists the transaction; in
/// edit mode a Delete action removes it.
struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.order) private var categories: [Category]

    /// The transaction being edited, or nil to create a new one.
    let editing: Transaction?

    @State private var type: TxType = .expense
    @State private var amountString = "0"
    @State private var selectedCategory = ""
    @State private var note = ""
    @State private var caretOn = true
    @State private var showScanner = false
    @State private var scanning = false
    @FocusState private var noteFocused: Bool

    init(editing: Transaction? = nil) {
        self.editing = editing
        _type = State(initialValue: editing?.type ?? .expense)
        if let e = editing {
            _amountString = State(initialValue: e.amount == e.amount.rounded()
                                  ? String(Int(e.amount)) : String(e.amount))
        }
        _selectedCategory = State(initialValue: editing?.categoryName ?? "")
        _note = State(initialValue: editing?.note ?? "")
    }

    private var accent: Color { type == .income ? Theme.Palette.green : Theme.Palette.clay }
    private var amount: Double { Double(amountString) ?? 0 }
    /// The selected chip, falling back to the first available chip so a valid
    /// category is always chosen once chips exist (the categories query can be
    /// empty on the first render, which previously left Save disabled).
    private var effectiveCategory: String {
        if chips.contains(where: { $0.name == selectedCategory }) { return selectedCategory }
        return chips.first?.name ?? ""
    }
    private var canSave: Bool { amount > 0 && !effectiveCategory.isEmpty }

    /// Chips depend on the entry type: real categories for expenses, a small
    /// income set otherwise.
    private var chips: [(name: String, colorHex: String)] {
        var base: [(name: String, colorHex: String)]
        if type == .income {
            base = [("Salary", Theme.CategoryColor.housing),
                    ("Freelance", Theme.CategoryColor.groceries),
                    ("Other", Theme.CategoryColor.other)]
        } else {
            base = categories.map { ($0.name, $0.colorHex) }
        }
        // When editing, keep the transaction's own category available even if it
        // isn't one of the current chips (e.g. a since-deleted category).
        if let e = editing, e.type == type, !base.contains(where: { $0.name == e.categoryName }) {
            let hex = categories.first { $0.name == e.categoryName }?.colorHex ?? Theme.CategoryColor.other
            base.append((e.categoryName, hex))
        }
        return base
    }

    private let keys = ["1","2","3","4","5","6","7","8","9",".","0","⌫"]
    private let keyColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            navRow
            ScrollView {
                VStack(spacing: 20) {
                    segmented
                    scanButton
                    amountDisplay
                    chipGrid
                    detailRows
                    if editing != nil {
                        Button(role: .destructive, action: delete) {
                            Text("Delete transaction")
                                .font(.ui(15, .bold)).foregroundStyle(Theme.Palette.clay)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Theme.Palette.claySoft)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.side)
                .padding(.top, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            // The custom keypad drives the amount. Hide it while the Note field
            // is focused so it doesn't sit under the system keyboard — tapping
            // the amount (below) brings it back.
            if !noteFocused {
                keypad
            }
        }
        .animation(.easeInOut(duration: 0.2), value: noteFocused)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .background(Theme.Palette.page.ignoresSafeArea())
        .fullScreenCover(isPresented: $showScanner) {
            ReceiptCameraScanner { image in
                showScanner = false
                guard let image else { return }
                scanning = true
                Task {
                    let result = await ReceiptParser.scan(image)
                    await MainActor.run {
                        if let amt = result.amount { amountString = formatAmount(amt) }
                        if let m = result.merchant, note.isEmpty { note = m }
                        scanning = false
                    }
                }
            }
            .ignoresSafeArea()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { noteFocused = false }
            }
        }
        .onAppear(perform: syncSelection)
        .onChange(of: type) { _, _ in syncSelection() }
    }

    /// Keeps a valid category selected for the current type.
    private func syncSelection() {
        if !chips.contains(where: { $0.name == selectedCategory }) {
            selectedCategory = chips.first?.name ?? ""
        }
    }

    // MARK: Scan receipt

    private var scanButton: some View {
        Button { showScanner = true } label: {
            HStack(spacing: 8) {
                if scanning {
                    ProgressView().controlSize(.small).tint(Theme.Palette.green)
                } else {
                    Image(systemName: "doc.viewfinder").font(.system(size: 15, weight: .semibold))
                }
                Text(scanning ? "Reading receipt…" : "Scan a receipt").font(.ui(14, .semibold))
            }
            .foregroundStyle(Theme.Palette.green)
            .frame(maxWidth: .infinity).padding(.vertical, 11)
            .background(Theme.Palette.greenSoft2)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(scanning)
    }

    /// Formats a scanned amount for the keypad display (no trailing .00).
    private func formatAmount(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.2f", v)
    }

    // MARK: Nav row

    private var navRow: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .font(.ui(15)).foregroundStyle(Theme.Palette.muted)
            Spacer()
            Text(editing == nil ? "Add" : "Edit").font(.ui(17, .bold)).foregroundStyle(Theme.Palette.ink)
            Spacer()
            Button("Save", action: save)
                .font(.ui(15, .bold))
                .foregroundStyle(canSave ? Theme.Palette.green : Theme.Palette.faint)
                .disabled(!canSave)
        }
        .padding(.horizontal, Theme.Spacing.side)
        .padding(.vertical, 14)
    }

    // MARK: Segmented control

    private var segmented: some View {
        HStack(spacing: 4) {
            segment("Expense", .expense, Theme.Palette.clay)
            segment("Income", .income, Theme.Palette.green)
        }
        .padding(4)
        .background(Color(hex: "#e7e7e0"))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func segment(_ title: String, _ t: TxType, _ activeColor: Color) -> some View {
        let active = type == t
        return Button {
            type = t
        } label: {
            Text(title)
                .font(.ui(14, .semibold))
                .foregroundStyle(active ? activeColor : Theme.Palette.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(active ? Theme.Palette.surface : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .appShadow(active ? .card : Shadow(color: .clear, radius: 0, x: 0, y: 0))
        }
        .buttonStyle(.plain)
    }

    // MARK: Amount

    private var amountDisplay: some View {
        VStack(spacing: 8) {
            Text("AMOUNT")
                .font(.mono(11, .medium)).kerning(0.5)
                .foregroundStyle(Theme.Palette.muted)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("AED").font(.ui(20)).foregroundStyle(Theme.Palette.muted)
                Text(amountString).tabular()
                    .font(.ui(48, .heavy)).foregroundStyle(accent)
                Rectangle()
                    .fill(accent)
                    .frame(width: 2, height: 40)
                    .opacity(caretOn ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: caretOn)
                    .onAppear { caretOn = false }
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { noteFocused = false }   // tap the amount → back to the keypad
    }

    // MARK: Category chips

    private var chipGrid: some View {
        LazyVGrid(columns: keyColumns, spacing: 10) {
            ForEach(chips, id: \.name) { chip in
                let active = effectiveCategory == chip.name
                Button {
                    selectedCategory = chip.name
                } label: {
                    HStack(spacing: 8) {
                        ColorSquare(hex: chip.colorHex, size: 18, corner: 5)
                        Text(chip.name)
                            .font(.ui(11, .semibold))
                            .foregroundStyle(active ? Color(hex: chip.colorHex) : Theme.Palette.inkSecondary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(active ? Color(hex: chip.colorHex).opacity(0.12) : Theme.Palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                            .stroke(active ? Color(hex: chip.colorHex) : Theme.Palette.border,
                                    lineWidth: active ? 1.5 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Detail rows

    private var detailRows: some View {
        Card(padding: 4, radius: Theme.Radius.button) {
            VStack(spacing: 0) {
                HStack {
                    Text("Date").font(.ui(13)).foregroundStyle(Theme.Palette.muted)
                    Spacer()
                    Text(editing == nil ? "Today · \(dateLabel)" : dateLabel)
                        .font(.ui(13, .semibold)).foregroundStyle(Theme.Palette.ink)
                }
                .padding(12)
                Rectangle().fill(Theme.Palette.hairlineSoft).frame(height: 1)
                HStack {
                    Text("Note").font(.ui(13)).foregroundStyle(Theme.Palette.muted)
                    Spacer()
                    TextField("Add a note", text: $note)
                        .focused($noteFocused)
                        .submitLabel(.done)
                        .onSubmit { noteFocused = false }
                        .font(.ui(13, .semibold))
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Theme.Palette.ink)
                }
                .padding(12)
            }
        }
    }

    private var dateLabel: String {
        let f = DateFormatter()
        f.calendar = SampleData.cal()
        f.dateFormat = "MMM d"
        return f.string(from: editing?.date ?? Date())
    }

    // MARK: Keypad

    private var keypad: some View {
        LazyVGrid(columns: keyColumns, spacing: 10) {
            ForEach(keys, id: \.self) { key in
                Button {
                    tapKey(key)
                } label: {
                    Group {
                        if key == "⌫" {
                            Image(systemName: "delete.left").font(.system(size: 20, weight: .medium))
                        } else {
                            Text(key).font(.ui(23, .semibold))
                        }
                    }
                    .foregroundStyle(Theme.Palette.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Theme.Palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
                    .appShadow(.card)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.side)
        .padding(.top, 12)
        .padding(.bottom, Theme.Spacing.bottomSafe)
    }

    // MARK: Keypad input

    private func tapKey(_ key: String) {
        switch key {
        case "⌫":
            if amountString.count <= 1 { amountString = "0" }
            else { amountString.removeLast() }
            if amountString.isEmpty { amountString = "0" }
        case ".":
            if !amountString.contains(".") { amountString += "." }
        default:
            if amountString == "0" {
                amountString = key
            } else {
                if let dot = amountString.firstIndex(of: ".") {
                    let decimals = amountString.distance(from: amountString.index(after: dot),
                                                         to: amountString.endIndex)
                    if decimals >= 2 { return }
                }
                amountString += key
            }
        }
    }

    // MARK: Save

    private func save() {
        guard canSave else { return }
        let cleanNote = note.trimmingCharacters(in: .whitespaces)
        if let e = editing {
            // Amend in place — keeps the original date, autoPosted flag and
            // recurring link.
            e.typeRaw = type.rawValue
            e.amount = amount
            e.categoryName = effectiveCategory
            e.note = cleanNote
        } else {
            context.insert(Transaction(type: type, amount: amount, categoryName: effectiveCategory,
                                       date: Date(), note: cleanNote))
        }
        try? context.save()
        dismiss()
    }

    private func delete() {
        if let e = editing {
            context.delete(e)
            try? context.save()
        }
        dismiss()
    }
}
