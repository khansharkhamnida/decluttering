import UIKit

struct Sticker {
    let id: String
    let name: String
    let requirement: String
    let symbol: String
    let color: UIColor
    let isEarned: (BoothStats) -> Bool
}

/// Binny's collectible stickers. Once earned, a sticker stays earned even if a streak later breaks.
enum StickerBook {

    static let all: [Sticker] = [
        Sticker(id: "first-poof", name: "First Poof", requirement: "Bin your first photo",
                symbol: "sparkles", color: UIColor(hex: 0xE8A33D)) { $0.binned >= 1 },
        Sticker(id: "first-keeper", name: "First Keeper", requirement: "Keep your first photo",
                symbol: "heart.fill", color: UIColor(hex: 0xE5667F)) { $0.kept >= 1 },
        Sticker(id: "three-day", name: "3-Day Sparkle", requirement: "Keep a 3-day streak",
                symbol: "flame.fill", color: UIColor(hex: 0xE8703D)) { $0.streak >= 3 },
        Sticker(id: "tidy-ten", name: "Tidy Ten", requirement: "Bin 10 photos",
                symbol: "leaf.fill", color: UIColor(hex: 0x4FA86B)) { $0.binned >= 10 },
        Sticker(id: "heart-collector", name: "Heart Collector", requirement: "Keep 10 photos",
                symbol: "heart.circle.fill", color: UIColor(hex: 0xC85A9B)) { $0.kept >= 10 },
        Sticker(id: "week-wonder", name: "Week Wonder", requirement: "Keep a 7-day streak",
                symbol: "moon.stars.fill", color: UIColor(hex: 0x6F6BD6)) { $0.streak >= 7 },
        Sticker(id: "half-century", name: "Half Century", requirement: "Bin 50 photos",
                symbol: "star.fill", color: UIColor(hex: 0x3F9BC9)) { $0.binned >= 50 },
        Sticker(id: "century-sweep", name: "Century Sweep", requirement: "Bin 100 photos",
                symbol: "crown.fill", color: UIColor(hex: 0xB8862B)) { $0.binned >= 100 },
        Sticker(id: "month-marvel", name: "Month Marvel", requirement: "Keep a 30-day streak",
                symbol: "trophy.fill", color: UIColor(hex: 0xA34A4A)) { $0.streak >= 30 }
    ]

    private static let storageKey = "earnedStickerIDs"

    /// Every sticker earned so far, including ones from earlier streaks.
    static func earnedIDs(for stats: BoothStats, defaults: UserDefaults = .standard) -> Set<String> {
        let saved = Set(defaults.stringArray(forKey: storageKey) ?? [])
        return saved.union(all.filter { $0.isEarned(stats) }.map(\.id))
    }

    /// Stickers earned since the last call. Saves them, so each one is announced only once.
    static func newlyEarned(for stats: BoothStats, defaults: UserDefaults = .standard) -> [Sticker] {
        let saved = Set(defaults.stringArray(forKey: storageKey) ?? [])
        let nowEarned = all.filter { $0.isEarned(stats) && !saved.contains($0.id) }
        guard !nowEarned.isEmpty else { return [] }
        defaults.set(Array(saved.union(nowEarned.map(\.id))), forKey: storageKey)
        return nowEarned
    }
}

/// A round sticker with a white border, tilted a little. Locked ones are blank and dashed.
final class StickerView: UIView {

    init(sticker: Sticker, earned: Bool, tilt: CGFloat) {
        super.init(frame: .zero)

        let disc = UIView()
        disc.layer.cornerRadius = 34
        disc.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: earned ? sticker.symbol : "lock.fill"))
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 26, weight: .bold)
        icon.translatesAutoresizingMaskIntoConstraints = false
        disc.addSubview(icon)

        if earned {
            disc.backgroundColor = sticker.color
            disc.layer.borderColor = UIColor.white.cgColor
            disc.layer.borderWidth = 4
            disc.layer.shadowColor = UIColor.black.cgColor
            disc.layer.shadowOpacity = 0.25
            disc.layer.shadowRadius = 4
            disc.layer.shadowOffset = CGSize(width: 0, height: 2)
            icon.tintColor = .white
            disc.transform = CGAffineTransform(rotationAngle: tilt)
        } else {
            disc.backgroundColor = BoothTheme.ink.withAlphaComponent(0.08)
            disc.layer.borderColor = BoothTheme.ink.withAlphaComponent(0.3).cgColor
            disc.layer.borderWidth = 2
            icon.tintColor = BoothTheme.ink.withAlphaComponent(0.35)
        }

        let name = UILabel()
        name.text = earned ? sticker.name : "???"
        name.font = BoothTheme.font(12, .heavy, maxScale: 1.3)
        name.textColor = BoothTheme.ink
        name.textAlignment = .center
        name.numberOfLines = 2

        let detail = UILabel()
        detail.text = sticker.requirement
        detail.font = BoothTheme.font(10, .semibold, maxScale: 1.3)
        detail.textColor = BoothTheme.ink.withAlphaComponent(0.65)
        detail.textAlignment = .center
        detail.numberOfLines = 2

        let stack = UIStackView(arrangedSubviews: [disc, name, detail])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            disc.widthAnchor.constraint(equalToConstant: 68),
            disc.heightAnchor.constraint(equalToConstant: 68),
            icon.centerXAnchor.constraint(equalTo: disc.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: disc.centerYAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        isAccessibilityElement = true
        accessibilityLabel = earned ? "\(sticker.name), earned" : "Locked sticker"
        accessibilityHint = sticker.requirement
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
