import UIKit

struct DayChipViewModel: Equatable {
    let offset: Int
    let label: String
    let isToday: Bool
    let spoken: String
}

/// One calm line for the whole top of the list: step to the day before or after, tap the date to jump
/// to any day within three days of today, and fold or open every folder from the button on the right.
final class DayBarView: UIView {

    var onSelect: ((Int) -> Void)?
    var onFoldTap: (() -> Void)?
    private(set) var selected = 0

    private var days: [DayChipViewModel] = []
    private let previousButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let dateButton = UIButton(type: .system)
    private let foldButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureRound(previousButton, symbol: "chevron.left", label: "Day before")
        configureRound(nextButton, symbol: "chevron.right", label: "Day after")
        previousButton.addAction(UIAction { [weak self] _ in self?.step(-1) }, for: .touchUpInside)
        nextButton.addAction(UIAction { [weak self] _ in self?.step(1) }, for: .touchUpInside)

        dateButton.showsMenuAsPrimaryAction = true
        dateButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        foldButton.addAction(UIAction { [weak self] _ in self?.onFoldTap?() }, for: .touchUpInside)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [previousButton, dateButton, nextButton, spacer, foldButton])
        row.alignment = .center
        row.spacing = 6
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            heightAnchor.constraint(equalToConstant: 44)
        ])
        updateFold(folderCount: 0, allCollapsed: false, isEnabled: true)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: 44) }

    // MARK: Day

    func configure(days: [DayChipViewModel], selected: Int) {
        self.days = days
        self.selected = selected
        guard let current = days.first(where: { $0.offset == selected }) else { return }

        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = BoothTheme.onBackground
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
        config.attributedTitle = AttributedString(current.label, attributes: AttributeContainer([.font: BoothTheme.font(17, .heavy, maxScale: 1.2)]))
        dateButton.configuration = config
        dateButton.accessibilityLabel = current.spoken
        dateButton.accessibilityHint = "Choose another day"

        dateButton.menu = UIMenu(children: days.map { day in
            UIAction(title: day.label, state: day.offset == selected ? .on : .off) { [weak self] _ in self?.choose(day.offset) }
        })

        let offsets = days.map(\.offset)
        previousButton.isEnabled = selected > (offsets.min() ?? selected)
        nextButton.isEnabled = selected < (offsets.max() ?? selected)
    }

    private func step(_ direction: Int) {
        choose(selected + direction)
    }

    private func choose(_ offset: Int) {
        guard offset != selected, days.contains(where: { $0.offset == offset }) else { return }
        BoothHaptics.shared.tap()
        configure(days: days, selected: offset)
        onSelect?(offset)
    }

    // MARK: Fold all

    /// Hidden below two folders, since there is nothing to fold or open all at once.
    func updateFold(folderCount: Int, allCollapsed: Bool, isEnabled: Bool) {
        foldButton.isHidden = folderCount < 2
        foldButton.isEnabled = isEnabled
        applyRoundStyle(foldButton, symbol: allCollapsed ? "rectangle.expand.vertical" : "rectangle.compress.vertical",
                        label: allCollapsed ? "Open all folders" : "Fold all folders", filled: true)
    }

    // MARK: Styling

    private func configureRound(_ button: UIButton, symbol: String, label: String) {
        applyRoundStyle(button, symbol: symbol, label: label, filled: false)
    }

    private func applyRoundStyle(_ button: UIButton, symbol: String, label: String, filled: Bool) {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.image = UIImage(systemName: symbol)
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        config.baseBackgroundColor = filled ? BoothTheme.primary : BoothTheme.chipFill
        config.baseForegroundColor = filled ? BoothTheme.onPrimary : BoothTheme.onBackground
        button.configuration = config
        button.accessibilityLabel = label
        if button.constraints.isEmpty {
            button.widthAnchor.constraint(equalToConstant: 38).isActive = true
            button.heightAnchor.constraint(equalToConstant: 38).isActive = true
        }
    }
}
