import SwiftUI
import UIKit

// MARK: - Keyboard dismissal
//
// Numeric keyboards (.decimalPad / .numberPad) have no return key, so amount
// fields need an explicit way out. `amountKeyboardDismissal()` adds a "Done"
// bar above the keyboard and lets a scroll/drag dismiss it.

enum KeyboardDismiss {
    static func resign() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension View {
    func amountKeyboardDismissal() -> some View {
        self
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { KeyboardDismiss.resign() }
                        .fontWeight(.semibold)
                }
            }
    }
}

// MARK: - Card container

struct Card<Content: View>: View {
    var padding: CGFloat = Theme.Spacing.card
    var radius: CGFloat = Theme.Radius.card
    var background: Color = Theme.Palette.surface
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .appShadow(.card)
    }
}

// MARK: - Pill

struct Pill: View {
    let text: String
    var bg: Color = Theme.Palette.greenSoft
    var fg: Color = Theme.Palette.green
    var dot: Color? = nil
    var mono: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if let dot {
                Circle().fill(dot).frame(width: 6, height: 6)
            }
            Text(text)
                .font(mono ? .mono(11, .semibold) : .ui(12, .semibold))
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(bg)
        .clipShape(Capsule())
    }
}

// MARK: - Buttons

struct PrimaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.ui(16, .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Theme.Palette.green)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                .appShadow(.primaryButton)
        }
        .buttonStyle(.plain)
    }
}

struct SecondaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.ui(16, .bold))
                .foregroundStyle(Theme.Palette.green)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Theme.Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                        .stroke(Theme.Palette.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Circular back button (‹)

struct CircleBackButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Palette.ink)
                .frame(width: 34, height: 34)
                .background(Theme.Palette.surface)
                .clipShape(Circle())
                .appShadow(.card)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - App mark (three ascending bars in a rounded square)

struct AppMark: View {
    var size: CGFloat = 72
    var body: some View {
        let unit = size / 72
        RoundedRectangle(cornerRadius: 22 * unit, style: .continuous)
            .fill(Theme.Palette.green)
            .frame(width: size, height: size)
            .overlay(
                HStack(alignment: .bottom, spacing: 6 * unit) {
                    bar(h: 22 * unit, color: .white)
                    bar(h: 32 * unit, color: Theme.Palette.greenSoft)
                    bar(h: 42 * unit, color: Theme.Palette.greenAccent)
                }
            )
            .appShadow(.appMark)
    }

    private func bar(h: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(color)
            .frame(width: 10 * (size / 72), height: h)
    }
}

// MARK: - Progress / track bars

/// A rounded track with a colored fill (used for sliders, budget bars, etc.)
struct TrackBar: View {
    var fraction: Double            // 0...1 (caller caps if needed)
    var height: CGFloat = 6
    var fill: Color = Theme.Palette.green
    var track: Color = Theme.Palette.hairline

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(fill)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Dashed "add" tile

struct DashedAddTile: View {
    let title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.ui(14, .semibold))
                .foregroundStyle(Theme.Palette.inkSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .foregroundStyle(Theme.Palette.dashed)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Small color square (category marker)

struct ColorSquare: View {
    let hex: String
    var size: CGFloat = 9
    var corner: CGFloat = 3
    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(Color(hex: hex))
            .frame(width: size, height: size)
    }
}

// MARK: - Screen background

struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(Theme.Palette.page.ignoresSafeArea())
    }
}

extension View {
    func screenBackground() -> some View { modifier(ScreenBackground()) }
}

// MARK: - Size-class adaptive helpers (iPad support)

/// Hides the navigation bar only in compact width (iPhone). In regular width
/// (iPad split view) the bar stays so the sidebar toggle remains reachable.
private struct CompactHiddenNavBar: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(sizeClass == .compact ? .hidden : .automatic, for: .navigationBar)
    }
}

extension View {
    func navBarHiddenInCompact() -> some View { modifier(CompactHiddenNavBar()) }
}

/// Caps content to a readable width and centers it. On iPhone the cap exceeds
/// the screen so it has no effect; on iPad it keeps the detail pane from
/// stretching edge-to-edge.
private struct ReadableContent: ViewModifier {
    var maxWidth: CGFloat
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    func readableContent(_ maxWidth: CGFloat = 760) -> some View {
        modifier(ReadableContent(maxWidth: maxWidth))
    }
}
