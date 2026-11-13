import UIKit

/// The look of the app right now. Every property follows the theme picked in `ThemeStore`.
enum BoothTheme {
    static var current: Theme { ThemeStore.current }

    static var onBackground: UIColor { current.onBackground }
    static var accent: UIColor { current.accent }
    static var paper: UIColor { current.paper }
    static var ink: UIColor { current.ink }
    static var primary: UIColor { current.primary }
    static var onPrimary: UIColor { current.onPrimary }
    static var chipFill: UIColor { current.chipFill }
    static var strip: UIColor { current.strip }
    static var folderBack: UIColor { current.folderBack }
    static var surface: UIColor { current.surface }
    static var viewerBackground: UIColor { current.viewerBackground }
    static var binBody: UIColor { current.binBody }
    static var binFace: UIColor { current.binBody.readableOn }
    static var selection: UIColor { current.selection }
    static var barShade: UIColor { current.barShade }
    static var photoTint: UIColor { current.background.base.withAlphaComponent(0.5) }
    static var photoPlaceholder: UIColor { current.barShade.withAlphaComponent(0.25) }

    /// Text on the always-dark photo viewer.
    static var onViewer: UIColor {
        current.onBackground.brightness01 > current.paper.brightness01 ? current.onBackground : current.paper
    }

    static var viewerAccent: UIColor {
        current.accent.brightness01 > 0.55 ? current.accent : onViewer.withAlphaComponent(0.8)
    }

    /// Light text over the dark theme backgrounds means dark UI chrome, and the other way round.
    static var interfaceStyle: UIUserInterfaceStyle { current.onBackground.brightness01 > 0.5 ? .dark : .light }

    /// Sheets sit on `surface`, so they follow its brightness rather than the background's.
    static var sheetStyle: UIUserInterfaceStyle { current.ink.brightness01 > 0.5 ? .dark : .light }

    /// Rounded system font by default, or whatever the theme asks for. By default it grows with the user's
    /// Dynamic Type setting, up to `maxScale` times its size.
    static func font(_ size: CGFloat, _ weight: UIFont.Weight = .bold, scaling: Bool = true, maxScale: CGFloat = 1.6) -> UIFont {
        let font = makeFont(size, weight, style: current.font)
        guard scaling else { return font }
        return UIFontMetrics.default.scaledFont(for: font, maximumPointSize: size * maxScale)
    }

    /// Same as `font`, for a theme other than the current one (the picker previews every theme).
    static func font(_ size: CGFloat, _ weight: UIFont.Weight, in theme: Theme) -> UIFont {
        makeFont(size, weight, style: theme.font)
    }

    private static func makeFont(_ size: CGFloat, _ weight: UIFont.Weight, style: Theme.FontStyle) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        func designed(_ design: UIFontDescriptor.SystemDesign) -> UIFont {
            guard let descriptor = base.fontDescriptor.withDesign(design) else { return base }
            return UIFont(descriptor: descriptor, size: size)
        }
        switch style {
        case .rounded: return designed(.rounded)
        case .serif: return designed(.serif)
        case .mono: return designed(.monospaced)
        case .system: return base
        case .named(let regular, let bold):
            return UIFont(name: weight >= .semibold ? bold : regular, size: size) ?? designed(.rounded)
        }
    }

    /// The background as a colour, so it can be assigned straight to a view.
    static var background: UIColor { background(of: current) }

    static func background(of theme: Theme) -> UIColor { BackgroundRenderer.color(for: theme) }
}

/// Draws theme backgrounds as tiled images and keeps them, so switching back is instant.
private enum BackgroundRenderer {
    private static var cache: [String: UIColor] = [:]

    static func color(for theme: Theme) -> UIColor {
        if let hit = cache[theme.id] { return hit }
        let color = render(theme.background)
        cache[theme.id] = color
        return color
    }

    private static func tile(_ size: CGSize, _ draw: @escaping (CGContext, CGSize) -> Void) -> UIColor {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { draw($0.cgContext, size) }
        return UIColor(patternImage: image)
    }

    private static func screenSize() -> CGSize {
        let bounds = UIScreen.main.bounds.size
        return CGSize(width: max(bounds.width, 1), height: max(bounds.height, 1))
    }

    private static func render(_ background: Theme.Background) -> UIColor {
        switch background {
        case .solid(let color):
            return color
        case .stripes(let a, let b, let width):
            return tile(CGSize(width: width * 2, height: 4)) { ctx, size in
                ctx.setFillColor(a.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: width, height: size.height))
                ctx.setFillColor(b.cgColor); ctx.fill(CGRect(x: width, y: 0, width: width, height: size.height))
            }
        case .dots(let base, let dot):
            return tile(CGSize(width: 26, height: 26)) { ctx, size in
                ctx.setFillColor(base.cgColor); ctx.fill(CGRect(origin: .zero, size: size))
                ctx.setFillColor(dot.cgColor)
                ctx.fillEllipse(in: CGRect(x: 11, y: 11, width: 4, height: 4))
                ctx.setFillColor(dot.withAlphaComponent(0.5).cgColor)
                ctx.fillEllipse(in: CGRect(x: -1.5, y: -1.5, width: 3, height: 3))
                ctx.fillEllipse(in: CGRect(x: 24.5, y: 24.5, width: 3, height: 3))
            }
        case .lines(let base, let line):
            return tile(CGSize(width: 4, height: 4)) { ctx, size in
                ctx.setFillColor(base.cgColor); ctx.fill(CGRect(origin: .zero, size: size))
                ctx.setFillColor(line.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: size.width, height: 1.5))
            }
        case .crosshatch(let base, let line):
            return tile(CGSize(width: 4, height: 4)) { ctx, size in
                ctx.setFillColor(base.cgColor); ctx.fill(CGRect(origin: .zero, size: size))
                ctx.setStrokeColor(line.cgColor); ctx.setLineWidth(1)
                ctx.move(to: CGPoint(x: 0, y: 4)); ctx.addLine(to: CGPoint(x: 4, y: 0))
                ctx.move(to: CGPoint(x: -1, y: 1)); ctx.addLine(to: CGPoint(x: 1, y: -1))
                ctx.move(to: CGPoint(x: 3, y: 5)); ctx.addLine(to: CGPoint(x: 5, y: 3))
                ctx.strokePath()
            }
        case .grid(let base, let line):
            return tile(CGSize(width: 22, height: 22)) { ctx, size in
                ctx.setFillColor(base.cgColor); ctx.fill(CGRect(origin: .zero, size: size))
                ctx.setFillColor(line.cgColor)
                ctx.fill(CGRect(x: 0, y: 0, width: size.width, height: 1))
                ctx.fill(CGRect(x: 0, y: 0, width: 1, height: size.height))
            }
        case .gradient(let colors):
            return tile(screenSize()) { ctx, size in
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray, locations: nil)!
                ctx.drawLinearGradient(gradient, start: CGPoint(x: size.width * 0.4, y: 0), end: CGPoint(x: size.width * 0.6, y: size.height),
                                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
        case .glow(let base, let glow):
            return tile(screenSize()) { ctx, size in
                ctx.setFillColor(base.cgColor); ctx.fill(CGRect(origin: .zero, size: size))
                let colors = [glow.cgColor, glow.withAlphaComponent(0).cgColor] as CFArray
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: nil)!
                let center = CGPoint(x: size.width / 2, y: -size.height * 0.05)
                ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center,
                                       endRadius: size.height * 0.6, options: [])
            }
        }
    }
}
