import SwiftUI
import SwiftData

@main
struct FinancialPlannerApp: App {
    let container = AppModelContainer.shared

    init() {
        SampleData.seedIfNeeded(container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            AppEntryView()
                // The design is a fixed light palette (the one dark surface, the
                // lock screen, is hardcoded). Pin the app to light so system
                // controls don't flip in dark mode. Also set via Info.plist's
                // UIUserInterfaceStyle for UIKit-presented surfaces.
                .preferredColorScheme(.light)
        }
        .modelContainer(container)
    }
}
