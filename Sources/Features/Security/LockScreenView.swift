import SwiftUI
import LocalAuthentication

/// V2-5 · App lock — the one dark screen. Gates the app behind device
/// biometrics (Face ID / Touch ID) with the device passcode as fallback via
/// `LAContext`. Shown on launch and on return from background after the
/// configured timeout.
struct LockScreenView: View {
    var onUnlock: () -> Void
    @State private var failed = false

    var body: some View {
        ZStack {
            Color(hex: "#11271f").ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                AppMark(size: 72)
                Text("Planner is locked")
                    .font(.ui(22, .heavy)).kerning(-0.4)
                    .foregroundStyle(Color(hex: "#eef3ef"))
                    .padding(.top, 26)
                Text("Your finances stay private. Unlock with Face ID to continue.")
                    .font(.ui(14)).foregroundStyle(Color(hex: "#a7c6b5"))
                    .multilineTextAlignment(.center).lineSpacing(3)
                    .frame(maxWidth: 260)
                    .padding(.top, 8)

                Button(action: authenticate) {
                    Image(systemName: "faceid")
                        .font(.system(size: 40, weight: .regular))
                        .foregroundStyle(Color(hex: "#9bd2b8"))
                        .frame(width: 84, height: 84)
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color(hex: "#9bd2b8").opacity(0.5), lineWidth: 2))
                }
                .buttonStyle(.plain)
                .padding(.top, 40)

                Text(failed ? "Authentication failed — tap to retry" : "Tap to unlock with Face ID")
                    .font(.ui(14, .semibold))
                    .foregroundStyle(failed ? Theme.Palette.clay : Color(hex: "#9bd2b8"))
                    .padding(.top, 18)
                Spacer()
                Button(action: authenticate) {
                    Text("Use passcode instead")
                        .font(.ui(15, .semibold)).foregroundStyle(Color(hex: "#a7c6b5"))
                        .padding(14)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 34)
        }
        .onAppear(perform: authenticate)
    }

    private func authenticate() {
        let context = LAContext()
        context.localizedFallbackTitle = "Use passcode"
        var error: NSError?
        // .deviceOwnerAuthentication = biometrics with automatic device-passcode fallback.
        let policy: LAPolicy = .deviceOwnerAuthentication
        guard context.canEvaluatePolicy(policy, error: &error) else {
            // No biometrics/passcode available (e.g. a fresh simulator) — don't
            // lock the user out of their own offline data.
            onUnlock()
            return
        }
        context.evaluatePolicy(policy, localizedReason: "Unlock Planner to view your finances") { success, _ in
            DispatchQueue.main.async {
                if success { onUnlock() } else { failed = true }
            }
        }
    }
}
