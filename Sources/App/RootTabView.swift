import SwiftUI

/// The tracking/review tabs from the handoff bottom bar. The center "Add" is a
/// raised button that presents the Add-transaction sheet rather than a tab.
enum AppTab: CaseIterable {
    case year, plan, charts, settings
}

/// App shell: a custom bottom tab bar (Year / Plan / + / Charts / Settings) with
/// the raised center Add button, matching the handoff's C1 chrome.
struct RootTabView: View {
    @State private var tab: AppTab = .year
    @State private var showAdd = false

    var body: some View {
        Group {
            switch tab {
            case .year:     NavigationStack { DashboardView() }
            case .plan:     NavigationStack { YearPlanView() }
            case .charts:   NavigationStack { ComingSoonView(title: "Charts & trends", systemImage: "chart.bar") }
            case .settings: NavigationStack { ComingSoonView(title: "Year in review", systemImage: "gearshape") }
            }
        }
        .tint(Theme.Palette.green)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AppTabBar(selected: $tab) { showAdd = true }
        }
        .sheet(isPresented: $showAdd) {
            AddTransactionView()
        }
    }
}

// MARK: - Custom tab bar

private struct AppTabBar: View {
    @Binding var selected: AppTab
    var onAdd: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            item(.year, "calendar", "Year")
            item(.plan, "square.grid.2x2", "Plan")
            addButton
            item(.charts, "chart.bar", "Charts")
            item(.settings, "gearshape", "Settings")
        }
        .padding(.top, 10)
        .padding(.bottom, Theme.Spacing.bottomSafe)
        .padding(.horizontal, 6)
        .background(Theme.Palette.page.opacity(0.92))
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.Palette.borderAlt).frame(height: 1)
        }
    }

    private func item(_ t: AppTab, _ icon: String, _ label: String) -> some View {
        let active = selected == t
        return Button {
            selected = t
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: active ? .semibold : .regular))
                Text(label)
                    .font(.ui(11, active ? .bold : .regular))
            }
            .foregroundStyle(active ? Theme.Palette.green : Theme.Palette.faint)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Theme.Palette.green)
                .clipShape(Circle())
                .appShadow(.tabButton)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .offset(y: -22)
    }
}

// MARK: - Placeholder for not-yet-built lanes (Charts / Settings)

struct ComingSoonView: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Theme.Palette.faint)
            Text(title)
                .font(.ui(20, .heavy)).foregroundStyle(Theme.Palette.ink)
            Text("Coming soon")
                .font(.mono(11, .medium)).kerning(0.5)
                .foregroundStyle(Theme.Palette.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
    }
}
