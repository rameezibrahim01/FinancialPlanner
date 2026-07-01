import SwiftUI

/// The app sections. On iPhone these are the bottom-tab-bar items; on iPad they
/// are the sidebar entries. The center "Add" is an action, not a section.
enum AppTab: CaseIterable {
    case year, plan, charts, settings

    var title: String {
        switch self {
        case .year: return "Home"
        case .plan: return "Plan the year"
        case .charts: return "Charts & trends"
        case .settings: return "Year in review"
        }
    }
    var shortTitle: String {
        switch self {
        case .year: return "Home"
        case .plan: return "Plan"
        case .charts: return "Charts"
        case .settings: return "Settings"
        }
    }
    var icon: String {
        switch self {
        case .year: return "house"
        case .plan: return "square.grid.2x2"
        case .charts: return "chart.bar"
        case .settings: return "gearshape"
        }
    }
}

/// App shell. Adapts to the horizontal size class: a custom bottom tab bar in
/// compact width (iPhone), and a `NavigationSplitView` sidebar in regular width
/// (iPad), reusing the same section views in both.
struct RootTabView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .regular {
            SidebarShell()
        } else {
            PhoneTabShell()
        }
    }
}

// MARK: - Section content (shared by both shells)

@ViewBuilder
func sectionView(for tab: AppTab) -> some View {
    switch tab {
    case .year:     DashboardView()
    case .plan:     YearPlanView()
    case .charts:   ChartsView()
    case .settings: SettingsView()
    }
}

/// One-shot tab routing — e.g. onboarding's "Continue to planning" sets this so
/// the app opens on the Plan tab once. Returns nil on normal launches.
func consumePendingTab() -> AppTab? {
    guard let raw = UserDefaults.standard.string(forKey: "pendingTab") else { return nil }
    UserDefaults.standard.removeObject(forKey: "pendingTab")
    switch raw {
    case "plan": return .plan
    case "charts": return .charts
    case "settings": return .settings
    default: return .year
    }
}

// MARK: - iPhone shell (custom bottom tab bar)

private struct PhoneTabShell: View {
    @State private var tab: AppTab = .year
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            // The bar is applied INSIDE the NavigationStack, on the root screen,
            // so it reliably reserves scroll inset. Pushed detail screens cover
            // it and use their own back button (matching the design).
            currentScreen
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    CustomTabBar(selected: $tab) { showAdd = true }
                }
        }
        .tint(Theme.Palette.green)
        .sheet(isPresented: $showAdd) {
            AddTransactionView()
        }
        .onAppear { if let t = consumePendingTab() { tab = t } }
    }

    @ViewBuilder private var currentScreen: some View {
        switch tab {
        case .year:     DashboardView()
        case .plan:     YearPlanView()
        case .charts:   ChartsView()
        case .settings: SettingsView()
        }
    }
}

// MARK: - Custom bottom tab bar with integrated raised Add button

private struct CustomTabBar: View {
    @Binding var selected: AppTab
    var onAdd: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            item(.year)
            item(.plan)
            Spacer().frame(width: 72)   // center slot for the raised +
            item(.charts)
            item(.settings)
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        // Page-colored bar that extends under the home indicator.
        .background(Theme.Palette.page.ignoresSafeArea(edges: .bottom))
        // Hairline first…
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.Palette.borderAlt).frame(height: 1)
        }
        // …then the raised + ON TOP of it, so the line never crosses the button.
        .overlay(alignment: .top) {
            addButton.offset(y: -22)
        }
    }

    private func item(_ t: AppTab) -> some View {
        let active = selected == t
        return Button {
            selected = t
        } label: {
            VStack(spacing: 4) {
                Image(systemName: t.icon)
                    .font(.system(size: 18, weight: active ? .semibold : .regular))
                Text(t.shortTitle)
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
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(Theme.Palette.green)
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.Palette.page, lineWidth: 4))
                .appShadow(.tabButton)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - iPad shell (sidebar split view)

private struct SidebarShell: View {
    @State private var selection: AppTab? = .year
    @State private var showAdd = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    ForEach(AppTab.allCases, id: \.self) { tab in
                        Label(tab.title, systemImage: tab.icon).tag(tab)
                    }
                } header: {
                    brand
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Planner")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button { showAdd = true } label: {
                    Label("New transaction", systemImage: "plus.circle.fill")
                        .font(.ui(15, .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(14)
                        .background(Theme.Palette.green)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                        .appShadow(.primaryButton)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        } detail: {
            NavigationStack {
                sectionView(for: selection ?? .year)
            }
        }
        .tint(Theme.Palette.green)
        .sheet(isPresented: $showAdd) {
            AddTransactionView()
        }
        .onAppear { if let t = consumePendingTab() { selection = t } }
    }

    private var brand: some View {
        HStack(spacing: 10) {
            AppMark(size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text("Planner").font(.ui(16, .heavy)).foregroundStyle(Theme.Palette.ink)
                Text("2026 · AED").font(.mono(10, .medium)).kerning(0.4)
                    .foregroundStyle(Theme.Palette.muted)
            }
        }
        .textCase(nil)
        .padding(.vertical, 10)
    }
}
