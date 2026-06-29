import SwiftUI

/// Decides between first-launch setup (Lane 1) and the main app. The flag is
/// persisted, so onboarding is shown only until the user finishes (or skips)
/// the income setup.
struct AppEntryView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            RootTabView()
        } else {
            OnboardingFlowView { hasCompletedOnboarding = true }
        }
    }
}
