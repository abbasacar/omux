import AppKit
import SwiftTerm
import SwiftUI

/// SwiftTerm has a Color too; across omux the plain name means SwiftUI's.
typealias Color = SwiftUI.Color

enum Theme: String, CaseIterable, Identifiable {
    case black, dark, graphite, midnight, dracula, nord, oneDark, gruvbox, solarizedDark,
        catppuccinMocha, tokyoNight, rosePine, light, solarizedLight, catppuccinLatte

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneDark: return "One Dark"
        case .solarizedDark: return "Solarized Dark"
        case .solarizedLight: return "Solarized Light"
        case .catppuccinMocha: return "Catppuccin Mocha"
        case .catppuccinLatte: return "Catppuccin Latte"
        case .tokyoNight: return "Tokyo Night"
        case .rosePine: return "Rosé Pine"
        default: return rawValue.capitalized
        }
    }

    static var current: Theme {
        Theme(rawValue: UserDefaults.standard.string(forKey: Prefs.theme) ?? "") ?? .dark
    }

    var isLight: Bool { self == .light || self == .solarizedLight || self == .catppuccinLatte }
    var colorScheme: ColorScheme { isLight ? .light : .dark }

    /// background, chrome (sidebar/header), foreground
    private var colors: (bg: UInt32, chrome: UInt32, fg: UInt32) {
        switch self {
        case .black: return (0x000000, 0x0F0F0F, 0xE6E6E6)
        case .dark: return (0x1C1C1F, 0x252529, 0xE6E6E6)
        case .graphite: return (0x2B2B2B, 0x363636, 0xE6E6E6)
        case .midnight: return (0x0D1117, 0x161B22, 0xC9D1D9)
        case .dracula: return (0x282A36, 0x21222C, 0xF8F8F2)
        case .nord: return (0x2E3440, 0x3B4252, 0xD8DEE9)
        case .oneDark: return (0x282C34, 0x21252B, 0xABB2BF)
        case .gruvbox: return (0x282828, 0x1D2021, 0xEBDBB2)
        case .solarizedDark: return (0x002B36, 0x073642, 0x839496)
        case .light: return (0xFBFBFB, 0xEFEFF1, 0x1F1F1F)
        case .solarizedLight: return (0xFDF6E3, 0xEEE8D5, 0x657B83)
        case .catppuccinMocha: return (0x1E1E2E, 0x181825, 0xCDD6F4)
        case .tokyoNight: return (0x1A1B26, 0x16161E, 0xC0CAF5)
        case .rosePine: return (0x191724, 0x1F1D2E, 0xE0DEF4)
        case .catppuccinLatte: return (0xEFF1F5, 0xE6E9EF, 0x4C4F69)
        }
    }

    var background: NSColor { NSColor(hex: colors.bg) }
    var chrome: NSColor { NSColor(hex: colors.chrome) }
    var foreground: NSColor { NSColor(hex: colors.fg) }

    /// 16 ANSI colours (normal 0-7, bright 8-15).
    var palette: [SwiftTerm.Color] {
        paletteHex.map { v in
            SwiftTerm.Color(red: UInt16((v >> 16) & 0xFF) * 257,
                            green: UInt16((v >> 8) & 0xFF) * 257,
                            blue: UInt16(v & 0xFF) * 257)
        }
    }

    /// The plain themes keep macOS's colors; the others have a palette of their own.
    private var hasOwnColors: Bool {
        switch self {
        case .black, .dark, .graphite, .light: return false
        default: return true
        }
    }

    private func ansi(_ index: Int) -> Color { Color(nsColor: NSColor(hex: paletteHex[index])) }

    /// Working, needs-you, done and error, in the theme's own colors so the sidebar and
    /// header match the terminal.
    func statusColor(_ state: TabRuntime.StatusState?) -> Color? {
        guard let state, state != .idle else { return nil }
        guard hasOwnColors else {
            switch state {
            case .working: return .blue
            case .blocked: return .orange
            case .done: return .green
            case .error: return .red
            case .idle: return nil
            }
        }
        switch state {
        // Rosé Pine has no green; its foam and iris keep done and working apart.
        case .working: return self == .rosePine ? Color(nsColor: NSColor(hex: 0xC4A7E7)) : ansi(4)
        case .blocked: return ansi(3)
        case .done: return self == .rosePine ? ansi(4) : ansi(2)
        case .error: return ansi(1)
        case .idle: return nil
        }
    }

    /// Selection and highlight color: the theme's blue, or the system accent for plain themes.
    var accent: Color { hasOwnColors ? statusColor(.working)! : .accentColor }

    private var paletteHex: [UInt32] {
        var hex: [UInt32]
        switch self {
        case .midnight:
            hex = [0x484F58, 0xFF7B72, 0x3FB950, 0xD29922, 0x58A6FF, 0xBC8CFF, 0x39C5CF, 0xB1BAC4,
                   0x6E7681, 0xFFA198, 0x56D364, 0xE3B341, 0x79C0FF, 0xD2A8FF, 0x56D4DD, 0xF0F6FC]
        case .dracula:
            hex = [0x21222C, 0xFF5555, 0x50FA7B, 0xF1FA8C, 0xBD93F9, 0xFF79C6, 0x8BE9FD, 0xF8F8F2,
                   0x6272A4, 0xFF6E6E, 0x69FF94, 0xFFFFA5, 0xD6ACFF, 0xFF92DF, 0xA4FFFF, 0xFFFFFF]
        case .nord:
            hex = [0x3B4252, 0xBF616A, 0xA3BE8C, 0xEBCB8B, 0x81A1C1, 0xB48EAD, 0x88C0D0, 0xE5E9F0,
                   0x4C566A, 0xBF616A, 0xA3BE8C, 0xEBCB8B, 0x81A1C1, 0xB48EAD, 0x8FBCBB, 0xECEFF4]
        case .oneDark:
            hex = [0x282C34, 0xE06C75, 0x98C379, 0xE5C07B, 0x61AFEF, 0xC678DD, 0x56B6C2, 0xABB2BF,
                   0x5C6370, 0xE06C75, 0x98C379, 0xE5C07B, 0x61AFEF, 0xC678DD, 0x56B6C2, 0xFFFFFF]
        case .gruvbox:
            hex = [0x282828, 0xCC241D, 0x98971A, 0xD79921, 0x458588, 0xB16286, 0x689D6A, 0xA89984,
                   0x928374, 0xFB4934, 0xB8BB26, 0xFABD2F, 0x83A598, 0xD3869B, 0x8EC07C, 0xEBDBB2]
        case .solarizedDark, .solarizedLight:
            hex = [0x073642, 0xDC322F, 0x859900, 0xB58900, 0x268BD2, 0xD33682, 0x2AA198, 0xEEE8D5,
                   0x002B36, 0xCB4B16, 0x586E75, 0x657B83, 0x839496, 0x6C71C4, 0x93A1A1, 0xFDF6E3]
        case .catppuccinMocha:
            hex = [0x45475A, 0xF38BA8, 0xA6E3A1, 0xF9E2AF, 0x89B4FA, 0xF5C2E7, 0x94E2D5, 0xBAC2DE,
                   0x585B70, 0xF38BA8, 0xA6E3A1, 0xF9E2AF, 0x89B4FA, 0xF5C2E7, 0x94E2D5, 0xA6ADC8]
        case .tokyoNight:
            hex = [0x15161E, 0xF7768E, 0x9ECE6A, 0xE0AF68, 0x7AA2F7, 0xBB9AF7, 0x7DCFFF, 0xA9B1D6,
                   0x414868, 0xF7768E, 0x9ECE6A, 0xE0AF68, 0x7AA2F7, 0xBB9AF7, 0x7DCFFF, 0xC0CAF5]
        case .rosePine:
            hex = [0x26233A, 0xEB6F92, 0x31748F, 0xF6C177, 0x9CCFD8, 0xC4A7E7, 0xEBBCBA, 0xE0DEF4,
                   0x6E6A86, 0xEB6F92, 0x31748F, 0xF6C177, 0x9CCFD8, 0xC4A7E7, 0xEBBCBA, 0xE0DEF4]
        case .catppuccinLatte:
            hex = [0x5C5F77, 0xD20F39, 0x40A02B, 0xDF8E1D, 0x1E66F5, 0xEA76CB, 0x179299, 0xACB0BE,
                   0x6C6F85, 0xD20F39, 0x40A02B, 0xDF8E1D, 0x1E66F5, 0xEA76CB, 0x179299, 0xBCC0CC]
        case .light:
            hex = [0x000000, 0xC91B00, 0x00A600, 0x9A7B00, 0x0225C7, 0xCA30C7, 0x00A2B2, 0xBFBFBF,
                   0x686868, 0xFF6E67, 0x2EB84A, 0xC7A500, 0x6871FF, 0xFF77FF, 0x1BA8B5, 0xFFFFFF]
        case .black, .dark, .graphite:
            hex = [0x000000, 0xCD3131, 0x0DBC79, 0xE5E510, 0x2472C8, 0xBC3FBC, 0x11A8CD, 0xE5E5E5,
                   0x666666, 0xF14C4C, 0x23D18B, 0xF5F543, 0x3B8EEA, 0xD670D6, 0x29B8DB, 0xFFFFFF]
        }
        // "White" and "bright white" are near the background on light themes, so text
        // a program prints in them would vanish; use readable grays instead.
        switch self {
        case .light: hex[7] = 0x6E6E6E; hex[15] = 0x3A3A3A
        case .solarizedLight: hex[7] = 0x657B83; hex[15] = 0x073642
        case .catppuccinLatte: hex[7] = 0x6C6F85; hex[15] = 0x4C4F69
        default: break
        }
        return hex
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

enum Fonts {
    /// Installed fixed-pitch families, for the Settings picker.
    static let monospaceFamilies: [String] = NSFontManager.shared.availableFontFamilies
        .filter { NSFont(name: $0, size: 12)?.isFixedPitch == true }
        .sorted()

    /// Terminal font from Settings; empty family means the system monospaced font.
    static func terminal() -> NSFont {
        let family = UserDefaults.standard.string(forKey: Prefs.fontFamily) ?? ""
        let stored = UserDefaults.standard.double(forKey: Prefs.fontSize)
        let size = stored > 0 ? stored : 13
        return (family.isEmpty ? nil : NSFont(name: family, size: size))
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }
}

/// Small icon buttons with a comfortable hit area and a hover highlight.
struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        IconButtonBody(configuration: configuration)
    }

    private struct IconButtonBody: View {
        let configuration: ButtonStyleConfiguration
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
                .background(
                    Color.primary.opacity(configuration.isPressed ? 0.16 : hovering && isEnabled ? 0.08 : 0),
                    in: RoundedRectangle(cornerRadius: 5)
                )
                .opacity(isEnabled ? 1 : 0.4)
                .onHover { hovering = $0 }
        }
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.dark
}

extension EnvironmentValues {
    /// The current theme, for views that color themselves by it.
    var omuxTheme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

/// A session's status dot: filled in the theme's status color, gray when idle, and a
/// hollow ring when the session is stopped. The session's own color has its own bar.
struct StatusDot: View {
    @Environment(\.omuxTheme) private var theme
    let runtime: TabRuntime?
    var size: CGFloat = 8

    var body: some View {
        if let color = theme.statusColor(runtime?.statusState) {
            Circle().fill(color).frame(width: size, height: size)
        } else if runtime?.exited ?? true {
            Circle().strokeBorder(Color.secondary.opacity(0.7), lineWidth: 1.2).frame(width: size, height: size)
        } else {
            Circle().fill(Color.secondary.opacity(0.5)).frame(width: size, height: size)
        }
    }
}
