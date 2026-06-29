import SwiftUI
import SwiftData

/// B4 · Savings goals — set/track goals and contribution pace.
struct SavingsGoalsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Goal.order) private var goals: [Goal]

    private var hero: Goal? { goals.first }
    private var others: [Goal] { Array(goals.dropFirst()) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                header
                if let hero { HeroGoalCard(goal: hero) }
                ForEach(others, id: \.persistentModelID) { OtherGoalCard(goal: $0) }
                DashedAddTile(title: "+ New goal", action: addGoal)
            }
            .padding(.horizontal, Theme.Spacing.side)
            .padding(.bottom, Theme.Spacing.bottomSafe)
        }
        .screenBackground()
        .navigationTitle("Savings goals")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PLAN · 2026").font(.mono(11, .medium)).kerning(0.5)
                .foregroundStyle(Theme.Palette.muted)
            Text("Goals").font(.ui(26, .heavy)).kerning(-0.6).foregroundStyle(Theme.Palette.ink)
        }
        .padding(.horizontal, 4)
    }

    private func addGoal() {
        let order = (goals.map(\.order).max() ?? -1) + 1
        context.insert(Goal(name: "New goal", target: 10000, saved: 0, deadline: nil,
                            monthlyContribution: 1000, colorHex: Theme.CategoryColor.transport, order: order))
        try? context.save()
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
