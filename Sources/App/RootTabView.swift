import SwiftUI
import UIKit

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

// MARK: - iPhone shell (system tab bar + raised Add button)

private struct PhoneTabShell: View {
    @State private var tab: AppTab = .year
    @State private var showAdd = false

    /// Styles the system tab bar to match the design (page-colored background,
    /// hairline top border, green selected / faint unselected items).
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.Palette.page)
        appearance.shadowColor = UIColor(Theme.Palette.borderAlt)
        let faint = UIColor(Theme.Palette.faint)
        let green = UIColor(Theme.Palette.green)
        for layout in [appearance.stackedLayoutAppearance,
                       appearance.inlineLayoutAppearance,
                       appearance.compactInlineLayoutAppearance] {
            layout.normal.iconColor = faint
            layout.normal.titleTextAttributes = [.foregroundColor: faint]
            layout.selected.iconColor = green
            layout.selected.titleTextAttributes = [.foregroundColor: green]
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        GeometryReader { geo in
            TabView(selection: $tab) {
                NavigationStack { DashboardView() }
                    .tabItem { Label("Year", systemImage: "calendar") }
                    .tag(AppTab.year)
                NavigationStack { YearPlanView() }
                    .tabItem { Label("Plan", systemImage: "square.grid.2x2") }
                    .tag(AppTab.plan)
                NavigationStack { ChartsView() }
                    .tabItem { Label("Charts", systemImage: "chart.bar") }
                    .tag(AppTab.charts)
                NavigationStack { SettingsView() }
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(AppTab.settings)
            }
            .tint(Theme.Palette.green)
            // Raised center Add button, drawn on top of the tab bar (so the bar's
            // hairline never crosses it) and lifted to poke above the bar.
            .overlay(alignment: .bottom) {
                addButton
                    .padding(.bottom, geo.safeAreaInsets.bottom + 18)
            }
        }
        .sheet(isPresented: $showAdd) {
            AddTransactionView()
        }
    }

    private var addButton: some View {
        Button { showAdd = true } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(Theme.Palette.green)
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.Palette.page, lineWidth: 3))
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
