import UIKit
import WidgetKit

/// One complete look for the app. Every colour the screens, the widget and the picker use comes from here.
struct Theme: Identifiable {

    enum Background {
        case stripes(UIColor, UIColor, width: CGFloat)
        case dots(base: UIColor, dot: UIColor)
        case solid(UIColor)
        case lines(base: UIColor, line: UIColor)
        case crosshatch(base: UIColor, line: UIColor)
        case grid(base: UIColor, line: UIColor)
        case gradient([UIColor])
        case glow(base: UIColor, glow: UIColor)

        /// The flat colour the pattern is built on, for places that can't show a pattern.
        var base: UIColor {
            switch self {
            case .stripes(let a, _, _): return a
            case .dots(let base, _), .lines(let base, _), .crosshatch(let base, _), .grid(let base, _), .glow(let base, _): return base
            case .solid(let color): return color
            case .gradient(let colors): return colors[colors.count / 2]
            }
        }
    }

    /// The little decoration row under the title.
    enum Divider { case bulbs, stitch, ticks, pixels, waves, sprockets, none }

    /// How each photo in a folder is framed.
    enum PhotoStyle { case plain, print, film, darkroom, exif }

    enum FontStyle {
        case rounded, serif, mono, system
        case named(regular: String, bold: String)
    }

    let id: String
    let name: String
    let tagline: String
    let background: Background
    /// Navigation bar colour once content scrolls under it.
    let barShade: UIColor
    let onBackground: UIColor
    /// Secondary text and decoration on the background.
    let accent: UIColor
    /// Light card surface (speech bubble, round buttons) and the text colour on `ink` fills.
    let paper: UIColor
    /// Text on cards and sheets, and the fill of the bin button.
    let ink: UIColor
    /// Main call to action and the selected filter chip.
    let primary: UIColor
    let onPrimary: UIColor
    let chipFill: UIColor
    /// Front panel of each year folder.
    let strip: UIColor
    let folderBack: UIColor
    /// Background of sheets and the swipe card, always readable with `ink`.
    let surface: UIColor
    let viewerBackground: UIColor
    let binBody: UIColor
    /// Outline of photos picked for binning.
    let selection: UIColor
    let font: FontStyle
    let divider: Divider
    let photoStyle: PhotoStyle
    let photoCorner: CGFloat
    /// Name of the alternate app icon, or nil for the primary one.
    let iconName: String?
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }

    /// Perceived brightness from 0 (black) to 1 (white).
    var brightness01: CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.299 * r + 0.587 * g + 0.114 * b
    }

    /// Near-black or white, whichever reads better on this colour.
    var readableOn: UIColor { brightness01 > 0.6 ? UIColor(hex: 0x1A1210) : UIColor(hex: 0xFFFFFF) }
}

enum ThemeCatalog {

    private static func c(_ hex: UInt32, _ alpha: CGFloat = 1) -> UIColor { UIColor(hex: hex).withAlphaComponent(alpha) }

    static let redCurtain = Theme(
        id: "red", name: "Red Curtain", tagline: "Velvet booth stripes",
        background: .stripes(c(0xB02339), c(0x8F192B), width: 14),
        barShade: c(0x8F192B), onBackground: c(0xFFF1E4), accent: c(0xF3DDA6),
        paper: c(0xFFF1E4), ink: c(0x6B0F1F), primary: c(0xFFF1E4), onPrimary: c(0x6B0F1F),
        chipFill: c(0x6B0F1F, 0.55), strip: c(0xFDE6E0), folderBack: c(0xF0C4BB), surface: c(0xFDE6E0),
        viewerBackground: c(0x2A070E), binBody: c(0xFFF1E4), selection: c(0x6B0F1F),
        font: .rounded, divider: .bulbs, photoStyle: .plain, photoCorner: 3, iconName: nil)

