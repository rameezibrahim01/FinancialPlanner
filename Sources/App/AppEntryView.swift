import SwiftUI
import SwiftData

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
    }
}
