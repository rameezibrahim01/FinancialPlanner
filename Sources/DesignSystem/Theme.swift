import SwiftUI

// MARK: - Color hex support

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r, g, b, a: Double
        switch s.count {
        case 8: // RRGGBBAA
            r = Double((rgb >> 24) & 0xff) / 255
            g = Double((rgb >> 16) & 0xff) / 255
            b = Double((rgb >> 8) & 0xff) / 255
            a = Double(rgb & 0xff) / 255
        default: // RRGGBB
            r = Double((rgb >> 16) & 0xff) / 255
            g = Double((rgb >> 8) & 0xff) / 255
            b = Double(rgb & 0xff) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Design tokens (authoritative — from the handoff token table)

enum Theme {
    enum Palette {
        static let page = Color(hex: "#f1f1ec")
        static let surface = Color(hex: "#ffffff")
        static let ink = Color(hex: "#15201a")          // primary text
        static let inkSecondary = Color(hex: "#4a544e")  // secondary values
        static let muted = Color(hex: "#8a928c")         // labels, captions
        static let faint = Color(hex: "#a0a89f")         // mono micro-labels, chevrons

        static let hairline = Color(hex: "#ecece6")
        static let hairlineSoft = Color(hex: "#f3f3ee")
        static let border = Color(hex: "#e2e2d8")
        static let borderAlt = Color(hex: "#e6e6df")
        static let dashed = Color(hex: "#c9c9bf")

        static let green = Color(hex: "#1f6f54")          // brand / positive / CTA
        static let greenSoft = Color(hex: "#dbeae1")
        static let greenSoft2 = Color(hex: "#eaf2ed")
        static let greenSoft3 = Color(hex: "#eef6f1")
        static let greenOnDark = Color(hex: "#bfe0cf")
        static let greenOnDark2 = Color(hex: "#9ec9b3")
        static let greenOnDark3 = Color(hex: "#eaf6f0")
        static let greenAccent = Color(hex: "#9bd2b8")    // pill on green card
        static let greenDark = Color(hex: "#0f3527")      // text on light-green pill

        static let clay = Color(hex: "#bd5a3c")           // expense / negative / over
        static let claySoft = Color(hex: "#f7e8e1")
        static let amber = Color(hex: "#d39a4a")          // high spend ratio
        static let amberBudget = Color(hex: "#c19a4a")    // budgeted portion of meter
    }

    /// Category accent colors (authoritative hex values from the handoff).
    enum CategoryColor {
        static let housing = "#1f6f54"
        static let groceries = "#7a8b3f"
        static let shopping = "#8b6b3f"
        static let transport = "#3f6f8b"
        static let dining = "#bd5a3c"
        static let utilities = "#6b7d6f"
        static let health = "#8b3f5a"
        static let school = "#5b5f8b"
        static let subscriptions = "#3f8b7d"
        static let other = "#8a928c"
    }

    enum Radius {
        static let card: CGFloat = 18
        static let summary: CGFloat = 22
        static let largeSummary: CGFloat = 24
        static let button: CGFloat = 16
        static let tile: CGFloat = 14
        static let tint: CGFloat = 11
        static let full: CGFloat = 999
    }

    enum Spacing {
        static let side: CGFloat = 16
        static let sideWide: CGFloat = 20
        static let card: CGFloat = 16
        static let section: CGFloat = 16
        static let element: CGFloat = 10
        static let bottomSafe: CGFloat = 28
    }
}

// MARK: - Typography
//
// The handoff specifies Hanken Grotesk (UI) + IBM Plex Mono (numeric/mono).
// SF Pro is an explicitly-permitted substitute; we use the system font here
// and route everything through these helpers so bundled fonts can be swapped
// in later by changing only this file.

extension Font {
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Text {
    /// Money / numeric figures use tabular figures throughout.
    func tabular() -> Text { self.monospacedDigit() }
}

// MARK: - Shadows

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    static let card = Shadow(color: Color(hex: "#14281e").opacity(0.04), radius: 1, x: 0, y: 1)
    static let primaryButton = Shadow(color: Color(hex: "#1f6f54").opacity(0.28), radius: 10, x: 0, y: 8)
    static let greenCard = Shadow(color: Color(hex: "#1f6f54").opacity(0.22), radius: 11, x: 0, y: 8)
    static let tabButton = Shadow(color: Color(hex: "#1f6f54").opacity(0.35), radius: 8, x: 0, y: 6)
    static let appMark = Shadow(color: Color(hex: "#1f6f54").opacity(0.32), radius: 13, x: 0, y: 10)
}

extension View {
    func appShadow(_ s: Shadow) -> some View {
        self.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }
}

// MARK: - Currency formatting (AED, comma thousands, no decimals)

enum Money {
    static func aed(_ amount: Double, decimals: Int = 0) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.minimumFractionDigits = decimals
        f.maximumFractionDigits = decimals
        let n = f.string(from: NSNumber(value: amount)) ?? "0"
        return "AED \(n)"
    }

    static func plain(_ amount: Double, decimals: Int = 0) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.minimumFractionDigits = decimals
        f.maximumFractionDigits = decimals
        return f.string(from: NSNumber(value: amount)) ?? "0"
    }

    /// Values shown in thousands on the Year Plan table (e.g. 18.5).
    static func thousands(_ amount: Double, signed: Bool = false) -> String {
        let v = amount / 1000
        let s = String(format: "%.1f", v)
        if signed && amount >= 0 { return "+\(s)" }
        return s
    }
}