    static let lavender = Theme(
        id: "purple", name: "Lavender Arcade", tagline: "Dreamy purple with twinkly stars",
        background: .dots(base: c(0x7F5AD0), dot: c(0x6A47BA)),
        barShade: c(0x6A47BA), onBackground: c(0xFAF5FF), accent: c(0xFFB7DE),
        paper: c(0xFAF5FF), ink: c(0x3B1F6E), primary: c(0xFAF5FF), onPrimary: c(0x3B1F6E),
        chipFill: c(0x4A2C8F, 0.8), strip: c(0xEBDDFB), folderBack: c(0xD3BDF3), surface: c(0xEBDDFB),
        viewerBackground: c(0x1E1038), binBody: c(0xFAF5FF), selection: c(0x3B1F6E),
        font: .rounded, divider: .bulbs, photoStyle: .plain, photoCorner: 3, iconName: "AppIcon-purple")

    static let midnight = Theme(
        id: "midnight", name: "Midnight Cinema", tagline: "Navy night with golden marquee glow",
        background: .dots(base: c(0x1D2347), dot: c(0x151A38)),
        barShade: c(0x151A38), onBackground: c(0xF4EBD3), accent: c(0xFFC947),
        paper: c(0xF4EBD3), ink: c(0x1D2347), primary: c(0xF4EBD3), onPrimary: c(0x1D2347),
        chipFill: c(0x2E3768, 0.8), strip: c(0xEAD9AE), folderBack: c(0xCDB57A), surface: c(0xEAD9AE),
        viewerBackground: c(0x0C1022), binBody: c(0xF4EBD3), selection: c(0x1D2347),
        font: .rounded, divider: .bulbs, photoStyle: .plain, photoCorner: 3, iconName: "AppIcon-midnight")

    static let kraft = Theme(
        id: "kraft", name: "Kraft Scrapbook", tagline: "Brown paper, taped-down prints",
        background: .crosshatch(base: c(0xD6B98C), line: c(0x000000, 0.04)),
        barShade: c(0xCDB07F), onBackground: c(0x4A3320), accent: c(0x7A2E45),
        paper: c(0xFFFDF6), ink: c(0x5A3A22), primary: c(0xFFFDF6), onPrimary: c(0x5A3A22),
        chipFill: c(0x4A3320, 0.13), strip: c(0xF0E0C0), folderBack: c(0xE9D2A4), surface: c(0xF0E0C0),
        viewerBackground: c(0x2A1C10), binBody: c(0xFFFDF6), selection: c(0x5A3A22),
        font: .named(regular: "MarkerFelt-Thin", bold: "MarkerFelt-Wide"), divider: .stitch, photoStyle: .print,
        photoCorner: 1, iconName: "AppIcon-kraft")

    static let blueprint = Theme(
        id: "blueprint", name: "Blueprint", tagline: "Cyanotype blue, graph paper, typewriter type",
        background: .grid(base: c(0x0F3C78), line: c(0xFFFFFF, 0.1)),
        barShade: c(0x0B2E5C), onBackground: c(0xEAF4FF), accent: c(0xB7D4F7),
        paper: c(0xF2F8FF), ink: c(0x0F3C78), primary: c(0xF2F8FF), onPrimary: c(0x0F3C78),
        chipFill: c(0x1E5AA8, 0.8), strip: c(0xDCEBFF), folderBack: c(0xB7D4F7), surface: c(0xDCEBFF),
        viewerBackground: c(0x081E3D), binBody: c(0xF2F8FF), selection: c(0x0F3C78),
        font: .named(regular: "AmericanTypewriter", bold: "AmericanTypewriter-Bold"), divider: .ticks,
        photoStyle: .plain, photoCorner: 0, iconName: "AppIcon-blueprint")

    static let golden = Theme(
        id: "golden", name: "Golden Hour", tagline: "Soft sunset gradient and serif type",
        background: .gradient([c(0xFFD9A0), c(0xFFAE8B), c(0xF2889B)]),
        barShade: c(0xFFAE8B), onBackground: c(0x4A1D2A), accent: c(0x7A2E40),
        paper: c(0xFFF8EF), ink: c(0x5B2433), primary: c(0xFFF8EF), onPrimary: c(0x5B2433),
        chipFill: c(0xFFFFFF, 0.28), strip: c(0xFFF3E6), folderBack: c(0xFFE6D2), surface: c(0xFFF3E6),
        viewerBackground: c(0x3A1522), binBody: c(0xFFF8EF), selection: c(0x5B2433),
        font: .serif, divider: .none, photoStyle: .plain, photoCorner: 8, iconName: "AppIcon-golden")

