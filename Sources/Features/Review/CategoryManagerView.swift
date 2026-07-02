import SwiftUI
import SwiftData

/// Manage the canonical categories — add, rename, recolor, delete. This is the
/// single source of truth every other screen (planning, expense entry,
/// recurring, breakdowns) reads from, so edits here flow everywhere. Renames and
/// recolors cascade to existing budgets / transactions / bills so nothing is
/// orphaned.
struct CategoryManagerView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.order) private var categories: [Category]
    @State private var editing: Category?
    @State private var showAdd = false
    @State private var pendingDelete: Category?

    /// On-brand accent options offered in the editor.
    static let palette = ["#1f6f54", "#7a8b3f", "#8b6b3f", "#3f6f8b", "#bd5a3c",
                          "#6b7d6f", "#8b3f5a", "#5b5f8b", "#3f8b7d", "#d39a4a", "#8a928c"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                header
                Card(padding: 4, radius: Theme.Radius.card) {
                    VStack(spacing: 0) {
                        ForEach(Array(categories.enumerated()), id: \.element.persistentModelID) { idx, cat in
                            Button { editing = cat } label: { row(cat) }
                                .buttonStyle(.plain)
                            if idx < categories.count - 1 {
                                Rectangle().fill(Theme.Palette.hairlineSoft).frame(height: 1)
                                    .padding(.leading, 52)
                            }
                        }
                    }
                }
                DashedAddTile(title: "+ Add category") { showAdd = true }
                Text("These categories appear everywhere you plan or record spending. Renaming or recoloring one updates it across your budgets, transactions and bills.")
                    .font(.ui(12)).foregroundStyle(Theme.Palette.muted).padding(.horizontal, 4)
            }
            .padding(.horizontal, Theme.Spacing.side)
            .padding(.top, 8)
            .padding(.bottom, Theme.Spacing.bottomSafe)
            .readableContent()
        }
        .screenBackground()
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAdd) {
            CategoryEditorSheet(existing: nil, nameTaken: nameTaken) { name, hex in
                add(name: name, hex: hex)
            }
        }
        .sheet(item: $editing) { cat in
            CategoryEditorSheet(existing: cat, nameTaken: { nameTaken($0, excluding: cat) },
                                onSave: { name, hex in apply(cat, name: name, hex: hex) },
                                onDelete: { pendingDelete = cat })
        }
        .alert("Delete category?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } })) {
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) {
                if let c = pendingDelete { delete(c) }
                pendingDelete = nil
            }
        } message: {
            Text("Removes “\(pendingDelete?.name ?? "")” and its budget rows from every month. Past transactions keep their label.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SETTINGS · DATA").font(.mono(11, .medium)).kerning(0.5)
                .foregroundStyle(Theme.Palette.muted)
            Text("Categories").font(.ui(26, .heavy)).kerning(-0.6)
                .foregroundStyle(Theme.Palette.ink)
        }
        .padding(.horizontal, 4)
    }

    private func row(_ cat: Category) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(hex: cat.colorHex))
                .frame(width: 30, height: 30)
            Text(cat.name).font(.ui(15, .semibold)).foregroundStyle(Theme.Palette.ink)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: "#cdd2cb"))
        }
        .padding(.vertical, 11).padding(.horizontal, 10)
        .contentShape(Rectangle())
    }

    // MARK: Data

    /// True if `name` is already used by a category (optionally ignoring one, so
    /// an edit can keep its own name).
    private func nameTaken(_ name: String, excluding: Category? = nil) -> Bool {
        let key = name.trimmingCharacters(in: .whitespaces).lowercased()
        return categories.contains {
            $0.persistentModelID != excluding?.persistentModelID
                && $0.name.lowercased() == key
        }
    }

    private func add(name: String, hex: String) {
        let order = (categories.map(\.order).max() ?? -1) + 1
        context.insert(Category(name: name, colorHex: hex, order: order))
        try? context.save()
    }

    /// Applies a rename and/or recolor, cascading to everything that references
    /// the category by name.
    private func apply(_ cat: Category, name: String, hex: String) {
        let oldName = cat.name
        if name != oldName {
            for b in fetch(CategoryBudget.self) where b.categoryName == oldName { b.categoryName = name }
            for t in fetch(Transaction.self) where t.categoryName == oldName { t.categoryName = name }
            for r in fetch(Recurring.self) where r.categoryName == oldName { r.categoryName = name }
            cat.name = name
        }
        if hex != cat.colorHex {
            cat.colorHex = hex
            for b in fetch(CategoryBudget.self) where b.categoryName == name { b.colorHex = hex }
            for r in fetch(Recurring.self) where r.categoryName == name { r.colorHex = hex; r.tintHex = hex }
        }
        try? context.save()
    }

    /// Deletes the category and its budget rows across all months. Transactions
    /// keep their label as a historical record.
    private func delete(_ cat: Category) {
        let name = cat.name
        for b in fetch(CategoryBudget.self) where b.categoryName == name { context.delete(b) }
        context.delete(cat)
        try? context.save()
    }

    private func fetch<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }
}

// MARK: - Add / edit category sheet

private struct CategoryEditorSheet: View {
    let existing: Category?
    /// Returns true if a name collides with another category.
    var nameTaken: (String) -> Bool
    var onSave: (String, String) -> Void
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var hex: String

    init(existing: Category?,
         nameTaken: @escaping (String) -> Bool,
         onSave: @escaping (String, String) -> Void,
         onDelete: (() -> Void)? = nil) {
        self.existing = existing
        self.nameTaken = nameTaken
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: existing?.name ?? "")
        _hex = State(initialValue: existing?.colorHex ?? CategoryManagerView.palette[0])
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }
    private var isEditing: Bool { existing != nil }
    private var duplicate: Bool { !trimmed.isEmpty && nameTaken(trimmed) }
    private var canSave: Bool { !trimmed.isEmpty && !duplicate }

    private let swatchColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Travel", text: $name)
                    if duplicate {
                        Text("Another category already uses this name.")
                            .font(.ui(12)).foregroundStyle(Theme.Palette.clay)
                    }
                }
                Section("Color") {
                    LazyVGrid(columns: swatchColumns, spacing: 12) {
                        ForEach(CategoryManagerView.palette, id: \.self) { option in
                            Circle()
                                .fill(Color(hex: option))
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Circle().strokeBorder(Theme.Palette.ink,
                                                          lineWidth: hex == option ? 3 : 0)
                                )
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white)
                                        .opacity(hex == option ? 1 : 0)
                                )
                                .onTapGesture { hex = option }
                        }
                    }
                    .padding(.vertical, 4)
                }
                if isEditing, let onDelete {
                    Section {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Text("Delete category").frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit category" : "Add category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(trimmed, hex)
                        dismiss()
                    }
                    .fontWeight(.bold).disabled(!canSave)
                }
            }
        }
    }
}
