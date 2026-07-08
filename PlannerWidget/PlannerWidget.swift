import WidgetKit
import SwiftUI

// MARK: - Colors (self-contained; the widget target can't see the app's Theme)

private extension Color {
    init(hexString: String) {
        let s = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        self.init(.sRGB,
                  red: Double((rgb >> 16) & 0xff) / 255,
                  green: Double((rgb >> 8) & 0xff) / 255,
                  blue: Double(rgb & 0xff) / 255,
                  opacity: 1)
    }
    static let plGreen = Color(hexString: "#1f6f54")
    static let plClay = Color(hexString: "#bd5a3c")
    static let plInk = Color(hexString: "#15201a")
    static let plMuted = Color(hexString: "#8a928c")
    static let plSoft = Color(hexString: "#eaf2ed")
}

private func money(_ v: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 0
    f.groupingSeparator = ","
    return f.string(from: NSNumber(value: v)) ?? "0"
}

// MARK: - Timeline

struct SafeToSpendEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SafeToSpendProvider: TimelineProvider {
    func placeholder(in context: Context) -> SafeToSpendEntry {
        SafeToSpendEntry(date: Date(), snapshot: .sample)
    }
    func getSnapshot(in context: Context, completion: @escaping (SafeToSpendEntry) -> Void) {
        completion(SafeToSpendEntry(date: Date(), snapshot: PlannerWidgetShared.load() ?? .sample))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SafeToSpendEntry>) -> Void) {
        let snapshot = PlannerWidgetShared.load() ?? .empty
        let entry = SafeToSpendEntry(date: Date(), snapshot: snapshot)
        // Refresh just after midnight so "days remaining" ticks over; the app also
        // reloads the timeline whenever the data changes.
        let next = Calendar.current.nextDate(after: Date(),
                                             matching: DateComponents(hour: 0, minute: 1),
                                             matchingPolicy: .nextTime) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

private extension WidgetSnapshot {
    static let sample = WidgetSnapshot(safeToday: 185, spentToday: 40, discretionaryLeft: 2450,
                                       daysRemaining: 12, monthName: "July", isOver: false,
                                       overAmount: 0, hasBudget: true, updatedAt: Date())
}

// MARK: - Views

struct SafeToSpendWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SafeToSpendEntry
    private var s: WidgetSnapshot { entry.snapshot }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline: inlineView
            case .accessoryRectangular: rectangularView
            case .systemMedium: mediumView
            default: smallView
            }
        }
        .widgetURL(URL(string: "planner://add"))
    }

    // Home-screen small
    private var smallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(s.isOver ? "OVER BUDGET" : "SAFE TODAY")
                .font(.system(size: 10, weight: .semibold)).kerning(0.5)
                .foregroundStyle(Color.plMuted)
            if !s.hasBudget {
                Text("Set a budget")
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(Color.plInk)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("AED").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.plMuted)
                    Text(money(s.isOver ? s.overAmount : s.safeToday))
                        .font(.system(size: 30, weight: .heavy)).minimumScaleFactor(0.6).lineLimit(1)
                        .foregroundStyle(s.isOver ? Color.plClay : Color.plGreen)
                }
                Spacer(minLength: 0)
                Text(s.hasBudget
                     ? "\(money(s.discretionaryLeft)) left · \(s.daysRemaining)d"
                     : " ")
                    .font(.system(size: 11)).foregroundStyle(Color.plMuted).lineLimit(1)
            }
            Spacer(minLength: 0)
            Label("Log expense", systemImage: "plus.circle.fill")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.plGreen)
                .labelStyle(.titleAndIcon)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(Color.plSoft, for: .widget)
    }

    // Home-screen medium
    private var mediumView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(s.monthName.uppercased())
                    .font(.system(size: 10, weight: .semibold)).kerning(0.5).foregroundStyle(Color.plMuted)
                Text(s.isOver ? "Over budget" : "Safe to spend today")
                    .font(.system(size: 12)).foregroundStyle(Color.plMuted)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("AED").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.plMuted)
                    Text(money(s.isOver ? s.overAmount : s.safeToday))
                        .font(.system(size: 34, weight: .heavy)).minimumScaleFactor(0.6).lineLimit(1)
                        .foregroundStyle(s.isOver ? Color.plClay : Color.plGreen)
                }
                Spacer(minLength: 0)
                Text(s.hasBudget
                     ? "Spent today \(money(s.spentToday)) · \(money(s.discretionaryLeft)) left · \(s.daysRemaining) days"
                     : "Set a budget to see your daily number")
                    .font(.system(size: 11)).foregroundStyle(Color.plMuted).lineLimit(2)
            }
            Spacer(minLength: 0)
            VStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 30, weight: .semibold)).foregroundStyle(Color.plGreen)
                Text("Log").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.plGreen)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(Color.plSoft, for: .widget)
    }

    // Lock-screen rectangular
    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(s.isOver ? "Over budget" : "Safe today")
                .font(.system(size: 12, weight: .semibold))
            Text(s.hasBudget ? "AED \(money(s.isOver ? s.overAmount : s.safeToday))" : "Set a budget")
                .font(.system(size: 20, weight: .heavy))
            if s.hasBudget {
                Text("\(money(s.discretionaryLeft)) left · \(s.daysRemaining)d")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    // Lock-screen inline
    private var inlineView: some View {
        Text(s.hasBudget ? "Safe today: AED \(money(s.isOver ? s.overAmount : s.safeToday))"
                         : "Planner: set a budget")
    }
}

// MARK: - Widget

struct SafeToSpendWidget: Widget {
    let kind = "SafeToSpendWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SafeToSpendProvider()) { entry in
            SafeToSpendWidgetView(entry: entry)
        }
        .configurationDisplayName("Safe to Spend")
        .description("Today's safe-to-spend, with a tap to log an expense.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct PlannerWidgetBundle: WidgetBundle {
    var body: some Widget {
        SafeToSpendWidget()
    }
}
