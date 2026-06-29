import SwiftUI

/// Wraps the first-launch setup flow (A1 → A2) in its own navigation stack.
/// Calls `onFinish` once the user finishes setup (or skips via "I already have
/// a backup").
struct OnboardingFlowView: View {
    var onFinish: () -> Void

    var body: some View {
        NavigationStack {
            WelcomeView(onFinish: onFinish)
        }
        .tint(Theme.Palette.green)
    }
}

/// A1 · Welcome — first launch; introduce the app and start setup.
struct WelcomeView: View {
    var onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            hero
            Spacer()
            cta
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity)
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 18) {
            AppMark(size: 72)
            VStack(spacing: 12) {
                Text("Plan your whole year. Offline.")
                    .font(.ui(30, .heavy)).kerning(-0.8)
                    .foregroundStyle(Theme.Palette.ink)
                    .lineSpacing(2)
                    .multilineTextAlignment(.center)
                Text("Budget every month, track income & expenses, and hit your savings goals — all stored on your device.")
                    .font(.ui(15)).foregroundStyle(Theme.Palette.inkSecondary)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            offlineBadge
        }
    }

    private var offlineBadge: some View {
        HStack(spacing: 6) {
            Circle().fill(Theme.Palette.green).frame(width: 6, height: 6)
            Text("WORKS 100% OFFLINE · NO ACCOUNT")
                .font(.mono(11, .medium)).kerning(0.4)
        }
        .foregroundStyle(Theme.Palette.green)
        .padding(.top, 4)
    }

    // MARK: CTA group

    private var cta: some View {
        VStack(spacing: 14) {
            NavigationLink {
                IncomeSetupView(onFinish: onFinish)
            } label: {
                Text("Get started")
                    .font(.ui(16, .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(16)
                    .background(Theme.Palette.green)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                    .appShadow(.primaryButton)
            }
            Button(action: onFinish) {
                Text("I already have a backup")
                    .font(.ui(15, .semibold)).foregroundStyle(Theme.Palette.inkSecondary)
            }
            .buttonStyle(.plain)
        }
    }
}
