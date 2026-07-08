import SwiftUI
import SwiftData

extension Notification.Name {
    /// Posted when a `planner://add` deep link (e.g. from the widget) opens the app.
    static let plannerLogExpense = Notification.Name("plannerLogExpense")
}

/// Decides between first-launch setup (Lane 1) and the main app, and gates the
/// whole thing behind the App Lock (V2-5) when enabled. Onboarding state and
/// lock preferences are persisted.
struct AppEntryView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("appLock") private var appLock = false
    @AppStorage("lockTimeout") private var lockTimeout = 0   // minutes; 0 = immediately

    @Environment(\.scenePhase) private var scenePhase
    @State private var isLocked = false
    @State private var backgroundedAt: Date?

    var body: some View {
        ZStack {
            if hasCompletedOnboarding {
                RootTabView()
            } else {
                OnboardingFlowView {
                    // "Continue to planning" should land on the Plan tab.
                    UserDefaults.standard.set("plan", forKey: "pendingTab")
                    hasCompletedOnboarding = true
                }
            }

            if appLock && isLocked {
                LockScreenView { isLocked = false }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLocked)
        .onOpenURL { url in
            // Widget "Log expense" tap → open the Add screen.
            if url.scheme == "planner" && url.host == "add" {
                NotificationCenter.default.post(name: .plannerLogExpense, object: nil)
            }
        }
        .onAppear {
            if appLock { isLocked = true }
            maybeAutoPost()
        }
        .onChange(of: hasCompletedOnboarding) { _, done in
            if done { maybeAutoPost() }   // salary/bills for the current month, right after setup
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                backgroundedAt = Date()
                if hasCompletedOnboarding { WidgetSnapshotWriter.update(context) }
            case .active:
                maybeAutoPost()   // catches a new day/month while backgrounded
                guard appLock, let since = backgroundedAt else { return }
                if Date().timeIntervalSince(since) >= TimeInterval(lockTimeout * 60) {
                    isLocked = true
                }
                backgroundedAt = nil
            default:
                break
            }
        }
    }

    private func maybeAutoPost() {
        guard hasCompletedOnboarding else { return }
        AutoPost.run(context)
        WidgetSnapshotWriter.update(context)
    }
}
