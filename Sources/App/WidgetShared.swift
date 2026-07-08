import Foundation

/// Shared between the app and the widget extension (compiled into both targets).
/// Only Foundation types here — no SwiftUI/SwiftData — so it stays safe in an
/// extension. The app writes a small snapshot to the App Group; the widget reads
/// it. No SwiftData is shared across processes.
enum PlannerWidgetShared {
    static let appGroup = "group.com.presight.financialplanner"
    static let snapshotKey = "widgetSnapshot"

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let d = defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        d.set(data, forKey: snapshotKey)
    }

    static func load() -> WidgetSnapshot? {
        guard let d = defaults, let data = d.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}

/// The glanceable numbers the widget shows. Mirrors the Today dashboard's
/// discretionary safe-to-spend model.
struct WidgetSnapshot: Codable {
    var safeToday: Double
    var spentToday: Double
    var discretionaryLeft: Double
    var daysRemaining: Int
    var monthName: String
    var isOver: Bool
    var overAmount: Double
    var hasBudget: Bool
    var updatedAt: Date

    /// A placeholder used before the app has written anything.
    static let empty = WidgetSnapshot(safeToday: 0, spentToday: 0, discretionaryLeft: 0,
                                      daysRemaining: 0, monthName: "", isOver: false,
                                      overAmount: 0, hasBudget: false, updatedAt: Date(timeIntervalSince1970: 0))
}