    static let pixel = Theme(
        id: "gameboy", name: "Pixel Pocket", tagline: "Four-shade green handheld screen",
        background: .lines(base: c(0x9BBC0F), line: c(0x0F380F, 0.08)),
        barShade: c(0x8BAC0F), onBackground: c(0x0F380F), accent: c(0x306230),
        paper: c(0xD6E4A8), ink: c(0x0F380F), primary: c(0x0F380F), onPrimary: c(0xD6E4A8),
        chipFill: c(0x8BAC0F), strip: c(0xCADC9F), folderBack: c(0x8BAC0F), surface: c(0xCADC9F),
        viewerBackground: c(0x0F380F), binBody: c(0xD6E4A8), selection: c(0x0F380F),
        font: .mono, divider: .pixels, photoStyle: .plain, photoCorner: 0, iconName: "AppIcon-gameboy")

    static let linen = Theme(
        id: "linen", name: "Clean Linen", tagline: "Calm and minimal, one tomato accent",
        background: .solid(c(0xF3F0E8)),
        barShade: c(0xEAE5D8), onBackground: c(0x2B2A28), accent: c(0xC2401B),
        paper: c(0xFFFFFF), ink: c(0x2B2A28), primary: c(0x2B2A28), onPrimary: c(0xFFFFFF),
        chipFill: c(0xE6E1D4), strip: c(0xFFFFFF), folderBack: c(0xEAE5D8), surface: c(0xFFFFFF),
        viewerBackground: c(0x1A1917), binBody: c(0xFFFFFF), selection: c(0x2B2A28),
        font: .system, divider: .none, photoStyle: .plain, photoCorner: 7, iconName: "AppIcon-linen")

    static let seaside = Theme(
        id: "seaside", name: "Seaside Postcard", tagline: "Sky to sand with a red stamp",
        background: .gradient([c(0x7CCBF0), c(0xB9E6F7), c(0xF5EBD2)]),
        barShade: c(0x7CCBF0), onBackground: c(0x0C3B5B), accent: c(0xA32626),
        paper: c(0xFFFFFF), ink: c(0x0C3B5B), primary: c(0xD63B3B), onPrimary: c(0xFFFFFF),
        chipFill: c(0xFFFFFF, 0.55), strip: c(0xFFFFFF), folderBack: c(0xD5EEF9), surface: c(0xFFFFFF),
        viewerBackground: c(0x0A2236), binBody: c(0xFFFFFF), selection: c(0x0C3B5B),
        font: .rounded, divider: .waves, photoStyle: .plain, photoCorner: 3, iconName: "AppIcon-seaside")

    static let clay = Theme(
        id: "clay", name: "Cloud Clay", tagline: "Puffy soft-3D shapes in baby blue and bubblegum",
        background: .gradient([c(0xFFD3E8), c(0xBFD9FF), c(0xD7C9FF)]),
        barShade: c(0xBFD9FF), onBackground: c(0x2F2C5E), accent: c(0x7B3A8F),
        paper: c(0xFFFFFF), ink: c(0x3D3A6B), primary: c(0xFF8FB8), onPrimary: c(0x4A1030),
        chipFill: c(0xFFFFFF, 0.67), strip: c(0xFFFFFF), folderBack: c(0xFFD3E8), surface: c(0xFFFFFF),
        viewerBackground: c(0x1D1A45), binBody: c(0xFFFFFF), selection: c(0x3D3A6B),
        font: .rounded, divider: .none, photoStyle: .plain, photoCorner: 14, iconName: "AppIcon-clay")

    static let filmRoll = Theme(
        id: "film", name: "Film Roll", tagline: "Yellow film box, black negative strips",
        background: .stripes(c(0xF5B800), c(0xF1B100), width: 22),
        barShade: c(0xE5AB00), onBackground: c(0x1B1710), accent: c(0x6B2D00),
        paper: c(0xFFF4CC), ink: c(0x1B1710), primary: c(0x1B1710), onPrimary: c(0xF5B800),
        chipFill: c(0x1B1710, 0.14), strip: c(0x1B1710), folderBack: c(0xFFE58A), surface: c(0xFFF4CC),
        viewerBackground: c(0x100D08), binBody: c(0xFFF4CC), selection: c(0xF5B800),
        font: .named(regular: "Menlo-Regular", bold: "Menlo-Bold"), divider: .sprockets, photoStyle: .plain,
        photoCorner: 2, iconName: "AppIcon-film")

