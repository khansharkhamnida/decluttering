import Foundation
import Testing
import UIKit
@testable import decluttering

// Serialized because these tests change the one shared theme setting.
@MainActor
@Suite(.serialized)
struct ThemeTests {

    private func contrast(_ a: UIColor, _ b: UIColor) -> CGFloat {
        func luminance(_ color: UIColor) -> CGFloat {
            var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0, alpha: CGFloat = 0
            color.getRed(&r, green: &g, blue: &bl, alpha: &alpha)
            func channel(_ v: CGFloat) -> CGFloat { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
            return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(bl)
        }
        let (hi, lo) = (max(luminance(a), luminance(b)), min(luminance(a), luminance(b)))
        return (hi + 0.05) / (lo + 0.05)
    }

    @Test func everyThemeHasAUniqueIdAndIcon() {
        let ids = ThemeCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count)
        let icons = ThemeCatalog.all.compactMap(\.iconName)
        #expect(Set(icons).count == icons.count)
        #expect(ThemeCatalog.all.filter { $0.iconName == nil }.map(\.id) == ["red"])
        #expect(ThemeCatalog.all.count == 14)
    }

    @Test func unknownIdFallsBackToTheOriginalLook() {
        #expect(ThemeCatalog.theme(id: "nope").id == "red")
        #expect(ThemeCatalog.theme(id: nil).id == "red")
    }

    @Test func textIsReadableOnItsSurface() {
        for theme in ThemeCatalog.all {
            #expect(contrast(theme.ink, theme.surface) >= 4.5, "ink on surface: \(theme.name)")
            #expect(contrast(theme.ink, theme.paper) >= 4.5, "ink on paper: \(theme.name)")
            #expect(contrast(theme.onPrimary, theme.primary) >= 3.5, "onPrimary on primary: \(theme.name)")
            #expect(contrast(theme.onBackground, theme.background.base) >= 4.5, "onBackground on background: \(theme.name)")
            #expect(contrast(theme.accent, theme.background.base) >= 3, "accent on background: \(theme.name)")
        }
    }

    @Test func selectingAThemeChangesTheLookAndAnnouncesIt() {
        let original = ThemeStore.current
        defer { ThemeStore.select(original) }
        var announced = 0
        let token = NotificationCenter.default.addObserver(forName: ThemeStore.didChange, object: nil, queue: nil) { _ in announced += 1 }
        defer { NotificationCenter.default.removeObserver(token) }

        let other = ThemeCatalog.all.first { $0.id != original.id }!
        ThemeStore.select(other)
        #expect(ThemeStore.current.id == other.id)
        #expect(BoothTheme.ink == other.ink)
        ThemeStore.select(other)
        #expect(announced == 1)
    }

    @Test func darkThemesGetLightTextAndTheOtherWayRound() {
        let original = ThemeStore.current
        defer { ThemeStore.select(original) }
        ThemeStore.select(ThemeCatalog.linen)
        #expect(BoothTheme.interfaceStyle == .light)
        ThemeStore.select(ThemeCatalog.darkroom)
        #expect(BoothTheme.interfaceStyle == .dark)
        #expect(BoothTheme.sheetStyle == .dark)
    }
}
