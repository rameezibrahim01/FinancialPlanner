import SwiftUI

/// The app sections. On iPhone these are the bottom-tab-bar items; on iPad they
/// are the sidebar entries. The center "Add" is an action, not a section.
enum AppTab: CaseIterable {
    case year, plan, charts, settings

    var title: String {
        switch self {
        case .year: return "Year at a glance"
        case .plan: return "Plan the year"
        case .charts: return "Charts & trends"
        case .settings: return "Year in review"
        }
    }
    var shortTitle: String {
        switch self {
        case .year: return "Year"
        case .plan: return "Plan"
        case .charts: return "Charts"
        case .settings: return "Settings"
        }
    }
    var icon: String {
        switch self {
        case .year: return "calendar"
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

// MARK: - iPhone shell (custom bottom tab bar)

private struct PhoneTabShell: View {
    @State private var tab: AppTab = .year
    @State private var showAdd = false

    var body: some View {
        Group {
            switch tab {
            case .year:     NavigationStack { DashboardView() }
            case .plan:     NavigationStack { YearPlanView() }
            case .charts:   NavigationStack { ChartsView() }
            case .settings: NavigationStack { SettingsView() }
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

// MARK: - Custom bottom tab bar (iPhone)

private struct AppTabBar: View {
    @Binding var selected: AppTab
    var onAdd: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            item(.year)
            item(.plan)
            addButton
            item(.charts)
            item(.settings)
        }
        .padding(.top, 10)
        .padding(.bottom, Theme.Spacing.bottomSafe)
        .padding(.horizontal, 6)
        .background(Theme.Palette.page.opacity(0.92))
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.Palette.borderAlt).frame(height: 1)
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
