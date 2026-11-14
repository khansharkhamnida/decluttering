import UIKit

/// The booth report: streak, totals, the optional daily reminder and the kept list.
final class StatsViewController: UIViewController {

    private let stats: BoothStats
    private let earnedStickers: Set<String>
    private let reminderOn: Bool
    private let onToggleReminder: (Bool, @escaping (Bool) -> Void) -> Void
    private let onResetKept: () -> Void

    private let reminderSwitch = UISwitch()
    private let keepersSwitch = UISwitch()
    private let keepersSettings = KeepersAlbumSettings()

    init(stats: BoothStats, earnedStickers: Set<String>, reminderOn: Bool,
         onToggleReminder: @escaping (Bool, @escaping (Bool) -> Void) -> Void,
         onResetKept: @escaping () -> Void) {
        self.stats = stats
        self.earnedStickers = earnedStickers
        self.reminderOn = reminderOn
        self.onToggleReminder = onToggleReminder
        self.onResetKept = onResetKept
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    static func present(from host: UIViewController, stats: BoothStats, earnedStickers: Set<String>, reminderOn: Bool,
                        onToggleReminder: @escaping (Bool, @escaping (Bool) -> Void) -> Void,
                        onResetKept: @escaping () -> Void) {
        let controller = StatsViewController(stats: stats, earnedStickers: earnedStickers, reminderOn: reminderOn,
                                             onToggleReminder: onToggleReminder, onResetKept: onResetKept)
        controller.modalPresentationStyle = .pageSheet
        if let sheet = controller.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        host.present(controller, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = BoothTheme.sheetStyle
        view.backgroundColor = BoothTheme.surface

        let title = UILabel()
        title.text = "Booth Report"
        title.font = BoothTheme.font(26, .heavy)
        title.textColor = BoothTheme.ink

        let tiles = UIStackView(arrangedSubviews: [
            tile(value: stats.streak, caption: "day streak", symbol: "flame.fill"),
            tile(value: stats.binned, caption: "binned", symbol: "trash.fill"),
            tile(value: stats.kept, caption: "kept", symbol: "heart.fill")
        ])
        tiles.spacing = 10
        tiles.distribution = .fillEqually

        let line = UILabel()
        line.text = BoothVoice.reportLine(binned: stats.binned, streak: stats.streak)
        line.font = BoothTheme.font(15, .semibold)
        line.textColor = BoothTheme.ink.withAlphaComponent(0.8)
        line.numberOfLines = 0
        line.textAlignment = .center

        let reminderLabel = UILabel()
        reminderLabel.text = "Daily booth reminder at 9:00"
        reminderLabel.font = BoothTheme.font(16, .bold)
        reminderLabel.textColor = BoothTheme.ink
        reminderSwitch.isOn = reminderOn
        reminderSwitch.onTintColor = BoothTheme.ink
        reminderSwitch.addAction(UIAction { [weak self] _ in self?.reminderChanged() }, for: .valueChanged)
        reminderLabel.isAccessibilityElement = false
        reminderSwitch.accessibilityLabel = "Daily booth reminder at 9:00"

        let reminderRow = UIStackView(arrangedSubviews: [reminderLabel, reminderSwitch])
        reminderRow.alignment = .center
        reminderRow.isLayoutMarginsRelativeArrangement = true
        reminderRow.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        let reminderCard = UIView()
        reminderCard.backgroundColor = .white.withAlphaComponent(0.6)
        reminderCard.layer.cornerRadius = 14
        reminderRow.translatesAutoresizingMaskIntoConstraints = false
        reminderCard.addSubview(reminderRow)
        NSLayoutConstraint.activate([
            reminderRow.topAnchor.constraint(equalTo: reminderCard.topAnchor),
            reminderRow.bottomAnchor.constraint(equalTo: reminderCard.bottomAnchor),
            reminderRow.leadingAnchor.constraint(equalTo: reminderCard.leadingAnchor),
            reminderRow.trailingAnchor.constraint(equalTo: reminderCard.trailingAnchor)
        ])

        var views: [UIView] = [title, tiles, line, reminderCard, keepersCard()]
        if stats.kept > 0 {
            var config = UIButton.Configuration.plain()
            config.baseForegroundColor = BoothTheme.ink
            config.attributedTitle = AttributedString("Bring my \(stats.kept) kept photos back", attributes: AttributeContainer([.font: BoothTheme.font(15, .bold)]))
            let bringBack = UIButton(configuration: config)
            bringBack.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                let action = self.onResetKept
                self.dismiss(animated: true) { action() }
            }, for: .touchUpInside)
            views.append(bringBack)
        }

        let stickersTitle = UILabel()
        stickersTitle.text = "Sticker book  \(earnedStickers.count)/\(StickerBook.all.count)"
        stickersTitle.font = BoothTheme.font(20, .heavy)
        stickersTitle.textColor = BoothTheme.ink
        views.append(stickersTitle)
        views.append(stickerGrid())

        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 30),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -30),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -22)
        ])
    }

    private func stickerGrid() -> UIView {
        let columns = 3
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 16
        var row: UIStackView?
        for (index, sticker) in StickerBook.all.enumerated() {
            if index % columns == 0 {
                row = UIStackView()
                row?.distribution = .fillEqually
                row?.alignment = .top
                row?.spacing = 8
                grid.addArrangedSubview(row!)
            }
            let tilt: CGFloat = [-0.08, 0.06, -0.04][index % 3]
            row?.addArrangedSubview(StickerView(sticker: sticker, earned: earnedStickers.contains(sticker.id), tilt: tilt))
        }
        return grid
    }

    /// Switch for the optional Photos album, with a short note on what it does.
    private func keepersCard() -> UIView {
        let caption = "Add kept photos to a \u{201C}Decluttering Keepers\u{201D} album in Photos"
        let label = UILabel()
        label.text = caption
        label.font = BoothTheme.font(16, .bold)
        label.textColor = BoothTheme.ink
        label.numberOfLines = 0
        label.isAccessibilityElement = false

        keepersSwitch.isOn = keepersSettings.isEnabled
        keepersSwitch.onTintColor = BoothTheme.ink
        keepersSwitch.setContentHuggingPriority(.required, for: .horizontal)
        keepersSwitch.setContentCompressionResistancePriority(.required, for: .horizontal)
        keepersSwitch.accessibilityLabel = "Add kept photos to a Decluttering Keepers album in Photos"
        keepersSwitch.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.keepersSettings.isEnabled = self.keepersSwitch.isOn
        }, for: .valueChanged)

        let row = UIStackView(arrangedSubviews: [label, keepersSwitch])
        row.alignment = .center
        row.spacing = 12

        let note = UILabel()
        note.text = "Bringing your kept photos back doesn\u{2019}t change this album."
        note.font = BoothTheme.font(12, .semibold)
        note.textColor = BoothTheme.ink.withAlphaComponent(0.7)
        note.numberOfLines = 0

        let content = UIStackView(arrangedSubviews: [row, note])
        content.axis = .vertical
        content.spacing = 6
        content.isLayoutMarginsRelativeArrangement = true
        content.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        let card = UIView()
        card.backgroundColor = .white.withAlphaComponent(0.6)
        card.layer.cornerRadius = 14
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.topAnchor),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor)
        ])
        return card
    }

    private func reminderChanged() {
        let wanted = reminderSwitch.isOn
        onToggleReminder(wanted) { [weak self] succeeded in
            // If permission was refused the switch goes back to off
            if !succeeded { self?.reminderSwitch.setOn(!wanted, animated: true) }
        }
    }

    private func tile(value: Int, caption: String, symbol: String) -> UIView {
        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = BoothTheme.ink.withAlphaComponent(0.7)
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)

        let number = UILabel()
        number.text = "\(value)"
        number.font = BoothTheme.font(34, .heavy)
        number.textColor = BoothTheme.ink

        let label = UILabel()
        label.text = caption
        label.font = BoothTheme.font(12, .bold)
        label.textColor = BoothTheme.ink.withAlphaComponent(0.7)

        let stack = UIStackView(arrangedSubviews: [icon, number, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 14, left: 6, bottom: 12, right: 6)
        stack.isAccessibilityElement = true
        stack.accessibilityLabel = "\(value) \(caption)"

        let card = UIView()
        card.backgroundColor = .white.withAlphaComponent(0.6)
        card.layer.cornerRadius = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor)
        ])
        return card
    }
}
