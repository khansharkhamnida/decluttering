import UIKit

/// Chips that narrow today's memories to one type of media, each with how many there are.
/// The same chips on every day. Types with nothing in them are dimmed. Hidden only when a day has no photos at all.
final class MediaFilterBar: UIView {

    var onSelect: ((MediaFilter) -> Void)?
    private(set) var selected: MediaFilter = .all

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private var chips: [FilterChipViewModel] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -14),
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: 38) }

    func configure(chips: [FilterChipViewModel], selected: MediaFilter) {
        isHidden = chips.isEmpty
        guard chips != self.chips else { return select(selected) }
        self.chips = chips
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for chip in chips {
            let button = UIButton(configuration: .filled())
            button.addAction(UIAction { [weak self] _ in
                self?.select(chip.filter)
                self?.onSelect?(chip.filter)
            }, for: .touchUpInside)
            stack.addArrangedSubview(button)
        }
        select(selected)
    }

    func select(_ filter: MediaFilter) {
        selected = filter
        for (chip, view) in zip(chips, stack.arrangedSubviews) {
            guard let button = view as? UIButton else { continue }
            let isSelected = chip.filter == filter
            var config = UIButton.Configuration.filled()
            config.image = UIImage(systemName: chip.filter.symbol)
            config.imagePadding = 6
            config.cornerStyle = .capsule
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
            config.baseBackgroundColor = isSelected ? BoothTheme.primary : BoothTheme.chipFill
            config.baseForegroundColor = isSelected ? BoothTheme.onPrimary : BoothTheme.onBackground
            button.isEnabled = chip.isEnabled
            button.alpha = chip.isEnabled ? 1 : 0.4
            config.attributedTitle = AttributedString("\(chip.filter.title) · \(chip.count)",
                                                      attributes: AttributeContainer([.font: BoothTheme.font(14, .bold, maxScale: 1.2)]))
            button.configuration = config
            button.accessibilityLabel = "\(chip.filter.title), \(chip.count == 0 ? "none today" : "\(chip.count) item\(chip.count == 1 ? "" : "s")")"
            button.accessibilityTraits = isSelected ? [.button, .selected] : .button
        }
    }
}
