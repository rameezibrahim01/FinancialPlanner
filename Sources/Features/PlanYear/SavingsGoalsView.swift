import SwiftUI
import SwiftData

/// B4 · Savings goals — set/track goals and contribution pace.
struct SavingsGoalsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Goal.order) private var goals: [Goal]
    @State private var showGoalSheet = false
    @State private var goalToEdit: Goal?

    private var hero: Goal? { goals.first }
    private var others: [Goal] { Array(goals.dropFirst()) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                header
                if let hero {
                    Button { edit(hero) } label: { HeroGoalCard(goal: hero) }
                        .buttonStyle(.plain)
                }
                ForEach(others, id: \.persistentModelID) { goal in
                    Button { edit(goal) } label: { OtherGoalCard(goal: goal) }
                        .buttonStyle(.plain)
                }
                debtLink
                DashedAddTile(title: "+ New goal") { goalToEdit = nil; showGoalSheet = true }
            }
            .padding(.horizontal, Theme.Spacing.side)
            .padding(.bottom, Theme.Spacing.bottomSafe)
            .readableContent()
        }
        .screenBackground()
        .navigationTitle("Savings goals")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showGoalSheet) {
            GoalSheet(goal: goalToEdit) { name, target, saved, monthly, deadline in
                if let g = goalToEdit {
                    g.name = name; g.target = target; g.saved = saved
                    g.monthlyContribution = monthly; g.deadline = deadline
                } else {
                    let order = (goals.map(\.order).max() ?? -1) + 1
                    context.insert(Goal(name: name, target: target, saved: saved, deadline: deadline,
                                        monthlyContribution: monthly,
                                        colorHex: Theme.CategoryColor.transport, order: order))
                }
                try? context.save()
            }
        }
    }

    private func edit(_ goal: Goal) { goalToEdit = goal; showGoalSheet = true }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PLAN · 2026").font(.mono(11, .medium)).kerning(0.5)
                .foregroundStyle(Theme.Palette.muted)
            Text("Goals").font(.ui(26, .heavy)).kerning(-0.6).foregroundStyle(Theme.Palette.ink)
        }
        .padding(.horizontal, 4)
    }

    private var debtLink: some View {
        NavigationLink {
            DebtPayoffView()
        } label: {
            Card(padding: 16, radius: 16) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.Palette.claySoft).frame(width: 34, height: 34)
                        .overlay(Image(systemName: "creditcard")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.Palette.clay))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Debt payoff").font(.ui(14, .bold)).foregroundStyle(Theme.Palette.ink)
                        Text("Track balances & projected payoff")
                            .font(.ui(11)).foregroundStyle(Theme.Palette.faint)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "#cdd2cb"))
                }
            }
        }
        .buttonStyle(.plain)
    }

}

// MARK: - Add / edit goal sheet

private struct GoalSheet: View {
    var goal: Goal?
    /// (name, target, saved, monthlyContribution, deadline)
    var onSave: (String, Double, Double, Double, Date?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var targetText = ""
    @State private var savedText = ""
    @State private var monthlyText = ""
    @State private var hasDeadline = false
    @State private var deadline = Date()

    private var target: Double { Double(targetText) ?? 0 }
    private var saved: Double { Double(savedText) ?? 0 }
    private var monthly: Double { Double(monthlyText) ?? 0 }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && target > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    TextField("Name (e.g. New car)", text: $name)
                    amountRow("Target", $targetText)
                    amountRow("Saved so far", $savedText)
                }
                Section("Pace") {
                    amountRow("Contribution / month", $monthlyText)
                    Toggle("Has a deadline", isOn: $hasDeadline).tint(Theme.Palette.green)
                    if hasDeadline {
                        DatePicker("Reach by", selection: $deadline, displayedComponents: .date)
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(goal == nil ? "New goal" : "Edit goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(name.trimmingCharacters(in: .whitespaces), target, saved, monthly,
                               hasDeadline ? deadline : nil)
                        dismiss()
                    }
                    .fontWeight(.bold).disabled(!canSave)
                }
            }
            .onAppear {
                guard let g = goal else { return }
                name = g.name
                targetText = String(Int(g.target))
                savedText = String(Int(g.saved))
                monthlyText = String(Int(g.monthlyContribution))
                if let d = g.deadline { hasDeadline = true; deadline = d }
            }
        }
    }

    private func amountRow(_ label: String, _ text: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("AED").foregroundStyle(Theme.Palette.muted)
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
        }
    }
}

// MARK: - Pace calculation

enum GoalPace {
    /// Month name the goal is reached at the current monthly contribution.
    static func reachMonth(saved: Double, target: Double, monthly: Double, fromMonth: Int) -> String? {
        let remaining = target - saved
        guard remaining > 0 else { return "now" }
        guard monthly > 0 else { return nil }
        let need = Int((remaining / monthly).rounded(.up))
        let idx = fromMonth + need
        guard idx >= 1, idx <= 12 else { return idx > 12 ? "next year" : nil }
        return MonthPlan.shortNames[idx - 1].capitalized
    }
}

// MARK: - Hero goal card with progress ring

private struct HeroGoalCard: View {
    let goal: Goal

    private var reach: String? {
        GoalPace.reachMonth(saved: goal.saved, target: goal.target,
                            monthly: goal.monthlyContribution, fromMonth: 6)
    }
    private var deadlineText: String {
        guard let d = goal.deadline else { return "" }
        let f = DateFormatter(); f.dateFormat = "MMM yyyy"
        return " · by \(f.string(from: d))"
    }

    var body: some View {
        Card(padding: 22, radius: Theme.Radius.summary) {
            VStack(spacing: 14) {
                ProgressRing(fraction: goal.fill, percent: goal.percentFunded)
                    .frame(width: 140, height: 140)
                VStack(spacing: 4) {
                    Text(goal.name).font(.ui(18, .heavy)).foregroundStyle(Theme.Palette.ink)
                    Text("\(Money.aed(goal.saved)) of \(Money.plain(goal.target))\(deadlineText)")
                        .tabular()
                        .font(.ui(14)).foregroundStyle(Theme.Palette.inkSecondary)
                }
                if let reach {
                    Text("On track · \(Money.aed(goal.monthlyContribution))/mo reaches it by \(reach)")
                        .font(.ui(12, .semibold)).foregroundStyle(Theme.Palette.green)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Theme.Palette.greenSoft2)
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct ProgressRing: View {
    let fraction: Double
    let percent: Int

    var body: some View {
        ZStack {
            Circle().stroke(Color(hex: "#e7e7e0"), lineWidth: 16)
            Circle()
                .trim(from: 0, to: max(0, min(1, fraction)))
                .stroke(Theme.Palette.green, style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(percent)%").font(.ui(28, .heavy)).foregroundStyle(Theme.Palette.green)
                Text("funded").font(.ui(12)).foregroundStyle(Theme.Palette.muted)
            }
        }
    }
}

// MARK: - Other goal card

private struct OtherGoalCard: View {
    let goal: Goal

    var body: some View {
        Card(padding: 16, radius: 16) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(goal.name).font(.ui(14, .bold)).foregroundStyle(Theme.Palette.ink)
                    Spacer()
                    Text("\(Money.plain(goal.saved)) / \(Money.plain(goal.target))").tabular()
                        .font(.ui(13)).foregroundStyle(Theme.Palette.inkSecondary)
                }
                TrackBar(fraction: goal.fill, height: 7, fill: Color(hex: goal.colorHex))
                Text("\(goal.percentFunded)% funded")
                    .font(.ui(11)).foregroundStyle(Theme.Palette.muted)
            }
        }
    }
}
