import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

/// V2-4 · Backup, restore & export — first-class control over on-device data:
/// CSV / PDF / `.planner` exports, a backup-now action, and restore-from-file.
/// Everything stays local; sharing uses the system share sheet.
struct BackupView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MonthPlan.month) private var plans: [MonthPlan]
    @Query private var txns: [Transaction]
    @Query(sort: \Goal.order) private var goals: [Goal]
    @Query(sort: \Recurring.order) private var recurring: [Recurring]
    @Query(sort: \Debt.order) private var debts: [Debt]

    @AppStorage("autoBackup") private var autoBackup = true
    @AppStorage("lastBackupAt") private var lastBackupAt: Double = 0
    @AppStorage("startingSavings") private var startingSavings = 0.0

    @State private var shareItem: ShareItem?
    @State private var showImporter = false
    @State private var pendingRestoreURL: URL?
    @State private var showRestoreConfirm = false
    @State private var errorMessage: String?

    private let year = SampleData.year

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                statusCard
                section("EXPORT") {
                    row("Export transactions (CSV)", "All \(year) income & expenses",
                        tint: "#e6ead7", icon: "tablecells", action: exportCSV)
                    divider
                    row("Year report (PDF)", "Summary, charts & categories",
                        tint: "#dde6ea", icon: "doc.richtext", action: exportPDF)
                    divider
                    row("Share backup file", "Full data · .planner",
                        tint: "#dbeae1", icon: "square.and.arrow.up", action: shareBackup)
                }
                section("BACKUP") {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Auto-backup").font(.ui(14, .semibold)).foregroundStyle(Theme.Palette.ink)
                            Text("Daily · to Files / iCloud Drive")
                                .font(.ui(11)).foregroundStyle(Theme.Palette.faint)
                        }
                        Spacer()
                        Toggle("", isOn: $autoBackup).labelsHidden().tint(Theme.Palette.green)
                    }
                    .padding(.vertical, 12).padding(.horizontal, 14)
                    divider
                    row("Create backup now", nil, tint: "#eef6f1", icon: "externaldrive.badge.plus",
                        action: createBackupNow)
                    divider
                    row("Restore from file", nil, tint: "#dbeae1", icon: "arrow.uturn.backward",
                        tinted: true) { showImporter = true }
                }
                footer
            }
            .padding(.horizontal, Theme.Spacing.side)
            .padding(.top, 8)
            .padding(.bottom, Theme.Spacing.bottomSafe)
            .readableContent()
        }
        .screenBackground()
        .navigationTitle("Backup & data")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareItem) { ShareSheet(url: $0.url) }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .data]) { result in
            if case .success(let url) = result { pendingRestoreURL = url; showRestoreConfirm = true }
        }
        .alert("Replace all data?", isPresented: $showRestoreConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Replace", role: .destructive) { performRestore() }
        } message: {
            Text("Restoring overwrites your current plans, transactions, goals, debts and recurring bills.")
        }
        .alert("Couldn't complete", isPresented: Binding(get: { errorMessage != nil },
                                                          set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    // MARK: Status

    private var statusCard: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Theme.Palette.green)
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 18, weight: .semibold)).foregroundStyle(.white))
                .appShadow(.greenCard)
            VStack(alignment: .leading, spacing: 2) {
                Text(lastBackupAt == 0 ? "Not backed up yet" : "Backed up")
                    .font(.ui(15, .bold)).foregroundStyle(Theme.Palette.ink)
                Text(statusSubtext).font(.ui(12)).foregroundStyle(Theme.Palette.inkSecondary)
            }
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.greenSoft2)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Color(hex: "#cfe0d6"), lineWidth: 1))
    }

    private var statusSubtext: String {
        guard lastBackupAt > 0 else { return "Stored on this device" }
        let f = DateFormatter(); f.calendar = SampleData.cal(); f.dateFormat = "HH:mm"
        return "\(f.string(from: Date(timeIntervalSince1970: lastBackupAt))) · stored on this device"
    }

    // MARK: Section + row builders

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.ui(13, .bold)).kerning(0.3).foregroundStyle(Theme.Palette.muted)
                .padding(.horizontal, 4)
            Card(padding: 0) { VStack(spacing: 0) { content() } }
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.Palette.hairlineSoft).frame(height: 1).padding(.leading, 58)
    }

    private func row(_ name: String, _ sub: String?, tint: String, icon: String,
                     tinted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(hex: tint)).frame(width: 30, height: 30)
                    .overlay(Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Palette.green))
                VStack(alignment: .leading, spacing: 1) {
                    Text(name).font(.ui(14, .semibold))
                        .foregroundStyle(tinted ? Theme.Palette.green : Theme.Palette.ink)
                    if let sub {
                        Text(sub).font(.ui(11)).foregroundStyle(Theme.Palette.faint)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "#cdd2cb"))
            }
            .padding(.vertical, 12).padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack(spacing: 7) {
            Circle().fill(Theme.Palette.green).frame(width: 6, height: 6)
            Text("ALL DATA STAYS ON YOUR DEVICE")
                .font(.mono(11, .medium)).kerning(0.4).foregroundStyle(Theme.Palette.green)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    // MARK: Actions

    private func exportCSV() {
        do { shareItem = ShareItem(url: try Backup.writeCSV(txns: txns)) }
        catch { errorMessage = error.localizedDescription }
    }
    private func exportPDF() {
        do { shareItem = ShareItem(url: try Backup.writePDF(plans: plans, txns: txns, year: year)) }
        catch { errorMessage = error.localizedDescription }
    }
    private func shareBackup() {
        do {
            let url = try Backup.writePlanner(plans: plans, txns: txns, goals: goals,
                                              recurring: recurring, debts: debts,
                                              startingSavings: startingSavings, year: year)
            shareItem = ShareItem(url: url)
        } catch { errorMessage = error.localizedDescription }
    }
    private func createBackupNow() {
        do {
            let url = try Backup.writePlanner(plans: plans, txns: txns, goals: goals,
                                              recurring: recurring, debts: debts,
                                              startingSavings: startingSavings, year: year)
            lastBackupAt = Date().timeIntervalSince1970
            shareItem = ShareItem(url: url)
        } catch { errorMessage = error.localizedDescription }
    }
    private func performRestore() {
        guard let url = pendingRestoreURL else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            try Backup.restore(from: data, into: context)
        } catch {
            errorMessage = "That file couldn't be restored. Make sure it's a valid .planner backup."
        }
    }
}

// MARK: - Share sheet

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