    static let filmDark = Theme(
        id: "filmdark", name: "Film Roll Dark", tagline: "Black negative frames, orange date stamp",
        background: .solid(c(0x17110D)),
        barShade: c(0x0F0B08), onBackground: c(0xF4E3C1), accent: c(0xFFB627),
        paper: c(0x2A2118), ink: c(0xF4E3C1), primary: c(0xFFB627), onPrimary: c(0x17110D),
        chipFill: c(0xF4E3C1, 0.14), strip: c(0x0C0906), folderBack: c(0x2A2118), surface: c(0x2A2118),
        viewerBackground: c(0x0D0A07), binBody: c(0xF4E3C1), selection: c(0xFFB627),
        font: .named(regular: "CourierNewPSMT", bold: "CourierNewPS-BoldMT"), divider: .none, photoStyle: .film,
        photoCorner: 0, iconName: "AppIcon-filmdark")

    static let darkroom = Theme(
        id: "dark", name: "Darkroom", tagline: "Red safelight, contact-sheet feel",
        background: .glow(base: c(0x12060A), glow: c(0x7A120B, 0.55)),
        barShade: c(0x0B0306), onBackground: c(0xFFD4D4), accent: c(0xFF6A6A),
        paper: c(0x2B0D12), ink: c(0xFFD4D4), primary: c(0xFF5A55), onPrimary: c(0x1A0508),
        chipFill: c(0xFF3D3D, 0.16), strip: c(0x1E090E), folderBack: c(0x2B0D12), surface: c(0x2B0D12),
        viewerBackground: c(0x080304), binBody: c(0xFFD4D4), selection: c(0xFF3D3D),
        font: .named(regular: "CourierNewPSMT", bold: "CourierNewPS-BoldMT"), divider: .none, photoStyle: .darkroom,
        photoCorner: 0, iconName: "AppIcon-dark")

    static let cameraRoll = Theme(
        id: "camera", name: "Camera Roll", tagline: "Dark leather, red dot, EXIF settings",
        background: .dots(base: c(0x19191B), dot: c(0xFFFFFF, 0.06)),
        barShade: c(0x111113), onBackground: c(0xECECEE), accent: c(0xA8A8AE),
        paper: c(0x2A2A2D), ink: c(0xECECEE), primary: c(0xD8322E), onPrimary: c(0xFFFFFF),
        chipFill: c(0xFFFFFF, 0.1), strip: c(0x222224), folderBack: c(0x2A2A2D), surface: c(0x2A2A2D),
        viewerBackground: c(0x0E0E10), binBody: c(0xECECEE), selection: c(0xFFFFFF),
        font: .system, divider: .none, photoStyle: .exif, photoCorner: 3, iconName: "AppIcon-camera")

    static let all: [Theme] = [redCurtain, lavender, midnight, kraft, blueprint, golden, pixel, linen, seaside, clay,
                               filmRoll, filmDark, darkroom, cameraRoll]

    static func theme(id: String?) -> Theme { all.first { $0.id == id } ?? redCurtain }
}

/// Remembers the chosen theme in the App Group so the widget can follow the app.
enum ThemeStore {
    static let didChange = Notification.Name("ThemeStoreDidChange")

    private static let key = "selectedThemeID"
    private static let appGroupID = "group.com.khansharkhamnida.decluttering"
    private static var chosen: Theme?

    private static var defaults: UserDefaults { UserDefaults(suiteName: appGroupID) ?? .standard }

    /// The widget process never calls `select`, so it re-reads the shared value each time and follows the app.
    static var current: Theme {
        chosen ?? ThemeCatalog.theme(id: defaults.string(forKey: key))
    }

    static func select(_ theme: Theme) {
        guard theme.id != current.id else { return }
        chosen = theme
        defaults.set(theme.id, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: didChange, object: nil)
    }
}
