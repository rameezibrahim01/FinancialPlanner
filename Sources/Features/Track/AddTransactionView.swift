import SwiftUI
import SwiftData

/// C3 · Add transaction — enter a new income/expense. Segmented Expense|Income
/// control recolors the amount; category is single-select; the custom numeric
/// keypad edits the amount. Save persists a Transaction and dismisses.
struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.order) private var categories: [Category]

    @State private var type: TxType = .expense
    @State private var amountString = "0"
    @State private var selectedCategory = ""
    @State private var note = ""
    @State private var caretOn = true
    @FocusState private var noteFocused: Bool

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
        if type == .income {
            return [("Salary", Theme.CategoryColor.housing),
                    ("Freelance", Theme.CategoryColor.groceries),
                    ("Other", Theme.CategoryColor.other)]
        }
        return categories.map { ($0.name, $0.colorHex) }
    }

    private let keys = ["1","2","3","4","5","6","7","8","9",".","0","⌫"]
    private let keyColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            navRow
            ScrollView {
                VStack(spacing: 20) {
                    segmented
                    amountDisplay
                    chipGrid
                    detailRows
                }
                .padding(.horizontal, Theme.Spacing.side)
                .padding(.top, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            keypad
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .background(Theme.Palette.page.ignoresSafeArea())
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

    // MARK: Nav row

    private var navRow: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .font(.ui(15)).foregroundStyle(Theme.Palette.muted)
            Spacer()
            Text("Add").font(.ui(17, .bold)).foregroundStyle(Theme.Palette.ink)
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
                    Text("Today · \(todayLabel)").font(.ui(13, .semibold)).foregroundStyle(Theme.Palette.ink)
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

    private var todayLabel: String {
        let f = DateFormatter()
        f.calendar = SampleData.cal()
        f.dateFormat = "MMM d"
        return f.string(from: Date())
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
        let txn = Transaction(type: type, amount: amount, categoryName: effectiveCategory,
                              date: Date(), note: note.trimmingCharacters(in: .whitespaces))
        context.insert(txn)
        try? context.save()
        dismiss()
    }
}
